"""Placeholder sound effects (retro, synthesized). Replace any file in audio/sfx/ with a
real sound of the same name (.wav or .ogg) and the game uses it. Run: python3 tools/make_sfx.py"""
import numpy as np, wave, os
SR = 22050
OUT = "audio/sfx"
rng = np.random.default_rng(3)

def env(n, a=0.005, d=None, curve=3.0):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(a, 1e-4))
    if d:
        e *= np.clip(1.0 - t / d, 0, 1) ** curve
    return e

def sq(f, n, duty=0.5):
    ph = np.cumsum(np.broadcast_to(f, (n,)) / SR)
    return np.where((ph % 1.0) < duty, 1.0, -1.0)

def noise(n):
    return rng.uniform(-1, 1, n)

def lp(x, k):  # one-pole low-pass, k = 0..1 (smaller = darker)
    y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc); y[i] = acc
    return y

def crush(x, steps=16):
    return np.round(x * steps) / steps

def save(name, x, vol=0.8):
    x = np.clip(x / (np.max(np.abs(x)) + 1e-9) * vol, -1, 1)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def n(sec): return int(SR * sec)

# --- dogfight
k = n(0.07); save("gun", crush(noise(k) * 0.6 + sq(np.linspace(900, 300, k), k, 0.3) * 0.5) * env(k, 0.001, 0.07, 2), 0.5)
k = n(0.12); save("enemy_gun", crush(sq(np.linspace(500, 180, k), k, 0.25)) * env(k, 0.001, 0.12, 2), 0.4)
k = n(0.9); f = np.linspace(180, 1400, k); save("laser_charge", crush(sq(f, k, 0.5) * 0.5 + np.sin(np.cumsum(f * 2) / SR * 2 * np.pi) * 0.3) * env(k, 0.3) * np.linspace(0.3, 1, k), 0.4)
k = n(0.8); f = np.linspace(1800, 90, k); save("laser_fire", crush(sq(f, k, 0.5) * 0.6 + noise(k) * 0.4 * env(k, 0.001, 0.25)) * env(k, 0.001, 0.8, 1.5), 0.85)
k = n(0.9); save("explosion", crush(lp(noise(k), 0.08) * 3 + sq(np.linspace(90, 30, k), k, 0.5) * 0.4, 12) * env(k, 0.002, 0.9, 2.2), 0.9)
k = n(1.4); save("explosion_big", crush(lp(noise(k), 0.05) * 3 + sq(np.linspace(70, 22, k), k, 0.5) * 0.5, 10) * env(k, 0.002, 1.4, 1.8), 1.0)
k = n(1.0); save("boost_loop", crush(lp(noise(k), 0.2) * 0.8 + sq(np.full(k, 55.0), k, 0.4) * 0.3), 0.45)  # loops
k = n(0.6); save("drift_boost", crush(sq(np.linspace(200, 900, k), k, 0.5) * 0.5 + lp(noise(k), 0.35)) * env(k, 0.01, 0.6, 1.2), 0.7)
k = n(0.35); save("roll", crush(lp(noise(k), np.float64(0.25)) * np.sin(np.linspace(0, np.pi, k)) ** 2), 0.6)
k = n(0.25); save("dodge", crush(sq(np.linspace(1200, 2400, k), k, 0.5) * env(k, 0.001, 0.25, 2)), 0.35)
k = n(0.45); f = np.where(np.arange(k) < k // 3, 880, np.where(np.arange(k) < 2 * k // 3, 1175, 1568)); save("hoop", crush(sq(f, k, 0.5)) * env(k, 0.002, 0.45, 1.5), 0.4)
k = n(0.25); save("hit", crush(noise(k) * 0.8 + sq(np.linspace(160, 60, k), k, 0.5) * 0.5) * env(k, 0.001, 0.25, 2), 0.7)
k = n(0.5); save("bomb_drop", crush(sq(np.linspace(1400, 300, k), k, 0.5)) * env(k, 0.002, 0.5, 1), 0.3)
k = n(0.18); save("warning", crush(sq(np.full(k, 1320.0), k, 0.5)) * env(k, 0.002, 0.18, 0.5), 0.3)
# --- cards
k = n(0.08); save("card", crush(lp(noise(k), 0.6) * env(k, 0.001, 0.08, 3), 20), 0.5)
clicks = np.zeros(n(0.22))
for t0 in (0.0, 0.05, 0.11, 0.15):
    s = n(t0); kk = n(0.03); clicks[s:s + kk] += (sq(np.full(kk, 2400.0), kk, 0.5) * 0.5 + noise(kk)) * env(kk, 0.0005, 0.03, 3)
save("chips", crush(clicks), 0.45)
k = n(0.5); f = np.where(np.arange(k) < k // 2, 784, 1047); save("win", crush(sq(f, k, 0.25)) * env(k, 0.002, 0.5, 1), 0.35)
k = n(0.45); f = np.where(np.arange(k) < k // 2, 392, 262); save("lose", crush(sq(f, k, 0.5)) * env(k, 0.002, 0.45, 1), 0.3)
# --- UI / idle
k = n(0.05); save("tap", crush(sq(np.full(k, 660.0), k, 0.5) * env(k, 0.001, 0.05, 2)), 0.25)
k = n(0.12); save("buy", crush(sq(np.linspace(500, 1000, k), k, 0.5) * env(k, 0.001, 0.12, 1.5)), 0.3)
k = n(3.2); save("impact_rumble", crush(lp(noise(k), 0.025) * 4 + sq(np.linspace(48, 18, k), k, 0.5) * 0.6 + lp(noise(k), 0.3) * 1.5 * env(k, 0.001, 0.4, 2), 10) * env(k, 0.003, 3.2, 1.4), 1.0)   # asteroid impact
k = n(0.3); save("crunch", crush(lp(noise(k), 0.5) * (np.sin(np.arange(k) / SR * 2 * np.pi * 18) > 0) * env(k, 0.002, 0.3, 1), 8), 0.5)
print("wrote", len(os.listdir(OUT)), "sounds to", OUT)
