from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parent
PANELS = ROOT / "panels"
ACCEPTED = [
    "P001-E-v3.png",
    "P002-N-v1.png",
    "P003-N-v1.png",
    "P004-B-v1.png",
    "P005-C-v1.png",
    "P006-E-v1.png",
    "P007-N-v1.png",
    "P008-N-v1.png",
    "P009-B-v1.png",
    "P010-E-v1.png",
    "P011-N-v1.png",
    "P012-B-v2.png",
]


def clean_copy(source: Path) -> Path:
    target = source.with_name(f"{source.stem}-clean.png")
    with Image.open(source) as image:
        clean = image.convert("RGB")
        clean.save(target, "PNG", optimize=True)
    return target


def contact_sheet(paths: list[Path]) -> None:
    cell_width, cell_height = 360, 440
    columns, rows = 4, 3
    canvas = Image.new("RGB", (columns * cell_width, rows * cell_height), "#ece7df")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()

    for index, path in enumerate(paths):
        with Image.open(path) as image:
            preview = ImageOps.contain(image.convert("RGB"), (330, 395))
        x = (index % columns) * cell_width + (cell_width - preview.width) // 2
        y = (index // columns) * cell_height + 28 + (395 - preview.height) // 2
        canvas.paste(preview, (x, y))
        draw.text((index % columns * cell_width + 14, index // columns * cell_height + 10), path.stem, fill="#332f2b", font=font)

    canvas.save(ROOT / "style-master-v2-contact-sheet.webp", "WEBP", quality=90, method=6)


def vertical_strip(paths: list[Path]) -> None:
    width = 690
    background = "#f7f3ed"
    resized: list[Image.Image] = []
    for path in paths:
        with Image.open(path) as image:
            rgb = image.convert("RGB")
            height = round(rgb.height * width / rgb.width)
            resized.append(rgb.resize((width, height), Image.Resampling.LANCZOS))

    gaps = [100] * (len(resized) - 1)
    gaps[4] = 320
    gaps[8] = 320
    total_height = sum(image.height for image in resized) + sum(gaps)
    strip = Image.new("RGB", (width, total_height), background)
    y = 0
    for index, image in enumerate(resized):
        strip.paste(image, (0, y))
        y += image.height
        if index < len(gaps):
            y += gaps[index]
    strip.save(ROOT / "style-master-v2-strip.webp", "WEBP", quality=88, method=6)


def main() -> None:
    sources = [PANELS / name for name in ACCEPTED]
    missing = [str(path) for path in sources if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing accepted panels: " + ", ".join(missing))

    clean = [clean_copy(path) for path in sources]
    contact_sheet(clean)
    vertical_strip(clean)

    for path in clean:
        with Image.open(path) as image:
            print(f"{path.name}\t{image.width}x{image.height}\t{image.mode}")


if __name__ == "__main__":
    main()
