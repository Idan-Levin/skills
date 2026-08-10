# Herdr Implement Review

Runs a coding task in a Codex implementer pane while the current Claude or Codex pane plans and reviews the work.

## Install

```bash
herdr integration install codex
herdr plugin install Idan-Levin/skills/plugins/herdr-implement-review --yes
npx --yes @openai/codex-security@0.1.8 login
```

Install the Claude integration too when using a Claude mother pane.

## Run

Open the target project in a Herdr pane, describe the task, then run:

```bash
herdr plugin action invoke idan.implement-review.run
```

The mother chooses `LIGHT` for ordinary local changes or `DEEP` for sensitive security-related changes. DEEP runs Codex Security and may be slow or billable.
