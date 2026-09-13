# Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)

## Corpus Check
- 15 files · ~34,882 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 111 nodes · 160 edges · 11 communities
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5d2a42fe`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)
- Invoke-GitUpdateStep
- AI Dev Prompt Clipboard 📋
- Communities (11 total, 0 thin omitted)
- app.ps1
- Backlog - AI Dev Prompt Clipboard
- AI Dev Prompt Clipboard: Diary Archive
- Switch-Workspace

## God Nodes (most connected - your core abstractions)
1. `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)` - 11 edges
2. `Communities (11 total, 0 thin omitted)` - 11 edges
3. `Render-PromptCards()` - 10 edges
4. `AI Dev Prompt Clipboard 📋` - 9 edges
5. `Switch-Workspace()` - 7 edges
6. `AI Dev Prompt Clipboard: Developer Diary` - 7 edges
7. `Invoke-GitUpdateStep()` - 6 edges
8. `Invoke-HttpUpdateStep()` - 6 edges
9. `Update-ActiveClipboardIndicator()` - 6 edges
10. `Copy-PromptToClipboard()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Trigger-BackgroundUpdateCheck()` --calls--> `Check-ForUpdatesAsync()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 5 → community 1_
- `Copy-PromptToClipboard()` --calls--> `Track-PromptUsage()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 5 → community 9_

## Import Cycles
- None detected.

## Communities (11 total, 0 thin omitted)

### Community 0 - "Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)"
Cohesion: 0.11
Nodes (17): 📋 Active / Pending Tasks, AI Dev Prompt Clipboard: Developer Diary, 📊 Current State, ✅ Done (2026-09-13 — Product Strategy Initiatives v1.4.0), 🔬 Forensic Audit Findings - 2026-09-13, 🎯 Next Immediate Step, 📅 Weekly Summary (Week ending 2026-09-13), Community Hubs (Navigation) (+9 more)

### Community 1 - "Invoke-GitUpdateStep"
Cohesion: 0.21
Nodes (12): Check-ForUpdates(), Check-ForUpdatesAsync(), Get-GitBehindCount(), Get-GitDirtyStatus(), Get-LocalVersionInfo(), Get-RemoteUpdateInfoHttp(), Invoke-GitUpdateStep(), Invoke-HttpUpdateStep() (+4 more)

### Community 3 - "AI Dev Prompt Clipboard 📋"
Cohesion: 0.14
Nodes (13): 🚀 Acceso Rápido y Métodos de Inicio, AI Dev Prompt Clipboard 📋, 🔄 Auto-Actualizaciones Dual-Mode desde GitHub (Git + Fallback HTTP), 🎨 Características de la Interfaz, 🛠️ Estructura del Proyecto, 💻 Instalación y Configuración de Atajo, 📄 Licencia, 🌟 Método 1: Instalador Automático de 1 Línea (Recomendado para usuarios no técnicos / Sin Git) (+5 more)

### Community 4 - "Communities (11 total, 0 thin omitted)"
Cohesion: 0.18
Nodes (11): Communities (11 total, 0 thin omitted), Community 0 - "Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)", Community 10 - "Update-ActiveClipboardIndicator", Community 1 - "AI Dev Prompt Clipboard: Developer Diary", Community 2 - "app.ps1", Community 3 - "AI Dev Prompt Clipboard 📋", Community 4 - "Communities (11 total, 0 thin omitted)", Community 5 - "Check-ForUpdates" (+3 more)

### Community 5 - "app.ps1"
Cohesion: 0.17
Nodes (19): Copy-PromptToClipboard(), Get-AvailableWorkspaces(), Get-NextPhasePrompt(), Get-SafeClipboardText(), Get-SmartSuggestion(), Get-TemplateTokens(), Init-WorkspacesDropdown(), Render-PromptCards() (+11 more)

### Community 6 - "Backlog - AI Dev Prompt Clipboard"
Cohesion: 0.50
Nodes (3): Backlog - AI Dev Prompt Clipboard, Ideas & Tech Debt, Prioritized Backlog

### Community 8 - "AI Dev Prompt Clipboard: Diary Archive"
Cohesion: 0.33
Nodes (5): AI Dev Prompt Clipboard: Diary Archive, 📅 Archived Sprint: Week ending 2026-09-12, ✅ Done (2026-09-10 — System Tray, Windows Startup, App Identity, Auto-Updater & Finding #2), 🔬 Forensic Audit Findings - 2026-09-10, 🔬 Historical Forensic Audit Findings - Remediated Prior (2026-09-10)

### Community 9 - "Switch-Workspace"
Cohesion: 0.27
Nodes (11): Build-CategoryChips(), Delete-CurrentPromptEditor(), Save-Config(), Save-CurrentPromptEditor(), Save-Metrics(), Set-CategoryFilter(), Switch-NextCategory(), Switch-Workspace() (+3 more)

## Knowledge Gaps
- **42 isolated node(s):** `Corpus Check`, `Summary`, `Graph Freshness`, `Community Hubs (Navigation)`, `God Nodes (most connected - your core abstractions)` (+37 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)` connect `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)` to `Communities (11 total, 0 thin omitted)`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Why does `Communities (11 total, 0 thin omitted)` connect `Communities (11 total, 0 thin omitted)` to `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **What connects `Corpus Check`, `Summary`, `Graph Freshness` to the rest of the system?**
  _42 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._
- **Should `AI Dev Prompt Clipboard 📋` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._