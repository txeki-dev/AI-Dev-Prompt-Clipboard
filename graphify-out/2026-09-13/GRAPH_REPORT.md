# Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)

## Corpus Check
- 9 files · ~10,183 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 57 nodes · 61 edges · 9 communities (8 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6aab307e`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10)
- AI Dev Prompt Clipboard: Developer Diary
- app.ps1
- AI Dev Prompt Clipboard 📋
- Update-ActiveClipboardIndicator
- Check-ForUpdatesAsync
- Backlog - AI Dev Prompt Clipboard
- diary_archive.md

## God Nodes (most connected - your core abstractions)
1. `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10)` - 11 edges
2. `AI Dev Prompt Clipboard: Developer Diary` - 9 edges
3. `AI Dev Prompt Clipboard 📋` - 8 edges
4. `Check-ForUpdates()` - 5 edges
5. `Update-ActiveClipboardIndicator()` - 5 edges
6. `Trigger-BackgroundUpdateCheck()` - 3 edges
7. `Show-MainWindow()` - 3 edges
8. `Check-ForUpdatesAsync()` - 3 edges
9. `Copy-PromptToClipboard()` - 3 edges
10. `💻 Instalación y Configuración de Atajo` - 3 edges

## Surprising Connections (you probably didn't know these)
- `Show-MainWindow()` --calls--> `Update-ActiveClipboardIndicator()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 5 → community 4_
- `Check-ForUpdatesAsync()` --calls--> `Check-ForUpdates()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 5 → community 2_

## Import Cycles
- None detected.

## Communities (9 total, 1 thin omitted)

### Community 0 - "Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10)"
Cohesion: 0.15
Nodes (12): Communities (3 total, 1 thin omitted), Community 1 - "Check-ForUpdates", Community Hubs (Navigation), Corpus Check, God Nodes (most connected - your core abstractions), Graph Freshness, Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-10), Import Cycles (+4 more)

### Community 1 - "AI Dev Prompt Clipboard: Developer Diary"
Cohesion: 0.20
Nodes (9): 📋 Active / Pending Tasks, AI Dev Prompt Clipboard: Developer Diary, 📊 Current State, ✅ Done (2026-09-10 — System Tray, Windows Startup, App Identity, Auto-Updater & Finding #2), ✅ Done (2026-09-13 — Prompt Catalog Restructuring & RDi Protocol Addition), 🔬 Forensic Audit Findings - 2026-09-10, 🔬 Historical Forensic Audit Findings - Remediated Prior (2026-09-10), 🎯 Next Immediate Step (+1 more)

### Community 2 - "app.ps1"
Cohesion: 0.36
Nodes (4): Check-ForUpdates(), Exit-Application(), Get-GitBehindCount(), Restore-MergedUserConfig()

### Community 3 - "AI Dev Prompt Clipboard 📋"
Cohesion: 0.18
Nodes (10): 🚀 Acceso Rápido y Métodos de Inicio, AI Dev Prompt Clipboard 📋, 🔄 Auto-Actualizaciones desde GitHub (Motor Ekin), 🎨 Características de la Interfaz, 🛠️ Estructura del Proyecto, 💻 Instalación y Configuración de Atajo, 📄 Licencia, Opción 1: Doble clic (Recomendado) (+2 more)

### Community 4 - "Update-ActiveClipboardIndicator"
Cohesion: 0.40
Nodes (5): Copy-PromptToClipboard(), Get-SafeClipboardText(), Hide-MainWindow(), Set-CardActiveState(), Update-ActiveClipboardIndicator()

### Community 5 - "Check-ForUpdatesAsync"
Cohesion: 0.67
Nodes (3): Check-ForUpdatesAsync(), Show-MainWindow(), Trigger-BackgroundUpdateCheck()

### Community 6 - "Backlog - AI Dev Prompt Clipboard"
Cohesion: 0.50
Nodes (3): Backlog - AI Dev Prompt Clipboard, Ideas & Tech Debt, Prioritized Backlog

## Knowledge Gaps
- **29 isolated node(s):** `Corpus Check`, `Summary`, `Graph Freshness`, `Community Hubs (Navigation)`, `God Nodes (most connected - your core abstractions)` (+24 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `Corpus Check`, `Summary`, `Graph Freshness` to the rest of the system?**
  _29 weakly-connected nodes found - possible documentation gaps or missing edges._