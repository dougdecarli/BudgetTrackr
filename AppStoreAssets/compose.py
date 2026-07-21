#!/usr/bin/env python3
"""Compose localized, App Store-ready screenshots from real Simulator captures."""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"
BACKGROUNDS = ROOT / "backgrounds"
FINAL = ROOT / "final"

CANVAS = (1320, 2868)  # Current 6.9-inch iPhone portrait screenshot size.
SCREEN_WIDTH = 1110
SCREEN_X = (CANVAS[0] - SCREEN_WIDTH) // 2
SCREEN_Y = 760

FONT_DISPLAY_BOLD = "/Library/Fonts/SF-Pro-Display-Bold.otf"
FONT_TEXT_REGULAR = "/Library/Fonts/SF-Pro-Text-Regular.otf"
FONT_TEXT_SEMIBOLD = "/Library/Fonts/SF-Pro-Text-Semibold.otf"

APP_ICON = ROOT.parent / "FinanceApp" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"

SCREENS = [
    {
        "name": "01-seu-mes-em-um-olhar",
        "raw": "01-dashboard.png",
        "background": "emerald.png",
        "eyebrow": "VISÃO MENSAL",
        "headline": "Seu mês inteiro.\nEm um olhar.",
        "subtitle": "Renda, gastos e resultado no mesmo lugar.",
        "accent": "#35E778",
    },
    {
        "name": "02-para-onde-foi",
        "raw": "02-categories.png",
        "background": "violet-amber.png",
        "eyebrow": "CATEGORIAS",
        "headline": "Veja para onde\nseu dinheiro foi.",
        "subtitle": "Cada categoria, cada compra, cada detalhe.",
        "accent": "#FFAD33",
    },
    {
        "name": "03-tendencias-claras",
        "raw": "03-trends.png",
        "background": "cobalt.png",
        "eyebrow": "TENDÊNCIAS",
        "headline": "Transforme números\nem decisões.",
        "subtitle": "Compare renda, gastos e evolução ao longo do ano.",
        "accent": "#43D7FF",
    },
    {
        "name": "04-importe-a-fatura",
        "raw": "05-invoice.png",
        "background": "cobalt.png",
        "eyebrow": "FATURA DO CARTÃO",
        "headline": "Importe a fatura.\nPoupe horas.",
        "subtitle": "Nubank, Itaú e Santander — direto do PDF.",
        "accent": "#4AA3FF",
    },
    {
        "name": "05-compras-organizadas",
        "raw": "06-transactions.png",
        "background": "violet-amber.png",
        "eyebrow": "CATEGORIZAÇÃO",
        "headline": "Compras organizadas.\nAutomaticamente.",
        "subtitle": "Revise uma vez e o app aprende para as próximas.",
        "accent": "#B68CFF",
    },
    {
        "name": "06-pdf-sem-digitacao",
        "raw": "07-onboarding-invoice.png",
        "background": "emerald.png",
        "eyebrow": "IMPORTAÇÃO INTELIGENTE",
        "headline": "Seu PDF vira\norganização.",
        "subtitle": "O app lê cada compra para você.",
        "accent": "#35E778",
    },
    {
        "name": "07-seus-dados-sao-seus",
        "raw": "08-onboarding-privacy.png",
        "background": "cobalt.png",
        "eyebrow": "PRIVACIDADE",
        "headline": "Seus dados\nsão seus.",
        "subtitle": "No seu iCloud. Nunca nos nossos servidores.",
        "accent": "#43D7FF",
    },
]

