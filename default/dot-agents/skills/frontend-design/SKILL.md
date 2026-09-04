---
name: frontend-design
description: >-
  Frontend and landing-page design constraints for distinctive, non-generic UI.
  Use when building or restyling web UI, landing pages, marketing surfaces, or
  React/CSS layouts — unless an existing design system must be preserved.
---

# Frontend design

Avoid generic, overbuilt layouts. If working within an existing site or design system, preserve its patterns instead.

## Composition

- First viewport = one composition, not a dashboard (unless it is a dashboard).
- Brand first: brand/product name is hero-level, not just nav/eyebrow. No headline overpowers the brand.
- Brand test: if the first viewport could belong to another brand after removing nav, branding is too weak.
- One job per section: one purpose, one headline, usually one short supporting sentence.
- Reduce clutter: no pill clusters, stat strips, icon rows, boxed promos, schedule snippets, or competing text blocks.

## Hero

- Full-bleed hero on landing/promotional surfaces: dominant edge-to-edge visual. No inset heroes, side panels, rounded media cards, tiled collages, or floating image blocks unless the design system requires it.
- Hero budget: brand, one headline, one short sentence, one CTA group, one dominant image. No stats, schedules, listings, addresses, promos, or metadata in the first viewport.
- No hero overlays: no detached labels, floating badges, promo stickers, chips, or callout boxes on hero media.
- Real visual anchor: product, place, atmosphere, or context — not only decorative gradients.

## Cards and chrome

- Default: no cards. Never in the hero. Cards only when they contain a user interaction. If border/shadow/background/radius can go without hurting understanding, remove them.

## Typography and color

- Expressive purposeful fonts; avoid Inter/Roboto/Arial/system defaults.
- Backgrounds: not flat single-color — gradients, images, or subtle patterns.
- Clear visual direction; CSS variables.
- Avoid AI-default looks: purple-on-white / purple-indigo gradients; warm cream (#F4F1EA) + terracotta serif; broadsheet hairline/zero-radius dense columns.
- Avoid defaulting to: dark mode, purple, glow, rounded-full pills, multi-layer shadows, emojis.

## Motion and responsive

- At least 2–3 intentional motions for visually led work; presence and hierarchy, not noise.
- Must work on desktop and mobile.

## React

Prefer modern patterns (`useEffectEvent`, `startTransition`, `useDeferredValue`) when appropriate for the team. Do not add `useMemo`/`useCallback` by default; follow repo React Compiler guidance.
