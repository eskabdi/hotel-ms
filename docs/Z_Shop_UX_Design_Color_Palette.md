# Z Shop — UX Design Color Palette

> Extracted from the live Z Shop application (`https://e1bz24m7h2y1-deploy.space-z.ai/`)
> Framework: **Next.js + Tailwind CSS v4** (oklab color space) | Font: **Geist Sans / Geist Mono**

---

## 1. Design System Overview

Z Shop uses a **multi-accent warm palette** built on a clean white foundation. The design language is modern, minimal, and trust-driven — similar in spirit to Amazon's clean aesthetic but with a warmer, more vibrant accent system. Colors are defined using CSS custom properties in the **oklab** perceptual color space via Tailwind CSS v4, ensuring consistent perceived lightness across hues.

The palette is organized into four tiers:

| Tier | Role | Count |
|------|------|-------|
| **Core Neutrals** | Background, text, borders, dividers | 6 |
| **Primary Accents** | CTAs, hero gradients, brand moments | 8 |
| **Semantic Colors** | Sale badges, ratings, status indicators | 5 |
| **Full Tailwind Scale** | Extended system colors (red → violet) | 70+ |

---

## 2. Core Neutral Palette

These are the foundational whites, blacks, and grays that form the canvas of the entire application.

| Swatch | Name | Hex | Lab Value | Usage |
|--------|------|-----|-----------|-------|
| ⬜ | **White** | `#FFFFFF` | `lab(100 0 0)` | Page background, card surfaces, modal overlays |
| ⬛ | **Primary Text** | `#041009` | `lab(2.75 0 0)` | Headings (h2, h3), body text, labels |
| 🔲 | **Dark Surface** | `#18181B` | `lab(8.31 0.62 -2.17)` | Footer background, dark sections, overlay panels |
| 🩶 | **Footer Text** | `#D3D4D8` | `lab(84.98 0.60 -2.18)` | Footer links, secondary text on dark backgrounds |
| 🩻 | **Light Muted BG** | `#F4F4F5` | `lab(96.16 0.10 -0.36)` | Subtle section dividers, disabled states, hover fills |
| 🪨 | **Border Gray** | `#E5E5E5` | `lab(90.95 0 0)` | Card borders, input borders, divider lines, separator lines |
| 🩶 | **Mid Gray** | `#737373` | `lab(48.50 0 0)` | Placeholder text, disabled labels, secondary metadata |
| ⬛ | **Dark Gray** | `#3E3F46` | `lab(26.80 1.35 -4.68)` | Muted text on light backgrounds, subtle descriptions |

### Neutral Usage Rules

- **Background**: Always `#FFFFFF`. No off-white or tinted backgrounds for main content areas.
- **Text hierarchy**: Primary text `#041009` → Secondary text `#737373` → Tertiary `#3E3F46`.
- **Borders**: `#E5E5E5` at full opacity for card outlines; `rgba(229, 229, 229, 0.6)` for softer separators.
- **Dark sections** (footer, promotional banners): Background `#18181B`, text `#D3D4D8`.

---

## 3. Primary Accent Palette

Z Shop's identity is built on a **warm amber-orange** primary, supported by a family of vibrant secondary accents. Unlike typical e-commerce sites that use a single brand color, Z Shop employs a multi-accent approach where each product category and UI element can carry its own color identity.

### 3.1 Amber / Gold — Primary Brand Accent

The dominant warm tone used across hero banners, promotional badges, primary CTA backgrounds, and the "Today's Deals" section.

| Swatch | Name | Hex | Usage |
|--------|------|-----|-------|
| 🟡 | **Amber 400** | `#FCBB00` | Star ratings, warning indicators |
| 🟡 | **Amber 300** | `#FFD236` | Sale price highlights, deal badges |
| 🟡 | **Gold** | `#FFB800` | Hero gradient midpoint, category icons, featured labels |
| 🟡 | **Amber 200** | `#FEE685` | Soft highlight backgrounds, hover states on gold elements |
| 🟡 | **Gold Light** | `#FFC600` | Hero gradient endpoint, shimmer effects |
| 🟠 | **Orange 500** | `#FF9900` | Hero gradient start, deal percentage badges, CTA hover |
| 🟠 | **Deep Orange** | `#E77000` | "Deal" text labels, urgency text |
| 🟠 | **CTA Orange** | `#FF6800` | Add-to-cart buttons, primary action backgrounds |
| 🟠 | **Orange 600** | `#F05100` | CTA hover/active state, pressed buttons |
| 🟤 | **Gold Brown** | `#BF4C00` | Heavy discount labels, premium tier badges |