EN_SCREENS = [
    {
        "name": "01-your-month-at-a-glance",
        "raw": "01-dashboard.png",
        "background": "emerald.png",
        "eyebrow": "MONTHLY OVERVIEW",
        "headline": "Your whole month.\nAt a glance.",
        "subtitle": "Income, spending, and balance in one place.",
        "accent": "#35E778",
    },
    {
        "name": "02-see-where-it-went",
        "raw": "02-categories.png",
        "background": "violet-amber.png",
        "eyebrow": "CATEGORIES",
        "headline": "See where your\nmoney went.",
        "subtitle": "Every category, every purchase, every detail.",
        "accent": "#FFAD33",
    },
    {
        "name": "03-turn-numbers-into-decisions",
        "raw": "03-trends.png",
        "background": "cobalt.png",
        "eyebrow": "TRENDS",
        "headline": "Turn numbers\ninto decisions.",
        "subtitle": "Compare income, spending, and progress over time.",
        "accent": "#43D7FF",
    },
    {
        "name": "04-import-statements-save-hours",
        "raw": "05-invoice.png",
        "background": "cobalt.png",
        "eyebrow": "CARD STATEMENTS",
        "headline": "Import statements.\nSave hours.",
        "subtitle": "Nubank, Itaú, and Santander — straight from PDF.",
        "accent": "#4AA3FF",
    },
    {
        "name": "05-purchases-organized",
        "raw": "06-transactions.png",
        "background": "violet-amber.png",
        "eyebrow": "AUTO-CATEGORIZATION",
        "headline": "Purchases organized.\nAutomatically.",
        "subtitle": "Review once and the app learns for next time.",
        "accent": "#B68CFF",
    },
    {
        "name": "06-turn-pdfs-into-clarity",
        "raw": "07-onboarding-invoice.png",
        "background": "emerald.png",
        "eyebrow": "SMART IMPORT",
        "headline": "Turn PDFs\ninto clarity.",
        "subtitle": "The app reads every purchase for you.",
        "accent": "#35E778",
    },
    {
        "name": "07-your-data-stays-yours",
        "raw": "08-onboarding-privacy.png",
        "background": "cobalt.png",
        "eyebrow": "PRIVACY",
        "headline": "Your data\nstays yours.",
        "subtitle": "In your iCloud. Never on our servers.",
        "accent": "#43D7FF",
    },
]


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.LANCZOS)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def add_device(canvas: Image.Image, screenshot_path: Path) -> None:
    screenshot = Image.open(screenshot_path).convert("RGB")
    screen_height = round(SCREEN_WIDTH * screenshot.height / screenshot.width)
    screenshot = screenshot.resize((SCREEN_WIDTH, screen_height), Image.Resampling.LANCZOS)
    radius = 82
    mask = rounded_mask(screenshot.size, radius)

    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    shadow_mask = Image.new("L", CANVAS, 0)
    ImageDraw.Draw(shadow_mask).rounded_rectangle(
        (SCREEN_X - 2, SCREEN_Y + 20, SCREEN_X + SCREEN_WIDTH + 2, SCREEN_Y + screen_height + 24),
        radius + 10,
        fill=205,
    )
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(42))
    shadow.putalpha(shadow_mask)
    canvas.alpha_composite(shadow)

    border = Image.new("RGBA", (SCREEN_WIDTH + 18, screen_height + 18), (255, 255, 255, 0))
    ImageDraw.Draw(border).rounded_rectangle(
        (1, 1, border.width - 2, border.height - 2),
        radius + 9,
        fill=(12, 15, 24, 255),
        outline=(255, 255, 255, 76),
        width=3,
    )
    canvas.alpha_composite(border, (SCREEN_X - 9, SCREEN_Y - 9))

    device = Image.new("RGBA", screenshot.size, (0, 0, 0, 0))
    device.paste(screenshot, (0, 0), mask)
    canvas.alpha_composite(device, (SCREEN_X, SCREEN_Y))


def add_header(canvas: Image.Image, spec: dict[str, str], icon: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas)
    accent = spec["accent"]

    icon_size = 70
    icon_small = icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    icon_mask = rounded_mask((icon_size, icon_size), 16)
    canvas.paste(icon_small, (82, 80), icon_mask)

    draw.text(
        (172, 101),
        "BUDGETTRACKR",
        font=font(FONT_TEXT_SEMIBOLD, 29),
        fill=(255, 255, 255, 228),
        spacing=2,
    )

    eyebrow_font = font(FONT_TEXT_SEMIBOLD, 27)
    eyebrow_bbox = draw.textbbox((0, 0), spec["eyebrow"], font=eyebrow_font)
    eyebrow_width = eyebrow_bbox[2] - eyebrow_bbox[0]
    pill = (82, 190, 82 + eyebrow_width + 54, 246)
    accent_rgb = tuple(int(accent[i : i + 2], 16) for i in (1, 3, 5))
    draw.rounded_rectangle(pill, radius=28, fill=(*accent_rgb, 255))
    draw.text((109, 202), spec["eyebrow"], font=eyebrow_font, fill=(4, 8, 20, 255))

    draw.multiline_text(
        (82, 282),
        spec["headline"],
        font=font(FONT_DISPLAY_BOLD, 92),
        fill=(255, 255, 255, 255),
        spacing=2,
    )
    draw.text(
        (84, 548),
        spec["subtitle"],
        font=font(FONT_TEXT_REGULAR, 38),
        fill=(222, 228, 240, 232),
    )


def compose(spec: dict[str, str], icon: Image.Image, raw_dir: Path) -> Image.Image:
    background = cover(Image.open(BACKGROUNDS / spec["background"]), CANVAS).convert("RGBA")

    # Subtle dark veil keeps the campaign typography and real app UI dominant.
    veil = Image.new("RGBA", CANVAS, (2, 5, 16, 38))
    background.alpha_composite(veil)

    add_header(background, spec, icon)
    add_device(background, raw_dir / spec["raw"])
    return background.convert("RGB")


def make_contact_sheet(outputs: list[Path], output_name: str) -> None:
    thumb_w = 330
    thumb_h = round(thumb_w * CANVAS[1] / CANVAS[0])
    sheet = Image.new("RGB", (thumb_w * 4, thumb_h * 2), (6, 8, 18))
    for index, output in enumerate(outputs):
        image = Image.open(output).convert("RGB")
        image.thumbnail((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        x = (index % 4) * thumb_w
        y = (index // 4) * thumb_h
        sheet.paste(image, (x, y))
    sheet.save(ROOT / output_name, quality=95)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--locale", choices=("pt", "en"), default="pt")
    args = parser.parse_args()

    if args.locale == "en":
        raw_dir = ROOT / "raw-en"
        final_dir = ROOT / "final-en"
        screens = EN_SCREENS
        contact_name = "contact-sheet-en.png"
    else:
        raw_dir = RAW
        final_dir = FINAL
        screens = SCREENS
        contact_name = "contact-sheet.png"

    final_dir.mkdir(parents=True, exist_ok=True)
    icon = Image.open(APP_ICON).convert("RGB")
    outputs: list[Path] = []
    for spec in screens:
        output = final_dir / f"{spec['name']}.png"
        compose(spec, icon, raw_dir).save(output, optimize=True)
        outputs.append(output)
    make_contact_sheet(outputs, contact_name)


if __name__ == "__main__":
    main()
