#!/usr/bin/env python3
"""生成全部原创音频:音乐(OGG)、环境音(OGG)、音效(WAV)。"""
import os, subprocess, wave, math
import numpy as np

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
AUD = os.path.join(ROOT, "audio")
os.makedirs(AUD, exist_ok=True)
SR = 44100
rng = np.random.default_rng(2026)

def save_wav(path, data, stereo=False):
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype(np.int16)
    if stereo and pcm.ndim == 2:
        frames = pcm
    else:
        frames = np.column_stack([pcm, pcm]) if not stereo else pcm
    with wave.open(path, "w") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(frames.tobytes())

def to_ogg(wav_path, name):
    ogg = os.path.join(AUD, name)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-qscale:a", "4", ogg], check=True)
    os.remove(wav_path)
    print("ogg:", name)

def note(freq, dur, amp=0.3, attack=0.02, release=0.4):
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = np.minimum(1, t / max(attack, 1e-4)) * np.exp(-t / (dur * release))
    return np.sin(2 * np.pi * freq * t) * env * amp, n

def pad_chord(freqs, dur, amp=0.14, vibrato=0.15):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        vib = 1 + 0.002 * np.sin(2 * np.pi * vibrato * t + rng.uniform(0, 6))
        out += np.sin(2 * np.pi * f * t * vib) + 0.4 * np.sin(2 * np.pi * f * 2.01 * t)
    out /= len(freqs)
    fade = int(0.5 * SR)
    env = np.ones(n)
    env[:fade] = np.linspace(0, 1, fade)
    env[-fade:] = np.linspace(1, 0, fade)
    return out * env * amp

def silence(dur):
    return np.zeros(int(dur * SR))

def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out

def tempo_pad(chords, beat, amp=0.14):
    """逐和弦铺底,自动循环长度对齐。"""
    out = np.array([])
    for c in chords:
        out = np.concatenate([out, pad_chord(c, beat, amp)])
    return out

# ================================================================ 音乐
def music_menu():
    # A 小调慢板:A- F - C - G
    A2, C3, E3, F2, G2, A3, D3 = 110.0, 130.8, 164.8, 87.3, 98.0, 220.0, 146.8
    seq = [[A2, A3, C3, E3], [F2, F2 * 2, A3, C3], [C3 / 2, G2, C3, E3], [G2, G2 * 1.5, D3, G2 * 2]]
    data = tempo_pad(seq, 4.0, 0.16)
    # 稀疏铃音
    bells = np.zeros_like(data)
    mel = [440, 523.3, 659.3, 587.3, 523.3, 440, 392, 440]
    for i, f in enumerate(mel):
        s, n = note(f, 2.5, 0.10, 0.01, 1.2)
        start = int((i * 2.0) * SR)
        end = min(start + n, len(bells))
        if start < len(bells):
            bells[start:end] += s[:end - start]
    data = mix(data, bells)
    for _ in range(2):
        data = np.concatenate([data, data])
    save_wav(os.path.join(AUD, "_m.wav"), data * 0.8)
    to_ogg(os.path.join(AUD, "_m.wav"), "music_menu.ogg")

