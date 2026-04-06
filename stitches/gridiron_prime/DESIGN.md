# Design System Document: The Broadcast Prime Directive

## 1. Overview & Creative North Star
**Creative North Star: "The Stadium Command Center"**

This design system is not a static interface; it is a live broadcast. It rejects the "flat web" aesthetic in favor of a high-octane, theatrical environment that mimics the intensity of an NFL Draft war room. We break the traditional grid through the use of **asymmetric overlays, kinetic typography, and forced perspective.**

The goal is "Aggressive Sophistication." By layering industrial typography over deep, obsidian textures and piercing them with neon accents, we create a sense of urgency and prestige. We move beyond the "template" look by treating the screen as a multi-layered glass stage where information doesn't just sit—it performs.

---

## 2. Colors & Surface Logic

### The "No-Line" Rule
Standard 1px borders are strictly prohibited. They feel like wireframes; we want to build with light and mass. Boundaries must be defined through **Background Color Shifts** or **Tonal Transitions**. 
- Use `surface-container-low` against a `background` base to define regions. 
- Use `surface-bright` as a subtle highlight edge on the "top" of a container to simulate a metallic rim, rather than a full stroke.

### Surface Hierarchy & Nesting (The "War Room" Stack)
Treat the UI as a physical set. Use the surface-container tiers to create depth:
1.  **Foundation:** `surface-container-lowest` (#0a0e14) for the deep background.
2.  **The Stage:** `surface-container` (#1c2026) for main content areas.
3.  **The Monolith:** `surface-container-highest` (#31353c) for high-priority interactive cards.

### The "Glass & Gradient" Rule
To achieve the "Broadcast Chyron" look, use Glassmorphism for floating panels:
- **Base:** `surface` at 60% opacity.
- **Effect:** `backdrop-filter: blur(12px)`.
- **Accent:** A 1px "Ghost Border" using `outline-variant` at 15% opacity to catch the "light."

### Signature Textures
Main CTAs and Hero moments should utilize **Metallic Gradients**:
- **Primary Action:** Linear gradient (135deg) from `primary` (#adc6ff) to `on_primary_container` (#3686ff).
- **Critical Alert/Auction End:** Linear gradient from `secondary` (#ffb3b2) to `secondary_container` (#bf012c).

---

## 3. Typography
Our typography is industrial, loud, and authoritative. It is designed to be "read from the back of the stadium."

*   **The Power Scale (Space Grotesk):** Used for all `display`, `headline`, and `label` roles. This is our "Industrial" voice. 
    *   *Display-LG/MD:* Must always be Uppercase with -2% letter spacing to feel like a broadcast headline.
    *   *Labels:* Use for data points (e.g., "BID AMOUNT"). These should be bold and high-contrast using `tertiary` (#e9c400).
*   **The Utility Scale (Inter):** Used for `body` and `title` roles. Inter provides the "Premium" balance to the aggression of Space Grotesk.
    *   *Body-MD:* Use `on_surface_variant` (#c4c6cf) for secondary information to maintain hierarchy and prevent visual clutter.

---

## 4. Elevation & Depth

### The Layering Principle
Depth is achieved through **Tonal Stacking**. 
- To make a player card pop, do not add a shadow immediately. Instead, place the `surface-container-high` card on a `surface-container-lowest` background. The delta in luminance creates the lift.

### Ambient Shadows (The Stadium Glow)
When an element must float (e.g., a modal or a floating auction bar):
- **Shadow:** Use `on_primary_fixed_variant` (#004493) at 10% opacity for the shadow color instead of black.
- **Blur:** Large and diffused (e.g., `box-shadow: 0 20px 40px rgba(0, 68, 147, 0.15)`).

### The "Ghost Border" Fallback
If a separation is required for accessibility, use the `outline-variant` token at **15% opacity**. It should feel like a faint reflection on a glass edge, not a container wall.

---

## 5. Components

### Buttons (The "Action Triggers")
- **Primary:** High-gloss gradient using `primary` to `on_primary_container`. Text is `on_primary_fixed` (#001a41) and bold.
- **Secondary:** Transparent background with a `primary` ghost border (20% opacity) and `primary` text.
- **The "Auction Hammer":** For the most critical actions, use a `tertiary` (#e9c400) fill with a subtle outer glow (0 0 15px `tertiary`).

### Broadcast Chyrons (Custom Component)
Used for live updates and scrolling tickers.
- **Style:** `surface-container-highest` background, skewed edges (-10 degrees), and a 2px `secondary` (#ffb3b2) "live" indicator.
- **Typography:** `label-md` in Space Grotesk, Uppercase.

### Input Fields
- **State:** No fill. Bottom border only (2px) using `outline-variant`. 
- **Focus State:** Bottom border shifts to `primary` with a 4px "underglow" shadow of the same color.

### Cards & Lists
- **Rule:** Forbid divider lines. 
- **Separation:** Use 16px of vertical white space or a subtle shift from `surface-container-low` to `surface-container-lowest`. 
- **The "Spotlight" Effect:** On hover/active state, apply a radial gradient overlay (10% opacity) starting from the top-left corner using `surface-tint`.

---

## 6. Do's and Don'ts

### Do:
- **Do** use intentional asymmetry. A player photo can break the top boundary of a card to create "Theatrical Depth."
- **Do** use `tertiary` (Gold) sparingly. It is a "Championship" color, reserved for winners, high bids, and top-tier players.
- **Do** embrace the dark. Ensure `on_surface` text provides at least 7:1 contrast against `surface` containers.

### Don't:
- **Don't** use standard 1px solid borders. It ruins the broadcast "glass" illusion.
- **Don't** use rounded corners larger than `lg` (0.5rem). This system is industrial and sharp; "bubbly" corners negate the intensity.
- **Don't** use pure white (#FFFFFF) for body text. Use `on_surface` (#dfe2eb) to reduce eye strain against the stark black backgrounds.