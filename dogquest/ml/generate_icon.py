"""
Generate DogQuest app icon: dog paw print on branded background.
Creates a 1024x1024 PNG suitable for flutter_launcher_icons.

Design:
- Rounded square background with warm brown gradient feel (solid color for compatibility)
- White dog paw print (large central pad + 4 toe pads)
- Subtle "DQ" text at the bottom
- High contrast for visibility at all sizes (48x48 to 512x512)

Brand colors from constants.dart:
- bgDeep: #1A0F0A (deep brown)
- bgCard: #2A1F1A (card brown)
- accent: #D4874E (warm amber/copper - uncommon rarity color)
- Primary brown: #4A2F1A (adaptive icon background)
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import os

SIZE = 1024
CENTER = SIZE // 2


def draw_paw_print(draw, cx, cy, scale=1.0, color="white"):
    """Draw a dog paw print centered at (cx, cy)."""

    # Main pad (large bean/heart shape at bottom) - use overlapping ellipses
    pad_w = int(160 * scale)
    pad_h = int(140 * scale)
    pad_y = cy + int(40 * scale)

    # Main pad: a rounded triangle-ish shape made from overlapping ellipses
    # Central large ellipse
    draw.ellipse(
        [cx - pad_w, pad_y - pad_h, cx + pad_w, pad_y + pad_h],
        fill=color,
    )
    # Two smaller ellipses at top-left and top-right to create the "dip" shape
    indent_r = int(50 * scale)
    indent_y = pad_y - pad_h + int(20 * scale)
    # Cut a notch at the top center of the main pad using background color
    # Actually, let's keep it simple -- a single large oval for the main pad

    # Four toe pads (smaller circles above the main pad)
    toe_r = int(62 * scale)  # toe pad radius
    toe_y_base = cy - int(120 * scale)  # vertical center of toe row

    # Toe positions: slight arc above the main pad
    toe_positions = [
        (cx - int(145 * scale), toe_y_base + int(25 * scale)),   # outer left (lower)
        (cx - int(52 * scale),  toe_y_base - int(35 * scale)),   # inner left (higher)
        (cx + int(52 * scale),  toe_y_base - int(35 * scale)),   # inner right (higher)
        (cx + int(145 * scale), toe_y_base + int(25 * scale)),   # outer right (lower)
    ]

    for tx, ty in toe_positions:
        # Slightly oval toe pads (taller than wide)
        tw = int(toe_r * 0.85)
        th = int(toe_r * 1.1)
        draw.ellipse([tx - tw, ty - th, tx + tw, ty + th], fill=color)


def create_icon():
    # Create base image with the app's primary brown background
    bg_color = (74, 47, 26)  # #4A2F1A - the adaptive icon background color
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw rounded square background
    corner_radius = int(SIZE * 0.22)  # ~22% corner radius (Google Play style)
    draw.rounded_rectangle(
        [0, 0, SIZE - 1, SIZE - 1],
        radius=corner_radius,
        fill=bg_color,
    )

    # Add a subtle radial gradient overlay for depth
    # Lighter center, darker edges
    gradient = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(gradient)
    for i in range(80):
        alpha = int(i * 0.7)  # subtle darkening towards edges
        r = SIZE // 2 - i * 4
        if r < 10:
            break
        # We'll skip the gradient for simplicity and rely on the clean design

    # Draw the paw print in warm white/cream color
    paw_color = (255, 248, 235)  # warm white/cream
    # Shift paw up slightly to leave room for text
    draw_paw_print(draw, CENTER, CENTER - int(SIZE * 0.06), scale=1.65, color=paw_color)

    # Add subtle shadow behind paw for depth
    # (We'll create the shadow version first, then overlay the paw)
    # Actually, let's create a cleaner version with shadow:

    img_final = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_final = ImageDraw.Draw(img_final)

    # Background
    draw_final.rounded_rectangle(
        [0, 0, SIZE - 1, SIZE - 1],
        radius=corner_radius,
        fill=bg_color,
    )

    # Add a very subtle inner glow / lighter center
    for i in range(5):
        inset = 80 + i * 40
        alpha_add = 8 - i
        lighter = (74 + alpha_add * 3, 47 + alpha_add * 2, 26 + alpha_add)
        draw_final.rounded_rectangle(
            [inset, inset, SIZE - 1 - inset, SIZE - 1 - inset],
            radius=max(corner_radius - inset, 10),
            fill=lighter,
        )

    # Shadow layer for the paw
    shadow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_layer)
    draw_paw_print(shadow_draw, CENTER + 4, CENTER - int(SIZE * 0.06) + 6,
                   scale=1.65, color=(0, 0, 0, 80))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=12))
    img_final = Image.alpha_composite(img_final, shadow_layer)

    # Paw print
    paw_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    paw_draw = ImageDraw.Draw(paw_layer)
    draw_paw_print(paw_draw, CENTER, CENTER - int(SIZE * 0.06),
                   scale=1.65, color=paw_color)
    img_final = Image.alpha_composite(img_final, paw_layer)

    # Add a subtle accent ring/border
    border_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border_layer)
    accent_color = (212, 135, 78, 100)  # #D4874E with transparency
    border_draw.rounded_rectangle(
        [6, 6, SIZE - 7, SIZE - 7],
        radius=corner_radius - 4,
        outline=accent_color,
        width=4,
    )
    img_final = Image.alpha_composite(img_final, border_layer)

    # Convert to RGB (no transparency) for the final icon
    output = Image.new("RGB", (SIZE, SIZE), bg_color)
    output.paste(img_final, mask=img_final.split()[3])

    return output


def create_adaptive_foreground():
    """Create adaptive icon foreground (paw on transparent background).
    Android adaptive icons use a 108dp canvas with 72dp safe zone (inner 66.67%).
    The foreground should be 1024x1024 with content in the center ~682px."""

    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    paw_color = (255, 248, 235)
    # Scale down and center for the safe zone
    draw_paw_print(draw, CENTER, CENTER - int(SIZE * 0.03), scale=1.3, color=paw_color)

    return img


if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.abspath(__file__))

    # Generate the main square icon
    icon = create_icon()
    icon_path = os.path.join(base_dir, "assets", "app_icon.png")
    icon.save(icon_path, "PNG")
    print(f"Generated: {icon_path} ({icon.size[0]}x{icon.size[1]})")

    # Generate adaptive foreground
    fg = create_adaptive_foreground()
    fg_path = os.path.join(base_dir, "assets", "app_icon_foreground.png")
    fg.save(fg_path, "PNG")
    print(f"Generated: {fg_path} ({fg.size[0]}x{fg.size[1]})")

    # Also save the square version for the legacy icon reference
    square_path = os.path.join(base_dir, "assets", "app_icon_square.png")
    icon.save(square_path, "PNG")
    print(f"Updated:   {square_path}")

    print("\nDone! Now run:")
    print("  cd dogquest && flutter pub run flutter_launcher_icons")
