---
name: herdr-implement-review
description: Run the Herdr Implement + Security Review plugin only when the user explicitly asks to start, invoke, or run the Herdr implementation-review workflow, or invokes $herdr-implement-review. Do not use for ordinary coding, review, terminal, or Herdr requests.
---

# Herdr Implement Review

Use the installed `idan.implement-review` plugin as the backend. The invoking Claude or Codex pane remains the mother planner and final reviewer; a Codex pane implements the task, and DEEP reviews add a scan-only Codex Security pane.

## Preconditions

Before invoking, verify:

1. The user explicitly requested this workflow and supplied a concrete task.
2. `HERDR_PANE_ID` and `HERDR_WORKSPACE_ID` are set.
3. `herdr pane get "$HERDR_PANE_ID"` identifies a Claude or Codex pane whose `foreground_cwd` is the intended repository.
4. `herdr plugin list --plugin idan.implement-review --json` shows the plugin is enabled. If absent, ask the user to install it; do not install implicitly.

If a precondition is missing, state what is missing and do not invoke the plugin.

## Run

Invoke:

```bash
herdr plugin action invoke idan.implement-review.run
```

Remain the mother process for the whole run. Write the requested plan and review artifacts, choose a proportionate LIGHT or DEEP review, inspect the actual diff and evidence, and approve or request revisions. Do not implement application code from the mother pane.

Report the final decision and run directory. Scanner completion is evidence, not approval.
