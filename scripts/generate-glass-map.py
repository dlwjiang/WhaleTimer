"""Bake a small rounded-lens displacement map; no runtime renderer is needed."""
from pathlib import Path
import math
import struct
import zlib

WIDTH, HEIGHT, RADIUS, EDGE = 440, 224, 28, 14
pixels = bytearray()
for y in range(HEIGHT):
    pixels.append(0)  # PNG scanline filter
    for x in range(WIDTH):
        px, py = x + .5 - WIDTH / 2, y + .5 - HEIGHT / 2
        qx, qy = abs(px) - (WIDTH / 2 - RADIUS), abs(py) - (HEIGHT / 2 - RADIUS)
        vx, vy = max(qx, 0), max(qy, 0)
        length = math.hypot(vx, vy)
        distance = length + min(max(qx, qy), 0) - RADIUS
        if length:
            nx, ny = vx / length, vy / length
        else:
            nx, ny = (1, 0) if qx > qy else (0, 1)
        nx *= 1 if px > 0 else -1
        ny *= 1 if py > 0 else -1
        strength = max(0, min(1, 1 + distance / EDGE))
        strength = strength * strength * (3 - 2 * strength)
        # R and G encode inward sampling at the bevel; the center is neutral.
        pixels.extend((round(127.5 - nx * 120 * strength), round(127.5 - ny * 120 * strength), 128, 255))


def chunk(kind, data):
    return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))


output = Path(__file__).resolve().parents[1] / 'public/glass/displacement-map.png'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', WIDTH, HEIGHT, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(pixels, 9)) + chunk(b'IEND', b''))
print(f'{output.name}: {output.stat().st_size} bytes')