### 3.2 Hero Gradient System

The hero carousel uses smooth, perceptually-uniform gradients created in oklab space. These are the three primary hero gradients:

```
Gradient 1 — Amber Sunrise (Electronics hero)
  linear-gradient(to right, #FF9900 0%, #FFB800 50%, #FFC600 100%)

Gradient 2 — Pink Fuchsia (Audio hero)
  linear-gradient(to right bottom, #FF2455 0%, #F73799 100%)

Gradient 3 — Emerald Tide (Home & Kitchen hero)
  linear-gradient(to right bottom, #00BB7E 0%, #00BBA7 100%)
```

### 3.3 Secondary Accents

| Swatch | Name | Hex | Usage |
|--------|------|-----|-------|
| 🟢 | **Emerald 400** | `#00D294` | "In Stock" badges, success states, eco-friendly labels |
| 🟢 | **Emerald 600** | `#009767` | Green text links, confirmations |
| 🟢 | **Teal 500** | `#00BBA7` | Category icons, secondary success |
| 🔵 | **Blue 500** | `#3080FF` | Hyperlinks, informational badges |
| 🔵 | **Blue 600** | `#155DFC` | Link hover state, selected filters |
| 🔵 | **Blue 700** | `#1447E6` | Active/pressed link state |
| 🟣 | **Violet 400** | `#A685FF` | Beauty category accent, creative labels |
| 🟣 | **Violet 500** | `#8D54FF` | Premium/boutique badges, "Z Prime" branding |

---

## 4. Semantic Color Tokens

These colors carry specific meaning and should only be used for their intended purpose.

| Token | Hex | Meaning | Used On |
|-------|-----|---------|---------|
| `--color-sale` | `#C90034` | Discount / sale | "% OFF" badges, strikethrough price labels, deal cards |
| `--color-sale-hot` | `#FF2455` | Hot deal / urgent | Limited-time deal gradients, flash sale banners |
| `--color-fuchsia` | `#F73799` | Trending / featured | "Featured" badges, trending product ribbons |
| `--color-success` | `#00D393` | Available / in-stock | Stock status indicators, order confirmed |
| `--color-warning` | `#FFD134` | Low stock / caution | "Only 3 left" warnings, review star fill |
| `--color-info` | `#3080FF` | Informational | Help links, info tooltips, learn-more links |
| `--color-subscribe-bg` | `#FFF2C7` | Warm highlight | Newsletter CTA background, promotional callout boxes |
| `--color-warm-bg` | `#FFE4E6` | Rose tint | Product detail warm backgrounds, soft accent sections |

---

## 5. Full Tailwind CSS Color Scale

Z Shop extends Tailwind v4 with custom oklab-based color scales. Below are the complete extracted variables from the `:root` stylesheet.

### 5.1 Red

| Shade | Hex | oklab (approx.) |
|-------|-----|----------------|
| 50 | `#FEF2F2` | `lab(96.50 4.19 1.52)` |
| 100 | `#FFE2E2` | `lab(92.24 10.29 3.84)` |
| 300 | `#FFA3A3` | `lab(76.55 36.42 15.53)` |
| 400 | `#FF6568` | `lab(63.71 60.75 31.31)` |
| 600 | `#E40014` | `lab(48.45 77.43 61.55)` |
| 800 | `#9F0712` | `lab(33.72 55.90 41.03)` |

### 5.2 Orange

| Shade | Hex | oklab (approx.) |
|-------|-----|----------------|
| 50 | `#FFF7ED` | `lab(97.70 1.54 5.91)` |
| 200 | `#FFD7A8` | `lab(88.49 9.95 28.84)` |
| 300 | `#FFB96D` | `lab(80.81 21.73 50.45)` |
| 500 | `#FE6E00` | `lab(64.27 57.18 90.36)` |
| 600 | `#F05100` | `lab(57.10 64.26 89.89)` |
| 700 | `#C53C00` | `lab(46.46 57.73 70.85)` |
| 900 | `#7E2A0C` | `lab(30.30 36.04 37.67)` |
| 950 | `#441306` | `lab(14.17 23.45 19.45)` |

