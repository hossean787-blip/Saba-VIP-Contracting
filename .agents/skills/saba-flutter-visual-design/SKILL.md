---
name: saba-flutter-visual-design
description: Plan and implement premium, accessible Persian RTL Flutter screens, finance forms, dashboards, and reports in the existing Saba VIP Contracting navy-and-champagne visual identity.
---

# Flutter visual design — Saba VIP Contracting

Use this when building or editing Flutter screens, forms, charts, navigation, responsive UI and visual quality.

Inspired by the design principles in Anthropic frontend-design:
https://github.com/anthropics/skills/tree/main/skills/frontend-design
This is a new Flutter-oriented skill; no web CSS, HTML or upstream source is copied.

## Visual baseline
Inspect lib/core/theme.dart and lib/widgets/ before proposing visuals. The established colors are midnight #101A24, panel #192633, champagne #D5B77D, ivory #F5F1E9 and mint #63D2B0. Preserve this theme unless explicitly instructed otherwise.

## Design-to-code routine
1. Identify the user's primary task: select contract, recognize expense, settle payment, record receipt, view certified work or inspect financial report.
2. Sketch the information hierarchy and state matrix first: empty, loaded, loading, invalid, success, failed, offline. Use a restrained token system, precise spacing, hierarchy and legible typography. No generic decorative SaaS dashboard.
3. Implement ACTUAL Flutter Material widgets, not a CSS/web mock-up. Prefer existing widgets; add shared components only for genuine reuse.
4. Use right-to-left layout and correct text alignment. Jalali dates, grouped digits and explicit rial/toman labels must stay readable on narrow devices, long Persian text and increased system font size.
5. In the expense UI, differentiate «ثبت هزینه» from optional «ثبت پرداخت». No payment selection means unpaid and no amount field; full means total amount; partial reveals the entered amount and outstanding balance, with immediate validation. Handle subsequent payments clearly.
6. Animation should explain a state change, not waste rendering budget. Maintain accessible targets, contrast, semantics, keyboard behavior and dark-mode legibility.
7. Capture actual Flutter renders or test screenshots when tools exist. Do not confuse a prototype with a tested production UI.

## Acceptance checklist
Verify RTL in every state, narrow screen without overflow, keyboard and scroll, text scaling, empty/error/loading states, duplicate-submit prevention, and unpaid/full/partial expenses. Record the screenshot or widget test evidence actually produced.
