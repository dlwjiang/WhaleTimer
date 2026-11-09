#!/usr/bin/env python3
"""Render src/audio.js synth recipes as offline PCM; no third-party samples."""
from pathlib import Path
import math
import shutil
import struct
import wave

APP = Path(__file__).resolve().parents[1] / 'Banke'
RATE = 24000
OUT = APP / 'Audio/Effects'

def envelope(t, peak, end, attack=.0005, hold=.003):
    if t < 0 or t >= end: return 0
    if t < attack: return peak*t/attack
    if t < hold: return peak
    return peak * (.0001/peak)**((t-hold)/(end-hold))

def click(layers, noise_end):
    frames = [0.] * int(RATE*.24)
    for initial, settled, peak, duration, delay, shape in layers:
        phase = 0
        ramp = min(.025,duration*.5)
        for i in range(int(delay*RATE), min(len(frames),int((delay+duration)*RATE))):
            t = i/RATE-delay
            frequency = initial*(settled/initial)**min(1,t/ramp)
            phase += 2*math.pi*frequency/RATE
            sine = math.sin(phase)
            value = sine if shape == 'sine' else 2/math.pi*math.asin(sine) if shape == 'triangle' else (1 if sine >= 0 else -1)
            frames[i] += value*envelope(t,peak,duration)
    seed=731; previous=0
    for i in range(int(noise_end*RATE)):
        seed=(1664525*seed+1013904223)&0xffffffff
        noise=seed/2147483648-1
        frames[i]+=(noise-previous)*.5*envelope(i/RATE,.24,noise_end,.0003,.002)
        previous=noise
    return frames

def bell():
    frames=[]
    for i in range(int(1.86*RATE)):
        t=i/RATE; sample=0
        for start in (0,.26):
            dt=t-start
            if 0 <= dt < 1.6:
                for hz,peak in ((1175,.11),(2350,.035),(3525,.015)):
                    gain=peak*dt/.005 if dt < .005 else peak*(.0001/peak)**((dt-.005)/1.495)
                    sample+=math.sin(2*math.pi*hz*dt)*gain
        frames.append(sample)
    return frames

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    clips={
        'play':click([(145,72,.34,.16,0,'sine'),(480,220,.28,.075,0,'triangle'),(1800,850,.12,.022,.014,'square')],.028),
        'pause':click([(185,90,.34,.18,0,'sine'),(620,280,.28,.085,0,'triangle'),(2400,1100,.12,.018,0,'square')],.022),
        'bell':bell(),
    }
    for name,frames in clips.items():
        scale=.98/max(1,max(map(abs,frames)))
        with wave.open(str(OUT/f'{name}.wav'),'wb') as output:
            output.setparams((1,2,RATE,0,'NONE','not compressed'))
            output.writeframes(b''.join(struct.pack('<h',round(v*scale*32767)) for v in frames))
    shutil.copyfile(OUT/'bell.wav',APP/'completion.wav')
    print('Rendered web play/pause clicks and two-strike bell.')
if __name__ == '__main__': main()
