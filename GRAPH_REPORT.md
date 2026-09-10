# Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 11 nodes · 13 edges · 3 communities (2 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b87ea8f1`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app.ps1
- Check-ForUpdates

## God Nodes (most connected - your core abstractions)
1. `Check-ForUpdates()` - 3 edges
2. `Trigger-BackgroundUpdateCheck()` - 3 edges
3. `Copy-PromptToClipboard()` - 2 edges
4. `Hide-MainWindow()` - 2 edges
5. `Exit-Application()` - 2 edges
6. `Show-MainWindow()` - 2 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (3 total, 1 thin omitted)

### Community 1 - "Check-ForUpdates"
Cohesion: 0.50
Nodes (4): Check-ForUpdates(), Exit-Application(), Show-MainWindow(), Trigger-BackgroundUpdateCheck()

## Knowledge Gaps
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Check-ForUpdates()` connect `Check-ForUpdates` to `app.ps1`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Why does `Trigger-BackgroundUpdateCheck()` connect `Check-ForUpdates` to `app.ps1`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._