def music_town():
    # 温暖民谣感:G 大调
    G2, B2, D3, G3, C3, E3 = 98.0, 123.5, 146.8, 196.0, 130.8, 164.8
    seq = [[G2, D3, G3, B2], [C3, E3, G3, C3 * 2], [G2, D3, G3, B2], [D3 * 0.98, 146.8, 185.0, 220.0]]
    pad = tempo_pad(seq, 2.0, 0.10)
    # 旋律(五声音阶拨弦)
    mel_notes = [392, 440, 494, 587, 494, 440, 392, 330, 392, 440, 523, 587, 523, 494, 440, 392]
    mel = np.zeros(int(len(mel_notes) * 1.0 * SR))
    for i, f in enumerate(mel_notes):
        s, n = note(f, 0.9, 0.14, 0.002, 0.5)
        start = int(i * 1.0 * SR)
        mel[start:start + n] += s
    beat = int(2.0 * SR)
    while len(mel) < len(pad):
        mel = np.concatenate([mel, mel])
    mel = mel[:len(pad)]
    # 简单低音
    bass = np.zeros(len(pad))
    for i in range(0, len(pad), beat):
        root = seq[(i // beat) % 4][0]
        s, n = note(root, 0.8, 0.12, 0.005, 0.6)
        bass[i:i + n] += s
    data = mix(pad, mel, bass)
    data = np.tile(data, 2)
    save_wav(os.path.join(AUD, "_m.wav"), data * 0.75)
    to_ogg(os.path.join(AUD, "_m.wav"), "music_town.ogg")

def music_explore():
    # 空旷冷冽:D 小调长音
    D2, F2, A2, D3, C3, G2, E3b = 73.4, 87.3, 110.0, 146.8, 130.8, 98.0, 155.6
    seq = [[D2, A2, D3, F2], [D2 - 6, A2 * 0.94, C3, D3 * 0.99], [D2, A2, D3, F2], [C3 * 0.5, G2, C3, E3b]]
    data = tempo_pad(seq, 5.0, 0.13)
    drone = np.zeros_like(data)
    for i in range(0, len(data), int(5.0 * SR)):
        s, n = note(36.7, 5.0, 0.10, 1.0, 4.0)
        drone[i:i + n] += s
    data = mix(data, drone)
    data = np.tile(data, 2)
    save_wav(os.path.join(AUD, "_m.wav"), data * 0.8)
    to_ogg(os.path.join(AUD, "_m.wav"), "music_explore.ogg")

def music_danger():
    # 紧张低脉冲:E 小调
    E2, G2, B2, D3, F2, A2 = 82.4, 98.0, 123.5, 146.8, 87.3, 110.0
    seq = [[E2, E2 * 2.02, G2, B2], [E2, E2 * 2.02, F2, A2]]
    data = tempo_pad(seq, 3.0, 0.13)
    pulse = np.zeros_like(data)
    for i in range(0, len(data), int(0.75 * SR)):
        s, n = note(55.0, 0.3, 0.18, 0.001, 0.4)
        pulse[i:i + n] += s
    data = mix(data, pulse)
    data = np.tile(data, 2)
    save_wav(os.path.join(AUD, "_m.wav"), data * 0.8)
    to_ogg(os.path.join(AUD, "_m.wav"), "music_danger.ogg")

def music_boss():
    # 战斗:快速低音脉冲 + 打击
    E2, G2, B2, D3 = 82.4, 98.0, 123.5, 146.8
    seq = [[E2, E2 * 2.02, B2, E2 * 3], [G2 - 4, G2 * 2, D3, G2 * 3]]
    data = tempo_pad(seq, 1.5, 0.12)
    pulse = np.zeros_like(data)
    beat = int(0.5 * SR)
    for i in range(0, len(data), beat):
        s, n = note(41.2, 0.25, 0.22, 0.001, 0.35)
        pulse[i:i + n] += s
        if (i // beat) % 4 == 2:
            s2, n2 = note(82.4, 0.15, 0.15, 0.001, 0.3)
            pulse[i:i + n2] += s2
    data = mix(data, pulse)
    data = np.tile(data, 3)
    save_wav(os.path.join(AUD, "_m.wav"), data * 0.85)
    to_ogg(os.path.join(AUD, "_m.wav"), "music_boss.ogg")

def music_ending():
    # C 大调抒情
    C3, E3, G3, C4, F3, A3, D3, B3, G2 = 130.8, 164.8, 196.0, 261.6, 174.6, 220.0, 146.8, 246.9, 98.0
    seq = [[C3, G3, C4, E3], [F3, C4, F3 * 1.5, A3], [G2, G3, B3, D3], [C3, E3, G3, C4]]
    data = tempo_pad(seq, 4.0, 0.15)
    mel_notes = [523.3, 494, 440, 392, 440, 523.3, 587.3, 523.3]
    mel = np.zeros(int(len(mel_notes) * 2.0 * SR))
    for i, f in enumerate(mel_notes):
        s, n = note(f, 2.0, 0.10, 0.02, 1.0)
        mel[int(i * 2.0 * SR):int(i * 2.0 * SR) + n] += s
    while len(mel) < len(data):
        mel = np.concatenate([mel, mel])
    data = mix(data, mel[:len(data)])
    data = np.tile(data, 2)
    save_wav(os.path.join(AUD, "_m.wav"), data * 0.8)
    to_ogg(os.path.join(AUD, "_m.wav"), "music_ending.ogg")

def amb_wind():
    n = int(30 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # 简易低通
    out = np.zeros(n)
    a = 0.995
    for i in range(1, n):
        out[i] = a * out[i - 1] + (1 - a) * noise[i]
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * t) * np.sin(2 * np.pi * 0.013 * t + 1.0)
    data = out * lfo * 2.2
    save_wav(os.path.join(AUD, "_a.wav"), data * 0.5)
    to_ogg(os.path.join(AUD, "_a.wav"), "amb_wind.ogg")

def amb_snow():
    n = int(30 * SR)
    noise = rng.standard_normal(n)
    out = np.convolve(noise, np.ones(8) / 8, "same")
    t = np.arange(n) / SR
    lfo = 0.6 + 0.4 * np.sin(2 * np.pi * 0.05 * t)
    data = out * lfo * 1.6
    save_wav(os.path.join(AUD, "_a.wav"), data * 0.4)
    to_ogg(os.path.join(AUD, "_a.wav"), "amb_snow.ogg")

# ================================================================ 音效
def sfx(name, data, gain=1.0):
    save_wav(os.path.join(AUD, f"sfx_{name}.wav"), data * gain)
    print("sfx:", name)

def ui_click():
    s, _ = note(880, 0.07, 0.35, 0.001, 0.1)
    return s
def ui_open():
    a, _ = note(520, 0.12, 0.25, 0.002, 0.2)
    b, _ = note(780, 0.15, 0.25, 0.002, 0.25)
    return np.concatenate([a, b])
def footstep_snow():
    n = int(0.14 * SR)
    noise = rng.standard_normal(n) * np.exp(-np.arange(n) / (0.03 * SR))
    return np.convolve(noise, np.ones(6) / 6, "same") * 3.0
def footstep_rock():
    n = int(0.08 * SR)
    noise = rng.standard_normal(n) * np.exp(-np.arange(n) / (0.015 * SR))
    return noise * 2.0
def sword_swing():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # 频率扫描的带通近似:与正弦调制相乘
    sweep = np.sin(2 * np.pi * (400 + 1800 * t / 0.25) * t)
    env = np.exp(-((t - 0.1) ** 2) / 0.004)
    return noise * sweep * env * 1.2
def sword_hit():
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * 90 * np.exp(-t * 3)) * np.exp(-t / 0.05)
    crack = rng.standard_normal(n) * np.exp(-np.arange(n) / (0.01 * SR))
    return (thud + crack * 0.7) * 1.5
def hurt():
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    f = 160 * np.exp(-t * 4) + 60
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.07) * 1.6
def enemy_die():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 300 - 240 * (t / 0.35)
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * rng.standard_normal(n) * np.exp(-t / 0.1)) * np.exp(-t / 0.15) * 0.8
def pickup():
    parts = []
    for f in [660, 880, 1320]:
        s, _ = note(f, 0.09, 0.22, 0.001, 0.15)
        parts.append(s)
    return np.concatenate(parts)