### 5.3 Amber

| Shade | Hex | oklab (approx.) |
|-------|-----|----------------|
| 50 | `#FFFBE8` | `lab(98.63 -0.64 8.42)` |
| 100 | `#FFF2C7` | `lab(95.92 -1.22 23.11)` |
| 200 | `#FEE685` | `lab(91.72 -0.51 49.91)` |
| 300 | `#FFD236` | `lab(86.42 6.13 78.40)` |
| 400 | `#FCBB00` | `lab(80.16 16.60 99.21)` |
| 500 | `#F99C00` | `lab(72.72 31.87 97.94)` |
| 600 | `#DD7400` | `lab(60.35 40.56 87.12)` |
| 700 | `#B75000` | `lab(47.27 42.91 69.30)` |
| 800 | `#953D00` | `lab(37.88 37.17 52.27)` |
| 900 | `#7B3306` | `lab(31.23 30.26 40.04)` |
| 950 | `#461901` | `lab(15.81 20.91 23.38)` |

### 5.4 Green

| Shade | Hex | oklab (approx.) |
|-------|-----|----------------|
| 100 | `#DCFCE7` | `lab(96.19 -13.85 6.52)` |
| 800 | `#016630` | `lab(37.46 -36.80 22.97)` |

### 5.5 Emerald

| Shade | Hex | oklab (approx.) |
|-------|-----|----------------|
| 50 | `#ECFDF5` | `lab(97.85 -6.95 1.85)` |
| 100 | `#D0FAE5` | `lab(94.90 -17.08 5.64)` |
| 200 | `#A4F4CF` | `lab(90.22 -31.04 9.47)` |
| 300 | `#5EE9B5` | `lab(83.92 -48.71 13.88)` |
| 400 | `#00D294` | `lab(75.08 -60.73 19.41)` |
| 500 | `#00BB7F` | `lab(66.98 -58.27 19.54)` |
| 600 | `#009767` | `lab(55.05 -49.92 15.93)` |
| 700 | `#007956` | `lab(44.49 -41.04 11.04)` |
| 800 | `#005F46` | `lab(35.37 -33.12 8.04)` |
| 900 | `#004E3B` | `lab(28.86 -26.92 5.46)` |
| 950 | `#002C22` | `lab(15.06 -17.95 2.38)` |

### 5.6 Teal

| Shade | Hex | oklab (approx.) |
|-------|-----|----------------|
| 50 | `#F0FDFA` | `lab(98.32 -4.75 -0.11)` |
| 500 | `#00BBA7` | `lab(67.39 -49.10 -2.64)` |
| 600 | `#009588` | `lab(55.02 -41.08 -3.90)` |
| 700 | `#00776E` | `lab(44.41 -33.14 -4.22)` |
| 950 | `#022F2E` | `lab(16.64 -15.32 -3.82)` |

### 5.7 Cyan

| Shade | Hex | oklab (approx.) |
|-------|-----|----------------|
| 600 | `#0092B5` | `lab(55.18 -26.75 -30.51)` |

### 5.8 Blue

| Shade | Hex | oklab (approx.) |
|-------|-----|----------------|
| 50 | `#EFF6FF` | `lab(96.49 -1.15 -5.11)` |
| 100 | `#DBEAFE` | `lab(92.03 -2.25 -11.65)` |
| 300 | `#90C5FF` | `lab(77.51 -6.46 -36.42)` |
| 400 | `#54A2FF` | `lab(65.04 -1.42 -56.98)` |
| 500 | `#3080FF` | `lab(54.17 13.34 -74.68)` |
| 600 | `#155DFC` | `lab(44.06 29.03 -86.04)` |
| 700 | `#1447E6` | `lab(36.91 35.10 -85.69)` |
| 800 | `#193CB8` | `lab(30.25 27.79 -70.27)` |

### 5.9 Violet

| Shade | Hex | oklab (approx.) |
|-------|-----|----------------|
| 50 | `#F5F3FF` | `lab(96.24 2.29 -5.52)` |
| 100 | `#EDE9FE` | `lab(93.08 4.35 -9.88)` |
| 200 | `#DDD6FF` | `lab(87.09 8.54 -19.42)` |
| 300 | `#C4B4FF` | `lab(76.74 18.39 -37.07)` |
| 400 | `#A685FF` | `lab(62.82 34.92 -60.05)` |
| 500 | `#8D54FF` | `lab(49.94 55.18 -81.90)` |
| 600 | (inferred deep violet) | — |

