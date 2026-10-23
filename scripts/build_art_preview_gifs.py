"""Encode review animations from existing native Godot captures; never alter sources."""
from pathlib import Path
import json
import hashlib
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CAPTURE = ROOT / 'docs/screenshots/art-finish-v3/orchard-motion/1440x900'

def main():
    report_path = CAPTURE / 'capture-report.json'
    report = json.loads(report_path.read_text(encoding='utf-8'))
    rows = report['frames']
    frames = []
    sources = []
    for row in rows:
        source = Path(row['path']).resolve()
        if not source.is_relative_to(CAPTURE.resolve()) or not source.is_file():
            raise ValueError(f'Capture frame outside expected directory: {source}')
        with Image.open(source) as im:
            frame = im.convert('RGB')
            frame.thumbnail((960, 600), Image.Resampling.LANCZOS)
            frames.append(frame)
        sources.append({'path': source.relative_to(ROOT).as_posix(),
                        'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                        'engine_time': row['time']})
    if not frames:
        raise ValueError('No native captured frames')
    output = CAPTURE / 'orchard-demonstration.gif'
    frames[0].save(output, save_all=True, append_images=frames[1:],
                   duration=100, loop=0, optimize=False, disposal=2)
    with Image.open(output) as check:
        assert check.n_frames == len(frames)
        size = check.size
    metadata = {'source': report_path.relative_to(ROOT).as_posix(),
                'source_frame_count': len(frames), 'encoded_frame_count': len(frames),
                'encoded_size': size, 'encoded_fps': 10,
                'encoded_duration_seconds': len(frames) / 10.0,
                'note': 'Preview resizes native frames; no interpolated or generated frames. Original PNGs are retained.',
                'output': output.relative_to(ROOT).as_posix(),
                'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
                'frames': sources}
    (CAPTURE / 'preview-gif.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    print(json.dumps({key: value for key, value in metadata.items() if key != 'frames'}))

if __name__ == '__main__':
    main()
