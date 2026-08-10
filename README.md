# Skills and plugins

Personal collection of agent skills and Herdr plugins.

## Agent skills

Install all skills:

```bash
npx skills add Idan-Levin/skills
```

Install one skill:

```bash
npx skills add Idan-Levin/skills --skill pyramid-summary
npx skills add Idan-Levin/skills --skill herdr-implement-review
```

- **pyramid-summary** — create answer-first executive summaries using the Pyramid Principle.
- **herdr-implement-review** — explicitly launch and mother a Herdr implementation-review workflow.

## Herdr plugin

Install the implementation-review backend:

```bash
herdr integration install codex
herdr plugin install Idan-Levin/skills/plugins/herdr-implement-review --yes
npx --yes @openai/codex-security@0.1.8 login
```

The plugin requires Herdr 0.7+, Node.js 22.13+ (or 24/26), Python 3.10+, and Codex Security access. Install the Claude integration too when using a Claude mother pane.

Then invoke it from a Claude or Codex pane with a concrete task:

```bash
herdr plugin action invoke idan.implement-review.run
```

The mother plan must choose `REVIEW_LEVEL: LIGHT` or `REVIEW_LEVEL: DEEP`.
LIGHT uses the mother review only. DEEP additionally runs the pinned Codex Security scanner and may be slow or billable.