### 5.10 Yellow

| Shade | Hex | oklab (approx.) |
|-------|-----|----------------|
| 400 | `#FAC800` | `lab(83.27 8.65 106.90)` |
| 500 | `#EDB200` | `lab(76.39 14.53 98.46)` |

---

## 6. Gradient Library

Z Shop uses oklab-space gradients for perceptual smoothness. These are the production gradients extracted from the live site.

### 6.1 Hero Gradients

```
/* Amber Sunrise — Electronics, Today's Deals */
background: linear-gradient(to right, #FF9900, #FFB800, #FFC600);

/* Pink Fuchsia — Audio, Fashion */
background: linear-gradient(to right bottom, #FF2455, #F73799);

/* Emerald Tide — Home & Kitchen, Grocery */
background: linear-gradient(to right bottom, #00BB7E, #00BBA7);

/* Warm Fade — Page top fade-in */
background: linear-gradient(oklab(0.987 -0.002 0.022 / 0.4), #FFFFFF 50%, #FFFFFF 100%);
```

### 6.2 Card & Surface Gradients

```
/* Soft warm overlay on cards */
background: linear-gradient(to right bottom, #FFFFFF, rgba(255, 248, 240, 0.3));

/* Z Prime promotional banner */
background: linear-gradient(to right bottom, #FFF2C7, #FFFFFF);
```

### 6.3 Transparent / Overlay Patterns

```
/* Hover overlay on product cards */
background: rgba(0, 0, 0, 0.05);

/* Active/pressed overlay */
background: rgba(0, 0, 0, 0.1);

/* Soft section separator */
background: rgba(0, 0, 0, 0.2);

/* Muted fill (50% overlay) */
background: rgba(0, 0, 0, 0.5);
```

---

## 7. Typography & Color Pairing

### Font Stack

```
--font-geist-sans: "Geist", "Geist Fallback"
--font-geist-mono: "Geist Mono", "Geist Mono Fallback"
```

### Color-Role Mapping

| Element | Foreground | Background | Border |
|---------|-----------|------------|--------|
| **Header / Nav** | `#041009` (near-black) | `#FFFFFF` (transparent) | `#E5E5E5` |
| **Hero Headings** | `#FFFFFF` (white on gradient) | Gradient (amber/pink/emerald) | — |
| **Section Headings (h2)** | `#041009` | `#FFFFFF` | — |
| **Body Text (p)** | `rgba(4, 16, 9, 0.9)` | `#FFFFFF` | — |
| **Links (a)** | `#D3D4D8` (on dark) / `#3080FF` (on light) | — | — |
| **Buttons (Primary CTA)** | `#18181B` (dark text) | `#FF6800` (orange) / gradient | — |
| **Buttons (Secondary)** | `#041009` | `#FFFFFF` | `#E5E5E5` |
| **Product Cards** | `#041009` (title) / `#737373` (price) | `#FFFFFF` | `rgba(229, 229, 229, 0.6)` |
| **Sale Badge** | `#FFFFFF` | `#C90034` (red) | — |
| **Deal % Badge** | `#FFFFFF` | `#FF6800` (orange) | — |
| **Star Rating** | `#FCBB00` (filled) / `#E5E5E5` (empty) | — | — |
| **Footer** | `#D3D4D8` | `#18181B` | — |
| **Input Fields** | `#041009` | `#FFFFFF` | `#E5E5E5` |

---

## 8. Color Accessibility Notes

### Contrast Ratios (WCAG 2.1)

| Pair | Ratio | Grade |
|------|-------|-------|
| `#041009` on `#FFFFFF` | ~18.5:1 | AAA |
| `#18181B` on `#FFFFFF` | ~17.2:1 | AAA |
| `#D3D4D8` on `#18181B` | ~10.1:1 | AAA |
| `#737373` on `#FFFFFF` | ~4.6:1 | AA |
| `#3E3F46` on `#FFFFFF` | ~8.5:1 | AAA |
| `#FFFFFF` on `#FF6800` | ~3.2:1 | AA Large Only |
| `#FFFFFF` on `#C90034` | ~4.5:1 | AA |
| `#FFFFFF` on `#FF2455` | ~3.5:1 | AA Large Only |
| `#3080FF` on `#FFFFFF` | ~4.6:1 | AA |
| `#00D393` on `#FFFFFF` | ~2.8:1 | AA Large Only |

