---
name: pyramid-summary
description: Summarize text using Barbara Minto's Pyramid Principle — answer-first executive summary with 3-7 supporting ideas and evidence bullets. Use when asked to summarize with the pyramid principle, produce an executive brief, or restructure a document answer-first.
---

# Pyramid Summary

Reorganize the given text so the reader understands the main point immediately and can drill down into supporting ideas. The goal is restructuring, not arbitrary shortening.

## Input

The text to summarize is pasted in the request or given as a file path. Read it in full before summarizing.

## Rules

1. Start with the single most important takeaway (1-3 sentences). A reader who only reads this should understand the main message.
2. Identify the 3-7 highest-level supporting ideas that directly support the takeaway. Group related ideas together and remove repetition.
3. Under each supporting idea, give concise bullet points: key evidence, arguments, examples, findings.
4. Preserve all important information — don't invent facts, don't omit important arguments, merge duplicates.
5. Rewrite for clarity: simple, direct language. Every sentence adds new information.
6. Build a logical hierarchy (inverted tree) — every section summarizes what's beneath it, every bullet supports its parent heading.
7. Put recommendations or decisions near the top, not buried at the end.

## Output format

```
# Executive Summary
<1-3 sentence answer-first summary>

# Supporting Idea 1
Short explanation.
- Key point
- Key point

# Supporting Idea 2
...

# Missing or Unclear
<assumptions, ambiguities, contradictions, or open questions that remain>
```

Should read as an executive brief, understandable in under five minutes, while preserving the source's core reasoning.
