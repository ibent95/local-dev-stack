# LDS Brand Assets

SVG logo variants for the Local Dev Stack (LDS) project.

## Logo Variants

| File | Variant | Use Case |
|------|---------|----------|
| `lds-flame-mark.svg` | Flame Mark | Hero/header graphics, splash screens |
| `lds-hex-badge.svg` | Hex Badge | Developer-focused contexts, social profiles |
| `lds-wordmark.svg` | Wordmark | Horizontal layouts, nav bars, documents |
| `lds-monogram.svg` | Monogram | Compact representations, favicons base |
| `lds-stacked.svg` | Stacked Lockup | Full branding, README headers, presentations |

## Color Variants

Each logo has three color modes:

| Suffix | Description | Background |
|--------|-------------|------------|
| *(none)* | Default (full color gradients) | Transparent / dark |
| `-dark` | Darker tones, reduced saturation | Light backgrounds |
| `-mono` | Single-color white | Dark backgrounds |
| `-light` | *(not generated — use default)* | — |

**Examples:**
- `lds-flame-mark.svg` — default red gradient (dark bg)
- `lds-flame-mark-dark.svg` — darker tones (light bg)
- `lds-flame-mark-mono.svg` — solid white (dark bg)

## Size-Optimized Icons

Square monogram icons sized for specific use cases:

| File | Size | Use Case |
|------|------|----------|
| `lds-icon-16.svg` | 16×16 | Tiny favicon |
| `lds-icon-32.svg` | 32×32 | Browser favicon |
| `lds-icon-64.svg` | 64×64 | Small UI icon |
| `lds-icon-128.svg` | 128×128 | Medium icon / notification |
| `lds-icon-256.svg` | 256×256 | App icon |
| `lds-icon-512.svg` | 512×512 | Splash / social media |

> **Note:** SVGs are vector and scale to any resolution. The size in the filename indicates the *intended* rendering size; the viewBox handles scaling.

## Brand Colors

| Hex | Name | Usage |
|-----|------|-------|
| `#EF4444` | Red 500 | Primary brand, gradients start |
| `#DC2626` | Red 600 | Mid gradient |
| `#B91C1C` | Red 700 | Gradient end, dark elements |
| `#991B1B` | Red 800 | Dark variant base |
| `#7F1D1D` | Red 900 | Deep dark variant |
| `#450A0A` | Red 950 | Darkest tone |
| `#FCA5A5` | Red 300 | Inner highlights |
| `#FEE2E2` | Red 100 | Text on dark fills |
| `#FEF2F2` | Red 50 | Brightest text |

## Typography

- **Primary:** `'Segoe UI', system-ui, sans-serif` — weight 800–900
- **Code accent:** `'Courier New', monospace` — weight 700
- **Letter spacing:** -1 (LDS), 3–4 (taglines)

## Usage

```html
<!-- Inline -->
<img src="assets/brand/lds-monogram.svg" alt="LDS" width="48" height="48" />

<!-- As background -->
<div style="background-image: url('assets/brand/lds-flame-mark-mono.svg')"></div>

<!-- Favicon -->
<link rel="icon" type="image/svg+xml" href="assets/brand/lds-icon-32.svg" />
```

## Source

Original designs exported from `red-logo.html` (root of repository).