### Recommendations

- **Primary CTA buttons** (`#FF6800` bg, white text): Meets AA for large text only. Consider adding a subtle text shadow or switching to `#E77000` for better contrast on small buttons.
- **Star ratings** (`#FCBB00` on white): Decorative — acceptable, but pair with a text label for accessibility.
- **Emerald success badges** (`#00D393` on white): Use only for large text or icons. For small text badges, use `#009767` instead.
- **All body text** in `#041009` on white exceeds AAA — no issues.

---

## 9. Dark Mode Tokens (Implied)

While the current live site renders in light mode, the CSS includes a **theme toggle button** in the header, indicating dark mode support. Based on the token structure, the dark mode palette would invert as follows:

| Token | Light | Dark (Inferred) |
|-------|-------|-----------------|
| Background | `#FFFFFF` | `#18181B` |
| Surface | `#FFFFFF` | `#27272A` |
| Text Primary | `#041009` | `#F4F4F5` |
| Text Secondary | `#737373` | `#A1A1AA` |
| Border | `#E5E5E5` | `#3F3F46` |
| Card BG | `#FFFFFF` | `#18181B` |
| Overlay | `rgba(0,0,0,0.05)` | `rgba(255,255,255,0.05)` |

---

## 10. CSS Variable Reference

For developers implementing these colors, the CSS custom properties are available on `:root`:

```css
:root {
  /* Core Neutrals */
  --color-zinc-50:  #F4F4F5;
  --color-zinc-200: #E5E5E5;
  --color-zinc-300: #D3D4D8;
  --color-zinc-700: #3E3F46;
  --color-zinc-900: #18181B;

  /* Primary Brand (Amber/Orange) */
  --color-amber-200: #FEE685;
  --color-amber-300: #FFD236;
  --color-amber-400: #FCBB00;
  --color-amber-500: #F99C00;
  --color-amber-600: #DD7400;
  --color-orange-500: #FE6E00;
  --color-orange-600: #F05100;
  --color-orange-700: #C53C00;

  /* Semantic */
  --color-red-400: #FF6568;
  --color-red-600: #E40014;
  --color-emerald-400: #00D294;
  --color-emerald-600: #009767;
  --color-blue-500: #3080FF;
  --color-blue-600: #155DFC;
  --color-violet-400: #A685FF;
  --color-violet-500: #8D54FF;

  /* Typography */
  --font-geist-sans: "Geist", "Geist Fallback";
  --font-geist-mono: "Geist Mono", "Geist Mono Fallback";
}
```

---

## 11. Summary — Quick Reference Card

### Brand Identity Colors

```
┌──────────────────────────────────────────────────┐
│  Z SHOP BRAND COLORS                              │
│                                                    │
│  ● Primary BG     #FFFFFF   (White)               │
│  ● Primary Text   #041009   (Near Black)           │
│  ● CTA Orange     #FF6800   (Action Orange)        │
│  ● Brand Gold     #FFB800   (Amber Gold)           │
│  ● Sale Red       #C90034   (Discount Red)         │
│  ● Success Green  #00D393   (Emerald)              │
│  ● Info Blue      ##3080FF   (Link Blue)           │
│  ● Premium Violet #8D54FF   (Violet)               │
│  ● Footer Dark    #18181B   (Zinc 900)             │
│  ● Footer Light   #D3D4D8   (Zinc 300)             │
│  ● Border         #E5E5E5   (Zinc 200)             │
│  ● Muted Text     #737373   (Neutral 500)          │
└──────────────────────────────────────────────────┘

### Hero Gradients

```
  Amber Sunrise    #FF9900 → #FFB800 → #FFC600
  Pink Fuchsia     #FF2455 → #F73799
  Emerald Tide     #00BB7E → #00BBA7
```

---

*Extracted on 2026-08-30 from the live Z Shop deployment. All hex values converted from oklab/Lab CSS computed styles. Tailwind v4 custom color scales included for developer reference.*