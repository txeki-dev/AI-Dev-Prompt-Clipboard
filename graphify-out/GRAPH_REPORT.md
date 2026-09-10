# Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 37 nodes · 41 edges · 7 communities (5 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `de6338f3`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10)
- diary.md
- app.ps1
- Check-ForUpdates
- Update-ActiveClipboardIndicator
- Communities (3 total, 1 thin omitted)

## God Nodes (most connected - your core abstractions)
1. `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10)` - 11 edges
2. `Update-ActiveClipboardIndicator()` - 5 edges
3. `🔬 Forensic Audit Findings - 2026-09-09 (Principal Security & Performance Auditor)` - 4 edges
4. `Copy-PromptToClipboard()` - 3 edges
5. `Check-ForUpdates()` - 3 edges
6. `Show-MainWindow()` - 3 edges
7. `Trigger-BackgroundUpdateCheck()` - 3 edges
8. `Hide-MainWindow()` - 2 edges
9. `Exit-Application()` - 2 edges
10. `Get-SafeClipboardText()` - 2 edges

## Surprising Connections (you probably didn't know these)
- `Copy-PromptToClipboard()` --calls--> `Update-ActiveClipboardIndicator()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 2 → community 4_
- `Show-MainWindow()` --calls--> `Update-ActiveClipboardIndicator()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 3 → community 4_

## Import Cycles
- None detected.

## Communities (7 total, 2 thin omitted)

### Community 0 - "Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10)"
Cohesion: 0.18
Nodes (10): Community Hubs (Navigation), Corpus Check, God Nodes (most connected - your core abstractions), Graph Freshness, Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10), Import Cycles, Knowledge Gaps, Suggested Questions (+2 more)

### Community 1 - "diary.md"
Cohesion: 0.20
Nodes (9): 📋 Active / Pending Tasks, 📊 Current State, ✅ Done (2026-09-10 — System Tray, Windows Startup, App Identity, Auto-Updater & Finding #2), 🔬 Forensic Audit Findings - 2026-09-09 (Principal Security & Performance Auditor), 🔴 HIGH — Bugs / Robustness, 🟢 LOW — UX / Optimization, 🟡 MEDIUM — Robustness / Edge cases, 🎯 Next Immediate Step (+1 more)

### Community 3 - "Check-ForUpdates"
Cohesion: 0.50
Nodes (4): Check-ForUpdates(), Exit-Application(), Show-MainWindow(), Trigger-BackgroundUpdateCheck()

### Community 4 - "Update-ActiveClipboardIndicator"
Cohesion: 0.67
Nodes (3): Get-SafeClipboardText(), Set-CardActiveState(), Update-ActiveClipboardIndicator()

## Knowledge Gaps
- **18 isolated node(s):** `Community Hubs (Navigation)`, `Corpus Check`, `God Nodes (most connected - your core abstractions)`, `Graph Freshness`, `Import Cycles` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10)` connect `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10)` to `Communities (3 total, 1 thin omitted)`?**
  _High betweenness centrality (0.103) - this node is a cross-community bridge._
- **Why does `Communities (3 total, 1 thin omitted)` connect `Communities (3 total, 1 thin omitted)` to `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10)`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **What connects `Community Hubs (Navigation)`, `Corpus Check`, `God Nodes (most connected - your core abstractions)` to the rest of the system?**
  _18 weakly-connected nodes found - possible documentation gaps or missing edges._