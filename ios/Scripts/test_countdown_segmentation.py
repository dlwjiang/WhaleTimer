"""Protect number order and word boundaries when ASR joins countdown tokens."""
import unittest
import numpy as np
from countdown_voices import sequence_matches, separated_number_words, quiet_word_boundaries


class CountdownSegmentationTests(unittest.TestCase):
    def waveform(self, count):
        sr=24000
        voice=np.sin(np.arange(int(sr*.3))*2*np.pi*440/sr).astype(np.float32)*.3
        return np.concatenate([np.concatenate([np.zeros(int(sr*.15),dtype=np.float32),voice]) for _ in range(count)]),sr

    def test_joined_and_fragmented_correct_numbers(self):
        self.assertTrue(sequence_matches(['오사삼이일'],'ko'))
        self.assertTrue(sequence_matches(['다섯','넷','셋','둘','하나'],'ko'))
        self.assertFalse(sequence_matches(['다섯','넷','셋','둘','둘'],'ko'))
        self.assertTrue(sequence_matches(['ゴ','ヨン','サ','ン','ニ','イチ'],'ja'))
        self.assertTrue(sequence_matches(['5','4','3','2','1'],'en'))

    def test_longer_context_is_explicit_and_not_accepted_as_app_audio(self):
        order=(6,5,4,3,2,1,0)
        self.assertTrue(sequence_matches(['육오사삼이일영'],'ko',order))
        self.assertFalse(sequence_matches(['육오사삼이일영'],'ko'))
        pcm,sr=self.waveform(7)
        words=separated_number_words(pcm,sr,'ko',order)
        self.assertEqual([w['text'] for w in words[1:-1]],['오','사','삼','이','일'])

    def test_missing_repeated_wrong_and_extra_numbers(self):
        for words,language in [(['五二三二一'],'zh-Hans'),(['오사삼이일이'],'ko'),(['five','four','two','one'],'en'),(['1','2','3','4','5'],'en')]:
            self.assertFalse(sequence_matches(words,language))

    def test_five_separated_islands_keep_each_spoken_number(self):
        pcm,sr=self.waveform(5)
        words=separated_number_words(pcm,sr,'ko')
        self.assertIsNotNone(words)
        self.assertEqual([w['text'] for w in words],['오','사','삼','이','일'])
        for i,word in enumerate(words):
            self.assertAlmostEqual(word['start'],i*.45+.15,places=2)
            self.assertAlmostEqual(word['end'],(i+1)*.45,places=2)

    def test_ambiguous_or_silent_audio_is_not_guessed(self):
        for count in [1,4,6]:
            pcm,sr=self.waveform(count)
            self.assertIsNone(separated_number_words(pcm,sr,'ko'))
        self.assertIsNone(separated_number_words(np.zeros(24000),24000,'en'))

    def test_cuts_use_silence_even_when_word_timestamps_lag(self):
        pcm,sr=self.waveform(5)
        words=separated_number_words(pcm,sr,'en')
        for word in words:
            word['start']+=.08;word['end']+=.08
        boundaries=quiet_word_boundaries(pcm,sr,words)
        self.assertIsNotNone(boundaries)
        for i,b in enumerate(boundaries[1:-1]):
            self.assertGreaterEqual(b,(i+1)*.45)
            self.assertLessEqual(b,(i+1)*.45+.15)
        continuous=np.ones(24000,dtype=np.float32)*.2
        self.assertIsNone(quiet_word_boundaries(continuous,24000,[{'start':0,'end':.45},{'start':.55,'end':1}]))


if __name__=='__main__':unittest.main()
