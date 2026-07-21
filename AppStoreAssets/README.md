# BudgetTrackr App Store screenshots

Two complete sets of seven localized portrait screenshots are ready, ordered by
their recommended App Store sequence:

- Portuguese: `final/`
- English: `final-en/`

Every image is `1320 × 2868`, RGB PNG (no alpha), matching Apple's accepted
6.9-inch iPhone size.

The real app captures live in `raw/` and `raw-en/`. The three generated campaign
backgrounds live in `backgrounds/`. Run `python3 compose.py` for Portuguese or
`python3 compose.py --locale en` for English. These commands also rebuild
`contact-sheet.png` and `contact-sheet-en.png` respectively.

The app can be launched with `-ScreenshotMode` to use a disposable in-memory
store with deterministic demo data. Add `-ScreenshotEnglish` for English and
`-ShowOnboarding` for onboarding pages. None of these modes writes to normal app
data or CloudKit.

## Generated-background prompt set

The backgrounds were generated with the built-in image-generation tool. Text,
the app UI, device screen, icon, and all marketing copy were added locally from
real project assets; no generated text or generated UI appears in the finals.

### Emerald

> Use case: ads-marketing. Asset type: App Store screenshot campaign background,
> portrait. Create a premium abstract background for a Brazilian personal finance
> app campaign, designed to sit behind a real iPhone UI screenshot and marketing
> headline. Deep midnight navy to near-black gradient with a large soft
> emerald-green luminous arc rising from the lower right, subtle glass-like
> translucent waves, restrained depth. Polished modern 3D gradient art,
> sophisticated fintech, premium Apple-like restraint. Vertical 9:19.5 portrait;
> keep the upper 30% calm and readable for white headline text; visual energy
> around outer edges and lower half; no central object. Confident, calm,
> optimistic, high contrast. Palette: #050816, #0B1538, #22C55E, faint cyan.
> Absolutely no text, letters, numbers, logos, icons, phone, device frame, UI,
> currency symbols, watermark, busy detail, or human subjects.

### Cobalt

> Use case: ads-marketing. Asset type: App Store screenshot campaign background,
> portrait, second artwork in a cohesive fintech series. Deep midnight navy
> gradient, elegant translucent cobalt and electric-cyan glass ribbons flowing
> upward from the bottom left, subtle radial glow, sparse soft particles.
> Polished modern 3D gradient art, sophisticated fintech, premium Apple-like
> restraint; visually compatible with an emerald companion background. Vertical
> 9:19.5 portrait; upper 30% calm and dark for white headline text; central region
> quiet for a device screenshot; edge-focused movement. Analytical, clear,
> trustworthy, quietly energetic. Palette: #050816, #0A1738, #2563EB, #06B6D4.
> Absolutely no text, letters, numbers, logos, icons, phone, device frame, UI,
> currency symbols, watermark, busy detail, or human subjects.

### Violet and amber

> Use case: ads-marketing. Asset type: App Store screenshot campaign background,
> portrait, third artwork in a cohesive fintech series. Deep midnight navy to
> black gradient with smooth translucent violet glass curves and a restrained
> warm amber-orange glow along the lower right edge; subtle depth, no recognizable
> objects. Polished modern 3D gradient art, sophisticated fintech, premium
> Apple-like restraint; visually compatible with emerald and cobalt companions.
> Vertical 9:19.5 portrait; upper 30% calm and dark for white headline text;
> central area quiet for a UI screenshot; visual motion confined to lower edges.
> Warm, organized, empowering, trustworthy. Palette: #050816, #12102F, #7C3AED,
> #F59E0B, small coral accents. Absolutely no text, letters, numbers, logos,
> icons, phone, device frame, UI, currency symbols, watermark, busy detail, or
> human subjects.
