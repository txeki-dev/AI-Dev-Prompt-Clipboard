# Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)

## Corpus Check
- 10 files · ~11,689 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 68 nodes · 78 edges · 10 communities
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `fe49e097`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)
- AI Dev Prompt Clipboard: Developer Diary
- app.ps1
- AI Dev Prompt Clipboard 📋
- Communities (8 total, 0 thin omitted)
- Check-ForUpdates
- Backlog - AI Dev Prompt Clipboard
- AI Dev Prompt Clipboard: Diary Archive
- Check-ForUpdatesAsync

## God Nodes (most connected - your core abstractions)
1. `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)` - 11 edges
2. `Check-ForUpdates()` - 9 edges
3. `Communities (8 total, 0 thin omitted)` - 8 edges
4. `AI Dev Prompt Clipboard 📋` - 8 edges
5. `AI Dev Prompt Clipboard: Developer Diary` - 6 edges
6. `Update-ActiveClipboardIndicator()` - 5 edges
7. `AI Dev Prompt Clipboard: Diary Archive` - 5 edges
8. `Trigger-BackgroundUpdateCheck()` - 3 edges
9. `Show-MainWindow()` - 3 edges
10. `Test-IsGitRepo()` - 3 edges

## Surprising Connections (you probably didn't know these)
- `Show-MainWindow()` --calls--> `Update-ActiveClipboardIndicator()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 9 → community 2_
- `Check-ForUpdatesAsync()` --calls--> `Check-ForUpdates()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 9 → community 5_

## Import Cycles
- None detected.

## Communities (10 total, 0 thin omitted)

### Community 0 - "Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)"
Cohesion: 0.18
Nodes (10): Community Hubs (Navigation), Corpus Check, God Nodes (most connected - your core abstractions), Graph Freshness, Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13), Import Cycles, Knowledge Gaps, Suggested Questions (+2 more)

### Community 1 - "AI Dev Prompt Clipboard: Developer Diary"
Cohesion: 0.29
Nodes (6): 📋 Active / Pending Tasks, AI Dev Prompt Clipboard: Developer Diary, 📊 Current State, ✅ Done (2026-09-13 — Prompt Catalog Restructuring, RDi Protocol & Dual-Mode Auto-Updater), 🎯 Next Immediate Step, 📅 Weekly Summary (Week ending 2026-09-13)

### Community 2 - "app.ps1"
Cohesion: 0.33
Nodes (5): Copy-PromptToClipboard(), Get-SafeClipboardText(), Hide-MainWindow(), Set-CardActiveState(), Update-ActiveClipboardIndicator()

### Community 3 - "AI Dev Prompt Clipboard 📋"
Cohesion: 0.18
Nodes (10): 🚀 Acceso Rápido y Métodos de Inicio, AI Dev Prompt Clipboard 📋, 🔄 Auto-Actualizaciones Dual-Mode desde GitHub (Git + Fallback HTTP), 🎨 Características de la Interfaz, 🛠️ Estructura del Proyecto, 💻 Instalación y Configuración de Atajo, 📄 Licencia, Opción 1: Doble clic (Recomendado) (+2 more)

### Community 4 - "Communities (8 total, 0 thin omitted)"
Cohesion: 0.25
Nodes (8): Communities (8 total, 0 thin omitted), Community 0 - "Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)", Community 1 - "AI Dev Prompt Clipboard: Developer Diary", Community 2 - "app.ps1", Community 3 - "AI Dev Prompt Clipboard 📋", Community 4 - "Communities (9 total, 1 thin omitted)", Community 6 - "Backlog - AI Dev Prompt Clipboard", Community 8 - "AI Dev Prompt Clipboard: Diary Archive"

### Community 5 - "Check-ForUpdates"
Cohesion: 0.32
Nodes (8): Check-ForUpdates(), Exit-Application(), Get-GitBehindCount(), Get-LocalVersionInfo(), Get-RemoteUpdateInfoHttp(), Restore-MergedUserConfig(), Test-IsGitRepo(), Update-FromGitHubHttp()

### Community 6 - "Backlog - AI Dev Prompt Clipboard"
Cohesion: 0.50
Nodes (3): Backlog - AI Dev Prompt Clipboard, Ideas & Tech Debt, Prioritized Backlog

### Community 8 - "AI Dev Prompt Clipboard: Diary Archive"
Cohesion: 0.33
Nodes (5): AI Dev Prompt Clipboard: Diary Archive, 📅 Archived Sprint: Week ending 2026-09-12, ✅ Done (2026-09-10 — System Tray, Windows Startup, App Identity, Auto-Updater & Finding #2), 🔬 Forensic Audit Findings - 2026-09-10, 🔬 Historical Forensic Audit Findings - Remediated Prior (2026-09-10)

### Community 9 - "Check-ForUpdatesAsync"
Cohesion: 0.67
Nodes (3): Check-ForUpdatesAsync(), Show-MainWindow(), Trigger-BackgroundUpdateCheck()

## Knowledge Gaps
- **35 isolated node(s):** `Corpus Check`, `Summary`, `Graph Freshness`, `Community Hubs (Navigation)`, `God Nodes (most connected - your core abstractions)` (+30 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)` connect `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)` to `Communities (8 total, 0 thin omitted)`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Why does `Communities (8 total, 0 thin omitted)` connect `Communities (8 total, 0 thin omitted)` to `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **What connects `Corpus Check`, `Summary`, `Graph Freshness` to the rest of the system?**
  _35 weakly-connected nodes found - possible documentation gaps or missing edges._