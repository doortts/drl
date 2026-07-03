#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="${1:-$repo_root/src/drl.ico}"
out="${2:-$repo_root/bin/iconfile.icns}"
tmp_root="${TMPDIR:-/tmp}"
tmp_root="${tmp_root%/}"
tmp_dir="$(mktemp -d "$tmp_root/drl-icon.XXXXXX")"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

if [[ ! -f "$src" ]]; then
  echo "Icon source not found: $src" >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "sips is required to generate the macOS app icon." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to generate the macOS app icon." >&2
  exit 1
fi

mkdir -p "$(dirname "$out")"

base_png="$tmp_dir/icon.png"

sips -s format png "$src" --out "$base_png" >/dev/null

for size in 16 32 48 64 128 256 512 1024; do
  sips -z "$size" "$size" "$base_png" --out "$tmp_dir/icon_${size}.png" >/dev/null
done

python3 - "$tmp_dir" "$out" <<'PY'
from pathlib import Path
import struct
import sys
import zlib

tmp_dir = Path(sys.argv[1])
out = Path(sys.argv[2])


def read_png_rgba(path):
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Not a PNG file: {path}")

    offset = 8
    compressed = b""
    width = height = color_type = None
    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        chunk = data[offset + 8:offset + 8 + length]
        offset += length + 12
        if kind == b"IHDR":
            width, height = struct.unpack(">II", chunk[:8])
            bit_depth = chunk[8]
            color_type = chunk[9]
            if bit_depth != 8 or color_type not in (2, 6):
                raise ValueError(f"Unsupported PNG format in {path}")
        elif kind == b"IDAT":
            compressed += chunk
        elif kind == b"IEND":
            break

    channels = 3 if color_type == 2 else 4
    stride = width * channels
    raw = zlib.decompress(compressed)
    rows = []
    previous = [0] * stride
    index = 0

    def paeth(left, up, upper_left):
        prediction = left + up - upper_left
        left_delta = abs(prediction - left)
        up_delta = abs(prediction - up)
        upper_left_delta = abs(prediction - upper_left)
        if left_delta <= up_delta and left_delta <= upper_left_delta:
            return left
        if up_delta <= upper_left_delta:
            return up
        return upper_left

    for _ in range(height):
        filter_type = raw[index]
        index += 1
        scanline = list(raw[index:index + stride])
        index += stride
        row = [0] * stride
        for i, value in enumerate(scanline):
            left = row[i - channels] if i >= channels else 0
            up = previous[i]
            upper_left = previous[i - channels] if i >= channels else 0
            if filter_type == 0:
                decoded = value
            elif filter_type == 1:
                decoded = value + left
            elif filter_type == 2:
                decoded = value + up
            elif filter_type == 3:
                decoded = value + ((left + up) // 2)
            elif filter_type == 4:
                decoded = value + paeth(left, up, upper_left)
            else:
                raise ValueError(f"Unsupported PNG filter {filter_type} in {path}")
            row[i] = decoded & 0xff

        pixels = []
        for i in range(0, stride, channels):
            red, green, blue = row[i:i + 3]
            alpha = row[i + 3] if channels == 4 else 255
            pixels.append((red, green, blue, alpha))
        rows.extend(pixels)
        previous = row

    return rows


def chunk(kind, data):
    return kind.encode("ascii") + struct.pack(">I", len(data) + 8) + data


entries = [
    ("is32", "icon_16.png"),
    ("s8mk", "icon_16.png"),
    ("il32", "icon_32.png"),
    ("l8mk", "icon_32.png"),
    ("ih32", "icon_48.png"),
    ("h8mk", "icon_48.png"),
    ("ic11", "icon_32.png"),
    ("ic12", "icon_64.png"),
    ("ic07", "icon_128.png"),
    ("ic13", "icon_256.png"),
    ("ic08", "icon_256.png"),
    ("ic14", "icon_512.png"),
    ("ic09", "icon_512.png"),
    ("ic10", "icon_1024.png"),
]

chunks = []
for kind, filename in entries:
    if kind in {"is32", "il32", "ih32"}:
        pixels = read_png_rgba(tmp_dir / filename)
        data = bytes(channel for pixel in pixels for channel in (pixel[3], pixel[0], pixel[1], pixel[2]))
    elif kind in {"s8mk", "l8mk", "h8mk"}:
        pixels = read_png_rgba(tmp_dir / filename)
        data = bytes(pixel[3] for pixel in pixels)
    else:
        data = (tmp_dir / filename).read_bytes()
    chunks.append(chunk(kind, data))

out.write_bytes(b"icns" + struct.pack(">I", 8 + sum(len(chunk) for chunk in chunks)) + b"".join(chunks))
PY
