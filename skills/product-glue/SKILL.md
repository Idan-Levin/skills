---
name: product-glue
description: Make a new or materially changed UI feature feel native to the product it lives in. Use automatically before, during, and after any implementation that adds or reshapes a screen, page, view, panel, modal, form, or navigation entry — study the surrounding routes, components, design tokens, terminology, information architecture, data models, and related features first, build with the existing patterns, then run a Product Glue review pass and fix the incoherences found. Also use when asked to check whether a feature feels bolted on, or on $product-glue.
---

# Product Glue

No feature should be an island. A feature is complete only when it fits into the product around it.

A coding agent can build a UI feature that is correct in isolation and still wrong in context: new terminology, a new component instead of the existing one, a parallel data concept, no route into it from anywhere users already are. This skill closes that gap. It runs in three phases — orient, implement, glue pass — and the third phase is not optional.

## When this applies

Applies to any work that adds or materially changes user-facing UI: a new page or route, a new panel or modal, a new form, a new list or detail view, a new navigation entry, or a substantial rework of an existing one.

Does not apply to pure backend work with no UI surface, one-line copy fixes, dependency bumps, or test-only changes.

## Phase 1 — Orient before implementing

Inspect the codebase before writing feature code. Read real files; do not infer conventions from the framework's defaults or from this skill's assumptions. Gather:

1. **Routes and navigation** — the router definition, nav/sidebar/menu components, breadcrumbs, and how existing pages register themselves.
2. **UI components** — the shared component library or `components/` directory. Note what already exists: buttons, tables, empty states, modals, form fields, page shells, loading and error states.
3. **Design tokens and design system** — theme files, Tailwind config, CSS variables, spacing and type scales, color usage. Note whether raw values are ever used or always tokens.
4. **Terminology and product language** — what the product calls its objects and actions, in UI strings and i18n files. Note singular/plural, capitalization, and verbs used on buttons.
5. **Information architecture** — how pages nest, what belongs under what, where a feature of this kind would sit.
6. **Data models and entities** — schema, types, API layer. Identify the entities this feature touches and how they already relate.
7. **Related features** — the closest existing analogue. It is the strongest available precedent for structure, layout, and naming.
8. **Existing links and relationships** — how pages already cross-reference each other: detail links, related-items sections, deep links, tabs.
9. **Interaction patterns** — how the product handles submission, validation, optimistic updates, confirmation, destructive actions, toasts, pagination, filtering, keyboard behavior.
10. **Product documentation** — README, docs site, design guidelines, `CLAUDE.md`/`AGENTS.md`, ADRs, Storybook, when present.

Then state, briefly, where the feature sits: which route, which nav section, which entities it belongs to, and which existing feature it most resembles. This placement decision drives everything after it.

## Phase 2 — Implement with the grain

- Prefer an existing component over a new one. Extend an existing component before forking it; create a new shared component only when nothing close exists, and put it where the others live.
- Use the product's existing terminology in every user-visible string, route segment, type name, and identifier. If the product says "workspace", never introduce "project".
- Follow the existing visual hierarchy, spacing scale, and design tokens. No hardcoded colors, spacing, or type sizes when tokens exist.
- Connect the feature: add it to navigation where comparable features appear, link out to the entities it references, and add inbound links from the pages a user would arrive from.
- Do not duplicate functionality that exists. If something close exists, extend it or reuse it.
- Preserve established interaction patterns — the same confirmation style, the same form validation, the same loading and empty states as the rest of the product.
- Match the conventions of the file structure, naming, and layer boundaries already in use.

## Phase 3 — The Product Glue pass

After the feature works, review it against these eight dimensions. Check each one explicitly against the actual code, not from memory of what was intended.

1. **Language** — Same terminology, naming conventions, capitalization, and button verbs as the rest of the product?
2. **Design** — Existing design system, components, tokens, spacing, hierarchy, and interaction patterns?
3. **Navigation** — Reachable from the right places, registered in nav, breadcrumbs and page titles consistent with siblings?
4. **Product relationships** — Relevant entities, features, and objects linked or referenced where a user would expect?
5. **Data model** — Built on existing concepts and structures rather than a parallel model that means the same thing?
6. **Duplication** — Did this recreate something that already exists?
7. **Discoverability** — Can users move naturally between this feature and the parts of the product it relates to, in both directions?
8. **Context** — Does the feature make sense as part of the whole product, not only on its own?

### Fix, don't just report

When the correct answer can be reasonably inferred from the existing product, fix it in the same pass — rename to the product's term, swap in the shared component, add the missing nav entry, add the cross-link, replace the raw value with the token. Report what was fixed.

Report rather than fix only when the decision is material and no clear precedent exists. Then present the options with the evidence found, and ask.

### Scope discipline

Keep changes scoped to making the new feature coherent. Inconsistencies discovered elsewhere in the product are not in scope: note them, do not fix them. This skill is not a licence to refactor, restyle, or redesign unrelated code, and a large diff outside the feature's own surface means the pass has gone wrong.

## Resolving uncertainty

Prefer the strongest existing precedent. When implementations disagree, weight by recency, by proximity to the feature's area, and by how many places follow the pattern. When there is no precedent and the decision is material, ask — do not invent a new convention and do not silently pick one.

## Output

Close with a short summary:

- **Placement** — where the feature sits and the precedent it follows.
- **Glue fixes applied** — the coherence changes made, one line each.
- **Open questions** — decisions with no clear precedent, with the options and evidence.
- **Noted, out of scope** — pre-existing inconsistencies observed and deliberately left alone.
