"""Regression checks for the casting/production mismatch that damaged the voices."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from selected_voice_contract import REVISION, sha, validate_review, validate_bundle, validate_transcripts, reference_generation_options, BASE_MODEL, equivalent_wording


class VoiceContractTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.cast = self.root / 'cast'
        self.pilot = self.root / 'pilot'
        self.source = self.root / 'source'
        self.audio = self.root / 'audio'
        for path in [self.cast / 'audio', self.pilot / 'mochi', self.source / 'mochi/en', self.audio / 'en/mochi']:
            path.mkdir(parents=True)
        # Synthetic fixture bytes, never copied into real production/review folders.
        self.a = self.cast / 'audio/maple-b.m4a'
        self.a.write_bytes(b'original audition')
        (self.cast / 'audio/maple-b.wav').write_bytes(b'original lossless audition')
        self.sample = self.pilot / 'mochi/direct.m4a'
        self.sample.write_bytes(b'direct pilot')
        self.selection = {'voice': 'maple-b', 'model': 'Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16', 'sha256': sha(self.a)}
        (self.pilot/'audition-source-check.json').write_text(json.dumps({'clips':{'mochi':{'exactAuditionMatch':True,'auditionSHA256':sha(self.a),'reencodedSHA256':sha(self.a),'sourceWAVSHA256':sha(self.cast/'audio/maple-b.wav')}}}))
        self.choices = self.cast / 'approved-choices.json'
        self.choices.write_text(json.dumps({'selectedVoices': {'mochi': self.selection}}))
        (self.pilot / 'manifest.json').write_text(json.dumps({'clips': {'mochi/direct': {
            'voice': 'maple-b', 'model': self.selection['model'], 'auditionSHA256': sha(self.a), 'audioSHA256': sha(self.sample)}}}))
        self.review = {'version': 2, 'choicesSHA256': sha(self.choices), 'routes': {'mochi': {
            'status': 'approved', 'route': 'direct', 'pilotSHA256': sha(self.sample)}}}

    def validate(self, review=None):
        return validate_review(self.review if review is None else review, ['mochi'], self.cast, self.pilot)

    def test_current_review_matches(self):
        self.assertEqual(self.validate()['selectedVoices']['mochi'], self.selection)

    def test_missing_or_rejected_listening_cannot_pass(self):
        for status in ['pending', 'rejected', None]:
            review = copy.deepcopy(self.review)
            review['routes']['mochi']['status'] = status
            with self.assertRaisesRegex(ValueError, 'pending or rejected'):
                self.validate(review)

    def test_old_review_cannot_follow_changed_pilot(self):
        self.sample.write_bytes(b'different performance')
        with self.assertRaisesRegex(ValueError, 'changed after listening'):
            self.validate()

    def test_original_audition_cannot_change(self):
        self.a.write_bytes(b'different voice')
        with self.assertRaisesRegex(ValueError, 'original audition changed'):
            self.validate()

    def test_lossless_reference_cannot_change_behind_approved_aac(self):
        (self.cast/'audio/maple-b.wav').write_bytes(b'wrong voice reference')
        with self.assertRaisesRegex(ValueError,'lossless source'):
            self.validate()

    def test_wrong_model_cannot_use_correct_voice_hash(self):
        p = self.pilot / 'manifest.json'
        data = json.loads(p.read_text())
        data['clips']['mochi/direct']['model'] = 'VoxCPM2-bf16'
        p.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'voice and engine'):
            self.validate()

    def bundle(self):
        raw = self.source / 'mochi/en/go.wav'
        raw.write_bytes(b'new raw audio')
        encoded = self.audio / 'en/mochi/go.m4a'
        encoded.write_bytes(b'new encoded audio')
        review_path = self.source / 'routes.json'
        review_path.write_text(json.dumps(self.review))
        return {'casting': {'pipelineRevision': REVISION, 'choicesSHA256': sha(self.choices),
                'selectedVoices': {'mochi': self.selection}, 'reviewSHA256': sha(review_path)},
                'productionReview': self.review, 'clips': {'en/mochi/go': {
                'pipelineRevision': REVISION, 'castingVoice': 'maple-b',
                'auditionSHA256': sha(self.a), 'auditionWAVSHA256': sha(self.cast / 'audio/maple-b.wav'),
                'route': 'direct', 'pilotSHA256': sha(self.sample), 'model': self.selection['model'],
                'rawSHA256': sha(raw), 'audioSHA256': sha(encoded),
                'encoding': {'speed': 1, 'pitch': 1, 'bitrateTarget': 128000, 'sampleRate': 24000, 'channels': 1, 'codec': 'aac'}}}}

    def check_bundle(self, bundle):
        return validate_bundle(self.audio, bundle, source=self.source, cast=self.cast, pilot=self.pilot)

    def test_source_and_engine_traceability(self):
        bundle = self.bundle()
        self.assertEqual(self.check_bundle(bundle), [])
        bundle['clips']['en/mochi/go']['model'] = 'VoxCPM2-bf16'
        self.assertIn('Incorrect model', self.check_bundle(bundle)[0])

    def test_changed_source_and_accelerated_audio_rejected(self):
        bundle = self.bundle()
        bundle['clips']['en/mochi/go']['encoding']['speed'] = 1.5
        self.assertIn('encoding speed', self.check_bundle(bundle)[0])
        bundle['clips']['en/mochi/go']['encoding']['speed'] = 1
        (self.source / 'mochi/en/go.wav').write_bytes(b'changed raw')
        self.assertIn('rawSHA256', self.check_bundle(bundle)[0])

    def test_nonenglish_reference_requires_explicit_language_evidence(self):
        (self.pilot/'mochi/reference.m4a').write_bytes(self.sample.read_bytes())
        self.review['routes']['mochi']['route']='reference'
        pilots=json.loads((self.pilot/'manifest.json').read_text())
        pilots['clips']['mochi/reference']={**pilots['clips']['mochi/direct'],'model':BASE_MODEL}
        (self.pilot/'manifest.json').write_text(json.dumps(pilots))
        bundle=self.bundle()
        entry=bundle['clips'].pop('en/mochi/go')
        entry.update(route='reference',model=BASE_MODEL)
        bundle['clips']['fr/mochi/go']=entry
        (self.source/'mochi/en').rename(self.source/'mochi/fr')
        (self.audio/'en').rename(self.audio/'fr')
        self.assertIn('languageConditioning',self.check_bundle(bundle)[0])
        entry['languageConditioning']='French'
        self.assertEqual(self.check_bundle(bundle),[])

    def test_reference_cloning_uses_the_actual_language_parameter(self):
        options=reference_generation_options('de',Path('audition.wav'),'Hello')
        self.assertEqual(options['lang_code'],'German')
        self.assertNotIn('language',options)
        self.assertEqual(reference_generation_options('en',Path('a.wav'),'Hi')['lang_code'],'auto')

    def test_installer_requires_current_wording_checks(self):
        bundle = self.bundle()
        key = 'en/mochi/go'
        report = {'clips': {key: {'sha256': bundle['clips'][key]['audioSHA256'], 'review': 'transcript-match', 'similarity': 1}}}
        self.assertEqual(validate_transcripts(bundle, report), [])
        report['clips'][key]['sha256'] = 'old recording'
        self.assertIn('stale', validate_transcripts(bundle, report)[0])
        report['clips'][key]['sha256'] = bundle['clips'][key]['audioSHA256']
        report['clips'][key]['similarity'] = .89
        self.assertIn('insufficient', validate_transcripts(bundle, report)[0])
        report['clips'][key]['similarity'] = 1
        bundle['clips'][key]['text'] = 'Different words'
        self.assertIn('different expected text', validate_transcripts(bundle, report)[0])

    def test_legacy_pipeline_cannot_claim_repair(self):
        self.assertIn('Legacy', self.check_bundle({'casting': {}, 'clips': {}})[0])

    def test_wording_variants_are_explicit_full_reactions_only(self):
        self.assertTrue(equivalent_wording('ko/luna/poke','앗, 나 찾았네!','아 나 찾았네'))
        self.assertTrue(equivalent_wording('zh-Hans/jun/poke','呀，被你发现啦！','呀，被你发现了。'))
        for heard in ['아 나 잊었네','아 나 찾았네 쫑','아 나 찾았네 나 찾았네']:
            self.assertFalse(equivalent_wording('ko/luna/poke','앗, 나 찾았네!',heard))
        self.assertFalse(equivalent_wording('ko/luna/greeting','앗, 나 찾았네!','아 나 찾았네'))
        entry={'audioSHA256':'same','text':'앗, 나 찾았네!'}
        report={'clips':{'ko/luna/poke':{'sha256':'same','expected':entry['text'],'heard':'아 나 찾았네','similarity':.8,'review':'equivalent-wording'}}}
        self.assertEqual(validate_transcripts({'clips':{'ko/luna/poke':entry}},report),[])
        report['clips']['ko/luna/poke']['heard']='아 나 잊었네'
        self.assertIn('unrecognized wording variant',validate_transcripts({'clips':{'ko/luna/poke':entry}},report)[0])

    def test_contextual_number_requires_unchanged_source_and_bounds(self):
        bundle=self.bundle()
        entry=bundle['clips'].pop('en/mochi/go')
        bundle['clips']['en/mochi/1']=entry
        (self.source/'mochi/en/go.wav').rename(self.source/'mochi/en/1.wav')
        (self.audio/'en/mochi/go.m4a').rename(self.audio/'en/mochi/1.m4a')
        context=self.source/'mochi/en/1-context.wav'
        context.write_bytes(b'full context performance')
        metadata={'method':'contextual-number-v2','number':1,'speed':1,'pitch':1,
                  'sourceSHA256':sha(context),'bounds':[.5,.9],'seed':7}
        context.with_suffix('.json').write_text(json.dumps(metadata))
        entry.update(method='contextual-number-v2',contextSHA256=sha(context),bounds=[.5,.9],seed=7)
        self.assertEqual(self.check_bundle(bundle),[])
        entry['bounds']=[.4,.9]
        self.assertIn('word boundary changed',self.check_bundle(bundle)[0])
        entry['bounds']=[.5,.9]
        context.write_bytes(b'different source')
        self.assertIn('source or word boundary changed',self.check_bundle(bundle)[0])


if __name__ == '__main__':
    unittest.main()