def quest_done():
    parts = []
    for f in [523, 659, 784, 1047]:
        s, _ = note(f, 0.15, 0.22, 0.003, 0.3)
        parts.append(s)
    return np.concatenate(parts)
def levelup():
    parts = []
    for f in [392, 523, 659, 784, 1047]:
        s, _ = note(f, 0.13, 0.2, 0.003, 0.3)
        parts.append(s)
    return np.concatenate(parts)
def bell():
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    a = np.sin(2 * np.pi * 660 * t) + 0.5 * np.sin(2 * np.pi * 990 * t) + 0.25 * np.sin(2 * np.pi * 1320 * t)
    return a * np.exp(-t / 0.5) * 0.35
def drink():
    n = int(0.35 * SR)
    out = np.zeros(n)
    for i in range(5):
        s = int(i * 0.06 * SR)
        burst = rng.standard_normal(int(0.03 * SR)) * np.exp(-np.arange(int(0.03 * SR)) / 800)
        out[s:s + len(burst)] += burst * 2.0
    return out
def roll():
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    env = np.exp(-((t - 0.08) ** 2) / 0.003)
    return np.convolve(noise * env, np.ones(4) / 4, "same") * 2.5
def wolf():
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.03 * np.sin(2 * np.pi * 6 * t)
    f = (280 - 130 * (t / 0.7)) * vib
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(2 * np.pi * 2 * np.cumsum(f) / SR)) * np.exp(-t / 0.5) * 0.55
def heal():
    parts = []
    for f in [523, 784, 1047]:
        s, _ = note(f, 0.18, 0.18, 0.01, 0.4)
        parts.append(s)
    return np.concatenate(parts)
def door():
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    f = 180 + 120 * t / 0.4
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.6 + rng.standard_normal(n) * np.exp(-t / 0.25) * 0.4) * 0.5

if __name__ == "__main__":
    music_menu(); music_town(); music_explore(); music_danger(); music_boss(); music_ending()
    amb_wind(); amb_snow()
    sfx("ui_click", ui_click())
    sfx("ui_open", ui_open())
    sfx("footstep_snow", footstep_snow())
    sfx("footstep_rock", footstep_rock())
    sfx("sword_swing", sword_swing())
    sfx("sword_hit", sword_hit())
    sfx("hurt", hurt())
    sfx("enemy_die", enemy_die())
    sfx("pickup", pickup())
    sfx("quest_done", quest_done())
    sfx("levelup", levelup())
    sfx("bell", bell())
    sfx("drink", drink())
    sfx("roll", roll())
    sfx("wolf", wolf())
    sfx("heal", heal())
    sfx("door", door())
    print("ALL AUDIO DONE")
