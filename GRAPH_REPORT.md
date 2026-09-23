# Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-23)

## Corpus Check
- 15 files · ~38,947 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 118 nodes · 180 edges · 16 communities
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d86e0017`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)
- Invoke-HttpUpdateStep
- AI Dev Prompt Clipboard 📋
- Communities (12 total, 0 thin omitted)
- Render-PromptCards
- Backlog - AI Dev Prompt Clipboard
- app.ps1
- Save-CurrentPromptEditor
- AI Dev Prompt Clipboard: Developer Diary
- AI Dev Prompt Clipboard: Diary Archive
- Write-AtomicUtf8File
- Select-Tab
- Invoke-GitUpdateStep

## God Nodes (most connected - your core abstractions)
1. `Render-PromptCards()` - 11 edges
2. `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)` - 11 edges
3. `Communities (12 total, 0 thin omitted)` - 10 edges
4. `AI Dev Prompt Clipboard 📋` - 9 edges
5. `AI Dev Prompt Clipboard: Diary Archive` - 9 edges
6. `Write-AtomicUtf8File()` - 8 edges
7. `AI Dev Prompt Clipboard: Developer Diary` - 8 edges
8. `Copy-PromptToClipboard()` - 7 edges
9. `Switch-Workspace()` - 7 edges
10. `Save-CurrentPromptEditor()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Delete-CurrentPromptEditor()` --calls--> `Write-AtomicUtf8File()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 13 → community 9_
- `Save-Metrics()` --calls--> `Write-AtomicUtf8File()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 13 → community 8_
- `Show-MainWindow()` --calls--> `Update-ActiveClipboardIndicator()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 8 → community 5_
- `Invoke-GitUpdateStep()` --calls--> `Restart-Application()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 1 → community 15_
- `Invoke-GitUpdateStep()` --calls--> `Restore-MergedUserConfig()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 13 → community 15_

## Import Cycles
- None detected.

## Communities (16 total, 0 thin omitted)

### Community 0 - "Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)"
Cohesion: 0.20
Nodes (10): Community Hubs (Navigation), Corpus Check, God Nodes (most connected - your core abstractions), Graph Freshness, Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13), Import Cycles, Knowledge Gaps, Suggested Questions (+2 more)

### Community 1 - "Invoke-HttpUpdateStep"
Cohesion: 0.33
Nodes (7): Check-ForUpdates(), Check-ForUpdatesAsync(), Get-LocalVersionInfo(), Get-RemoteUpdateInfoHttp(), Invoke-HttpUpdateStep(), Restart-Application(), Test-IsGitRepo()

### Community 3 - "AI Dev Prompt Clipboard 📋"
Cohesion: 0.14
Nodes (13): 🚀 Acceso Rápido y Métodos de Inicio, AI Dev Prompt Clipboard 📋, 🔄 Auto-Actualizaciones Dual-Mode desde GitHub (Git + Fallback HTTP), 🎨 Características de la Interfaz, 🛠️ Estructura del Proyecto, 💻 Instalación y Configuración de Atajo, 📄 Licencia, 🌟 Método 1: Instalador Automático de 1 Línea (Recomendado para usuarios no técnicos / Sin Git) (+5 more)

### Community 4 - "Communities (12 total, 0 thin omitted)"
Cohesion: 0.20
Nodes (10): Communities (12 total, 0 thin omitted), Community 0 - "Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)", Community 11 - "AI Dev Prompt Clipboard: Developer Diary", Community 1 - "Invoke-GitUpdateStep", Community 3 - "AI Dev Prompt Clipboard 📋", Community 4 - "Communities (11 total, 0 thin omitted)", Community 5 - "app.ps1", Community 6 - "Backlog - AI Dev Prompt Clipboard" (+2 more)

### Community 5 - "Render-PromptCards"
Cohesion: 0.22
Nodes (13): Copy-PromptToClipboard(), Get-SafeBrush(), Get-SafeClipboardText(), Get-SmartSuggestion(), Get-TemplateTokens(), Render-PromptCards(), Set-CardActiveState(), Set-SafeClipboardText() (+5 more)

### Community 6 - "Backlog - AI Dev Prompt Clipboard"
Cohesion: 0.50
Nodes (3): Backlog - AI Dev Prompt Clipboard, Ideas & Tech Debt, Prioritized Backlog

### Community 8 - "app.ps1"
Cohesion: 0.24
Nodes (6): Get-AvailableWorkspaces(), Init-WorkspacesDropdown(), Save-Metrics(), Show-MainWindow(), Track-PromptUsage(), Trigger-BackgroundUpdateCheck()

### Community 9 - "Save-CurrentPromptEditor"
Cohesion: 0.24
Nodes (12): Build-CategoryChips(), Delete-CurrentPromptEditor(), Get-NextCategoryName(), Get-NextPhasePrompt(), New-PromptItemSlug(), Save-Config(), Save-CurrentPromptEditor(), Set-CategoryFilter() (+4 more)

### Community 11 - "AI Dev Prompt Clipboard: Developer Diary"
Cohesion: 0.20
Nodes (8): 📋 Active / Pending Tasks, AI Dev Prompt Clipboard: Developer Diary, 📊 Current State, ✅ Done (2026-09-22), 🔬 Forensic Audit Findings - 2026-09-22, 🔬 Forensic Remediation: Zero-VBS Architecture (2026-09-22), 🎯 Next Immediate Step, 📅 Weekly Summary (Week ending 2026-09-13)

### Community 12 - "AI Dev Prompt Clipboard: Diary Archive"
Cohesion: 0.20
Nodes (9): AI Dev Prompt Clipboard: Diary Archive, 📅 Archived Sprint: Week ending 2026-09-12, 📅 Archived Sprint: Week ending 2026-09-13, ✅ Done (2026-09-10 — System Tray, Windows Startup, App Identity, Auto-Updater & Finding #2), ✅ Done (2026-09-13 — Product Strategy Initiatives v1.4.0), 🔬 Forensic Audit Findings - 2026-09-10, 🔬 Forensic Audit Findings - Remediated (2026-09-13 Session 2), 🔬 Historical Forensic Audit Findings - Remediated (2026-09-13 Session 1) (+1 more)

### Community 13 - "Write-AtomicUtf8File"
Cohesion: 0.40
Nodes (6): Import-WorkspacePackFile(), Merge-UserConfig(), Restore-MergedUserConfig(), Test-WorkspacePackContent(), Update-FromGitHubHttp(), Write-AtomicUtf8File()

### Community 14 - "Select-Tab"
Cohesion: 0.50
Nodes (4): Get-NextTabName(), Select-Tab(), Switch-NextTab(), Update-MetricsView()

### Community 15 - "Invoke-GitUpdateStep"
Cohesion: 0.67
Nodes (3): Get-GitBehindCount(), Get-GitDirtyStatus(), Invoke-GitUpdateStep()

## Knowledge Gaps
- **46 isolated node(s):** `Corpus Check`, `Summary`, `Graph Freshness`, `Community Hubs (Navigation)`, `God Nodes (most connected - your core abstractions)` (+41 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)` connect `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)` to `AI Dev Prompt Clipboard: Developer Diary`, `Communities (12 total, 0 thin omitted)`?**
  _High betweenness centrality (0.047) - this node is a cross-community bridge._
- **Why does `Communities (12 total, 0 thin omitted)` connect `Communities (12 total, 0 thin omitted)` to `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **What connects `Corpus Check`, `Summary`, `Graph Freshness` to the rest of the system?**
  _46 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `AI Dev Prompt Clipboard 📋` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._