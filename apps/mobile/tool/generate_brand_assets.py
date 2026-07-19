#!/usr/bin/env python3
"""Panelya marka varliklarini (launcher ikonu + splash) programatik uretir.

Kaynak: app/globals.css `.brand-mark` (SALT OKUNUR referans) -- koyu zemin
uzerinde mint, donuk kose kare + iki nokta goz + bir gulumseme cizgisinden
olusan basit bir isaret. Bu script o bicimi sadelestirilmis bir vektor
tanimi olarak (asagidaki `draw_mark_tile`) kod icinde tutar; TEK gercek
kaynak bu fonksiyondur, repoya ayrica bir "master" SVG/PNG committlenmez.
Script her calistirildiginda ayni girdiden ayni cikctilari (deterministik)
uretir, boylece tekrarlanabilir.

Kullanim:
    python3 apps/mobile/tool/generate_brand_assets.py

Bagimlilik: yalnizca Pillow (PIL). Bu bir gelistirme-zamani uretim
script'idir; Flutter runtime'ina veya pubspec bagimliliklarina eklenmez
(bkz. AGENTS.md gerekcesiz dependency yasagi -- flutter_launcher_icons /
flutter_native_splash paketleri kasitli olarak KULLANILMADI).
"""

from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# Marka renkleri (kaynak: apps/mobile/lib/app/theme/tokens.dart /
# app/globals.css, docs/mobile-handoff.md tasarim token tablosu).
# ---------------------------------------------------------------------------
BACKGROUND_HEX = "#07100E"
MINT_HEX = "#66E2AE"

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
IOS_APPICON = REPO_ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
IOS_LAUNCHIMAGE = REPO_ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
ANDROID_RES = REPO_ROOT / "android/app/src/main/res"

# Isaretin "31 css birimlik" tuval icinde supersample cozunurlugu. Yuksek
# tutulup sonra hedef boyuta LANCZOS ile kuculterek anti-alias saglanir.
UNIT_PX = 2000
ROTATION_DEGREES = -5  # app/globals.css .brand-mark { transform: rotate(-5deg) }


def _hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


BACKGROUND_RGB = _hex_to_rgb(BACKGROUND_HEX)
MINT_RGB = _hex_to_rgb(MINT_HEX)


def draw_mark_tile() -> Image.Image:
    """31x31 css-birim isareti UNIT_PX cozunurlukte, rotasyonlu, seffaf
    zemin uzerinde ciz. `.brand-mark` (mint donuk-kose kare) + iki `i`
    (goz noktalari) + ucuncu `i` (gulumseme cubugu) sadelestirilmis
    bicimidir; metin/harf veya ince detay yoktur.
    """
    scale = UNIT_PX / 31.0

    # Rotasyon oncesi kare tuval: kenarlari asmayan bir kare cizip sonra
    # `expand=True` ile donduruyoruz, boylece kose kirpma olmaz.
    tile = Image.new("RGBA", (UNIT_PX, UNIT_PX), (0, 0, 0, 0))
    draw = ImageDraw.Draw(tile)

    # .brand-mark: donuk kose kare (css'teki 9/13/10/13 karisik kose
    # yaricaplari sadelestirilerek tek, ortalama-yakin bir yaricapa
    # indirgendi -- kucuk boyutta okunabilirlik icin).
    corner_radius = round(11 * scale)
    draw.rounded_rectangle(
        [(0, 0), (UNIT_PX - 1, UNIT_PX - 1)],
        radius=corner_radius,
        fill=(*MINT_RGB, 255),
    )

    # .brand-mark i:nth-child(1) / (2): iki goz noktasi (6x6 daire,
    # sol/sag simetrik, css left:7/top:10 ve right:7/top:10).
    eye_d = 6 * scale
    eye_y0 = 10 * scale
    eye_y1 = eye_y0 + eye_d
    left_eye_x0 = 7 * scale
    right_eye_x0 = (31 - 7 - 6) * scale
    for x0 in (left_eye_x0, right_eye_x0):
        draw.ellipse(
            [(x0, eye_y0), (x0 + eye_d, eye_y1)],
            fill=(*BACKGROUND_RGB, 255),
        )

    # .brand-mark i:nth-child(3): gulumseme cubugu (10x4 dikdortgen,
    # left:11, bottom:7). Css'teki karma kose yaricapi (1px 1px 6px 6px)
    # tek bir "hap" (tam donuk, radius = height/2) olarak sadelestirildi.
    mouth_w = 10 * scale
    mouth_h = 4 * scale
    mouth_x0 = 11 * scale
    mouth_y1 = UNIT_PX - 7 * scale
    mouth_y0 = mouth_y1 - mouth_h
    draw.rounded_rectangle(
        [(mouth_x0, mouth_y0), (mouth_x0 + mouth_w, mouth_y1)],
        radius=mouth_h / 2,
        fill=(*BACKGROUND_RGB, 255),
    )

    rotated = tile.rotate(
        ROTATION_DEGREES,
        resample=Image.BICUBIC,
        expand=True,
        fillcolor=(0, 0, 0, 0),
    )
    return rotated


_MARK_TILE = draw_mark_tile()


