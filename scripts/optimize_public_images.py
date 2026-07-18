from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PUBLIC_IMAGES = ROOT / "public" / "images"
SOURCE_SUFFIXES = {".png", ".jpg", ".jpeg"}


def optimize(source: Path, *, quality: int, force: bool) -> tuple[Path, int, int]:
    target = source.with_suffix(".webp")
    if target.exists() and not force:
        return target, source.stat().st_size, target.stat().st_size

    with Image.open(source) as image:
        frame = image.convert("RGBA" if "A" in image.getbands() else "RGB")
        frame.save(target, "WEBP", quality=quality, method=6, exact=True)

    return target, source.stat().st_size, target.stat().st_size


def main() -> None:
    parser = argparse.ArgumentParser(description="Create Git-friendly WebP siblings for public raster assets.")
    parser.add_argument("--quality", type=int, default=84)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    sources = sorted(
        path
        for path in PUBLIC_IMAGES.rglob("*")
        if path.is_file() and path.suffix.lower() in SOURCE_SUFFIXES
    )
    before = 0
    after = 0
    for source in sources:
        target, source_bytes, target_bytes = optimize(source, quality=args.quality, force=args.force)
        before += source_bytes
        after += target_bytes
        print(f"{source.relative_to(ROOT)} -> {target.relative_to(ROOT)} ({target_bytes / 1024:.1f} KiB)")

    ratio = (after / before * 100) if before else 0
    print(f"Converted {len(sources)} assets: {before / 1024 / 1024:.2f} MiB -> {after / 1024 / 1024:.2f} MiB ({ratio:.1f}%).")


if __name__ == "__main__":
    main()
