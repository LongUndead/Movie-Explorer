---
name: Cinema Premium
colors:
  surface: '#081423'
  surface-dim: '#081423'
  surface-bright: '#2f3a4b'
  surface-container-lowest: '#040f1e'
  surface-container-low: '#111c2c'
  surface-container: '#152030'
  surface-container-high: '#1f2b3b'
  surface-container-highest: '#2a3546'
  on-surface: '#d7e3f9'
  on-surface-variant: '#e9bcb6'
  inverse-surface: '#d7e3f9'
  inverse-on-surface: '#263141'
  outline: '#af8782'
  outline-variant: '#5e3f3b'
  surface-tint: '#ffb4aa'
  primary: '#ffb4aa'
  on-primary: '#690003'
  primary-container: '#e50914'
  on-primary-container: '#fff7f6'
  inverse-primary: '#c0000c'
  secondary: '#e9c349'
  on-secondary: '#3c2f00'
  secondary-container: '#af8d11'
  on-secondary-container: '#342800'
  tertiary: '#b9c7e4'
  on-tertiary: '#233148'
  tertiary-container: '#65738d'
  on-tertiary-container: '#f9f9ff'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad5'
  primary-fixed-dim: '#ffb4aa'
  on-primary-fixed: '#410001'
  on-primary-fixed-variant: '#930007'
  secondary-fixed: '#ffe088'
  secondary-fixed-dim: '#e9c349'
  on-secondary-fixed: '#241a00'
  on-secondary-fixed-variant: '#574500'
  tertiary-fixed: '#d6e3ff'
  tertiary-fixed-dim: '#b9c7e4'
  on-tertiary-fixed: '#0d1c32'
  on-tertiary-fixed-variant: '#39475f'
  background: '#081423'
  on-background: '#d7e3f9'
  surface-variant: '#2a3546'
typography:
  display-lg:
    fontFamily: Chivo
    fontSize: 72px
    fontWeight: '900'
    lineHeight: 80px
    letterSpacing: -0.04em
  headline-lg:
    fontFamily: Chivo
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Chivo
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Chivo
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  title-lg:
    fontFamily: Chivo
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Chivo
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Chivo
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Chivo
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.1em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 48px
  xl: 80px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 64px
---

## Brand & Style
The design system is engineered for a high-end, immersive cinematic experience. The brand personality is prestigious, mysterious, and atmospheric, mimicking the anticipation of a darkened theater before a premiere. The target audience consists of cinephiles and luxury consumers who value curation and visual depth.

The design style is a hybrid of **Glassmorphism** and **High-Contrast/Bold** aesthetics. It utilizes deep layering, background blurs, and luminous accents to create a sense of three-dimensional space. Elements should feel like they are projected onto a dark stage, using subtle glows and "light leaks" to guide the user's eye.

## Colors
The palette is rooted in "Obsidian" (#020C1B) for the deepest background layers and "Deep Navy" (#0A192F) for secondary surfaces. These cool, dark tones provide the perfect canvas for high-energy accents.

**Cinema Red** (#E50914) is used for primary actions, critical alerts, and live indicators, evoking the classic velvet of theater curtains. **Gold** (#D4AF37) is used sparingly for premium tiers, ratings, and awards, adding a layer of prestige. Text and icons utilize high-clarity whites and off-greys to ensure legibility against the dark void.

## Typography
Chivo is the exclusive typeface for this design system, chosen for its sharp, modern, and authoritative character. It performs exceptionally well in high-contrast environments.

Headlines should be bold and impactful, often using tight letter-spacing to create a "blockbuster" feel. Labels and small metadata utilize the Bold weight with increased letter-spacing and uppercase styling to mimic technical film credits or marquee text.

## Layout & Spacing
The layout follows a fluid 12-column grid for desktop and a 4-column grid for mobile. Wide margins (64px on desktop) are encouraged to create a "letterboxed" cinematic feel, focusing the user's attention on the central content.

Spacing rhythm is based on an 8px scale. Horizontal spacing between cards should use the 24px gutter to maintain breathing room, while vertical sections should use 80px (xl) to clearly demarcate different content categories or genres.

## Elevation & Depth
Depth is created through a combination of **Glassmorphism** and **Subtle Glows**. Surfaces do not use traditional drop shadows; instead, they use:
1. **Backdrop Blurs:** Floating panels (like navigation or detail modals) use a 20px blur with a 10% opacity white border.
2. **Inner Glows:** Active cards and buttons feature a subtle 1px inner stroke of Cinema Red or Gold to simulate light catching an edge.
3. **Outer Bloom:** High-priority elements (like a "Watch Now" button) use a soft color-matched outer glow (bloom) instead of a black shadow, creating a luminous effect that feels "projected."

## Shapes
The design system uses "Soft" geometry. A 4px (0.25rem) base radius ensures that elements feel modern and intentional without becoming too playful or organic. This maintains the professional, architectural feel of a luxury cinema.

- **Standard Elements:** 4px radius.
- **Large Containers/Posters:** 8px (rounded-lg) radius.
- **Interactive Tags:** 12px (rounded-xl) radius for a slight pill-effect on smaller components.

## Components
- **Buttons:** Primary buttons are solid Cinema Red with a soft red bloom on hover. Secondary buttons use a glassmorphic style (transparent fill, white border, backdrop blur).
- **Cards:** Movie posters and content cards use a "vignette" overlay at the bottom to ensure title legibility. On hover, cards should scale slightly (1.05x) and gain a Gold inner border.
- **Chips/Tags:** Used for genres or technical specs (e.g., 4K, HDR). These should be semi-transparent with a 1px border and Chivo Bold uppercase text.
- **Input Fields:** Dark Obsidian backgrounds with a 1px Navy border. The border glows Cinema Red when the field is focused.
- **Progress Bars:** Seek bars and loading indicators should use a Cinema Red fill with a small "glow head" at the leading edge of the progress.
- **Navigation:** Top-fixed bar with a heavy backdrop blur (30px) and no solid background color, allowing content to bleed through as the user scrolls.