def render_mark(px_size: int, fill_ratio: float = 0.62) -> Image.Image:
    """Isareti seffaf px_size x px_size bir tuvalin ortasina, tuvalin
    `fill_ratio` oranini kaplayacak sekilde yerlestirir (buyuk kenar baz
    alinarak) ve donen RGBA image'i dondurur.
    """
    tile = _MARK_TILE
    target_major = max(1, round(px_size * fill_ratio))
    scale = target_major / max(tile.width, tile.height)
    new_size = (max(1, round(tile.width * scale)), max(1, round(tile.height * scale)))
    resized = tile.resize(new_size, Image.LANCZOS)

    canvas = Image.new("RGBA", (px_size, px_size), (0, 0, 0, 0))
    offset = (
        (px_size - resized.width) // 2,
        (px_size - resized.height) // 2,
    )
    canvas.alpha_composite(resized, offset)
    return canvas


def render_flat_icon(px_size: int, fill_ratio: float = 0.62) -> Image.Image:
    """Tam kapsama (full-bleed) kare ikon: #07100e zemin + ortalanmis mint
    isaret, alfa kanali olmadan (RGB) -- iOS App Store ikon kurallarina
    uygun (marketing 1024 ikonunda alfa kabul edilmez).
    """
    canvas = Image.new("RGB", (px_size, px_size), BACKGROUND_RGB)
    mark = render_mark(px_size, fill_ratio=fill_ratio)
    canvas.paste(mark, (0, 0), mark)
    return canvas


def render_adaptive_foreground(px_size: int) -> Image.Image:
    """Android adaptive icon foreground katmani: seffaf zemin + isaret,
    Google'in 108dp tuval / ~66dp guvenli bolge kuralina uyacak sekilde
    kucuk bir doldurma orani (fill_ratio) ile ortalanir.
    """
    # 108dp tuvalde 66dp guvenli bolge ~= %61; rahat bir pay icin biraz
    # daha kucuk tutuldu.
    return render_mark(px_size, fill_ratio=0.55)


def render_splash_mark(px_size: int) -> Image.Image:
    """Splash ekraninda ortada gorunecek kucuk mint isaret (seffaf zemin)."""
    return render_mark(px_size, fill_ratio=0.7)


# ---------------------------------------------------------------------------
# iOS AppIcon.appiconset -- Contents.json'daki her benzersiz dosya adi icin
# tam piksel boyutu (size * scale). Contents.json DEGISTIRILMEDI; yalnizca
# zaten listelenen dosyalarin piksel icerigi yenilendi.
# ---------------------------------------------------------------------------
IOS_APPICON_SIZES: dict[str, int] = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

# iOS LaunchImage.imageset -- storyboard'daki merkezi kucuk isaret gorseli
# (seffaf zemin; storyboard view'in kendi #07100e arka plani gorunur).
IOS_LAUNCHIMAGE_SIZES: dict[str, int] = {
    "LaunchImage.png": 120,
    "LaunchImage@2x.png": 240,
    "LaunchImage@3x.png": 360,
}

# Android legacy (API < 26) duz mipmap ic_launcher.png boyutlari.
ANDROID_LEGACY_ICON_SIZES: dict[str, int] = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Android adaptive icon foreground -- 108dp tuval, yogunluk carpanlari.
ANDROID_ADAPTIVE_FOREGROUND_SIZES: dict[str, int] = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}


def write_png(image: Image.Image, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG")


def generate_ios_appicons() -> None:
    for filename, px in IOS_APPICON_SIZES.items():
        icon = render_flat_icon(px)
        write_png(icon, IOS_APPICON / filename)


def generate_ios_launchimages() -> None:
    for filename, px in IOS_LAUNCHIMAGE_SIZES.items():
        mark = render_splash_mark(px)
        write_png(mark, IOS_LAUNCHIMAGE / filename)


def generate_android_legacy_icons() -> None:
    for folder, px in ANDROID_LEGACY_ICON_SIZES.items():
        icon = render_flat_icon(px)
        write_png(icon, ANDROID_RES / folder / "ic_launcher.png")


def generate_android_adaptive_foreground() -> None:
    for folder, px in ANDROID_ADAPTIVE_FOREGROUND_SIZES.items():
        fg = render_adaptive_foreground(px)
        write_png(fg, ANDROID_RES / folder / "ic_launcher_foreground.png")


def main() -> None:
    generate_ios_appicons()
    generate_ios_launchimages()
    generate_android_legacy_icons()
    generate_android_adaptive_foreground()
    print("Marka varliklari uretildi:")
    print(f"  iOS AppIcon:      {len(IOS_APPICON_SIZES)} dosya -> {IOS_APPICON}")
    print(f"  iOS LaunchImage:  {len(IOS_LAUNCHIMAGE_SIZES)} dosya -> {IOS_LAUNCHIMAGE}")
    print(f"  Android legacy:   {len(ANDROID_LEGACY_ICON_SIZES)} dosya -> {ANDROID_RES}/mipmap-*/ic_launcher.png")
    print(
        "  Android adaptive: "
        f"{len(ANDROID_ADAPTIVE_FOREGROUND_SIZES)} dosya -> "
        f"{ANDROID_RES}/mipmap-*/ic_launcher_foreground.png"
    )


if __name__ == "__main__":
    main()
