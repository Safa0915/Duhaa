---
name: feedback_design_previews
description: "User wants color/style previews, not full mockups, when comparing aesthetic directions"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d5d52f45-e26e-4383-865b-8a2510acbb62
---

When asked to show design options or aesthetics, show color palettes, typography samples, and brief visual swatches — NOT full interactive mockups.

**Why:** User explicitly said "I was just saying show me the colors and stuff" when full HTML mockups were built. Over-engineering the preview wastes time.

**How to apply:** For aesthetic comparison questions, output a simple color palette block (hex codes + names) and a 1-2 line description of the feel. Only build full mockups when explicitly asked to prototype or build.
