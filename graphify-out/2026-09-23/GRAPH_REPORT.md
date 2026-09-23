# Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-23)

## Corpus Check
- 15 files · ~39,848 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 123 nodes · 191 edges · 11 communities
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d86e0017`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- AI Dev Prompt Clipboard 📋
- Communities (16 total, 0 thin omitted)
- Render-PromptCards
- Backlog - AI Dev Prompt Clipboard
- app.ps1
- Save-CurrentPromptEditor
- Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-23)
- AI Dev Prompt Clipboard: Diary Archive

## God Nodes (most connected - your core abstractions)
1. `Communities (16 total, 0 thin omitted)` - 14 edges
2. `Render-PromptCards()` - 12 edges
3. `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-23)` - 11 edges
4. `AI Dev Prompt Clipboard 📋` - 9 edges
5. `AI Dev Prompt Clipboard: Diary Archive` - 9 edges
6. `Write-AtomicUtf8File()` - 8 edges
7. `AI Dev Prompt Clipboard: Developer Diary` - 8 edges
8. `Copy-PromptToClipboard()` - 7 edges
9. `Update-NextPhaseIndicator()` - 7 edges
10. `Switch-Workspace()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Delete-CurrentPromptEditor()` --calls--> `Write-AtomicUtf8File()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 8 → community 9_
- `Show-MainWindow()` --calls--> `Reload-ActivePromptsIfModified()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 5 → community 9_
- `Copy-PromptToClipboard()` --calls--> `Track-PromptUsage()`  [EXTRACTED]
  app.ps1 → app.ps1  _Bridges community 5 → community 8_

## Import Cycles
- None detected.

## Communities (11 total, 0 thin omitted)

### Community 3 - "AI Dev Prompt Clipboard 📋"
Cohesion: 0.14
Nodes (13): 🚀 Acceso Rápido y Métodos de Inicio, AI Dev Prompt Clipboard 📋, 🔄 Auto-Actualizaciones Dual-Mode desde GitHub (Git + Fallback HTTP), 🎨 Características de la Interfaz, 🛠️ Estructura del Proyecto, 💻 Instalación y Configuración de Atajo, 📄 Licencia, 🌟 Método 1: Instalador Automático de 1 Línea (Recomendado para usuarios no técnicos / Sin Git) (+5 more)

### Community 4 - "Communities (16 total, 0 thin omitted)"
Cohesion: 0.14
Nodes (14): Communities (16 total, 0 thin omitted), Community 0 - "Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-13)", Community 11 - "AI Dev Prompt Clipboard: Developer Diary", Community 12 - "AI Dev Prompt Clipboard: Diary Archive", Community 13 - "Write-AtomicUtf8File", Community 14 - "Select-Tab", Community 15 - "Invoke-GitUpdateStep", Community 1 - "Invoke-HttpUpdateStep" (+6 more)

### Community 5 - "Render-PromptCards"
Cohesion: 0.18
Nodes (15): Copy-PromptToClipboard(), Get-SafeBrush(), Get-SafeClipboardText(), Get-SmartSuggestion(), Get-TemplateTokens(), Render-PromptCards(), Set-CardActiveState(), Set-SafeClipboardText() (+7 more)

### Community 6 - "Backlog - AI Dev Prompt Clipboard"
Cohesion: 0.50
Nodes (3): Backlog - AI Dev Prompt Clipboard, Ideas & Tech Debt, Prioritized Backlog

### Community 8 - "app.ps1"
Cohesion: 0.13
Nodes (24): Check-ForUpdates(), Check-ForUpdatesAsync(), Get-AvailableWorkspaces(), Get-GitBehindCount(), Get-GitDirtyStatus(), Get-LocalVersionInfo(), Get-NextTabName(), Get-RemoteUpdateInfoHttp() (+16 more)

### Community 9 - "Save-CurrentPromptEditor"
Cohesion: 0.24
Nodes (13): Build-CategoryChips(), Delete-CurrentPromptEditor(), Get-NextCategoryName(), Get-NextPhasePrompt(), New-PromptItemSlug(), Reload-ActivePromptsIfModified(), Save-Config(), Save-CurrentPromptEditor() (+5 more)

### Community 11 - "Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-23)"
Cohesion: 0.10
Nodes (18): 📋 Active / Pending Tasks, AI Dev Prompt Clipboard: Developer Diary, 📊 Current State, ✅ Done (2026-09-22), 🔬 Forensic Audit Findings - 2026-09-22, 🔬 Forensic Remediation: Zero-VBS Architecture (2026-09-22), 🎯 Next Immediate Step, 📅 Weekly Summary (Week ending 2026-09-13) (+10 more)

### Community 12 - "AI Dev Prompt Clipboard: Diary Archive"
Cohesion: 0.20
Nodes (9): AI Dev Prompt Clipboard: Diary Archive, 📅 Archived Sprint: Week ending 2026-09-12, 📅 Archived Sprint: Week ending 2026-09-13, ✅ Done (2026-09-10 — System Tray, Windows Startup, App Identity, Auto-Updater & Finding #2), ✅ Done (2026-09-13 — Product Strategy Initiatives v1.4.0), 🔬 Forensic Audit Findings - 2026-09-10, 🔬 Forensic Audit Findings - Remediated (2026-09-13 Session 2), 🔬 Historical Forensic Audit Findings - Remediated (2026-09-13 Session 1) (+1 more)

## Knowledge Gaps
- **50 isolated node(s):** `Corpus Check`, `Summary`, `Graph Freshness`, `Community Hubs (Navigation)`, `God Nodes (most connected - your core abstractions)` (+45 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-23)` connect `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-23)` to `Communities (16 total, 0 thin omitted)`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Why does `Communities (16 total, 0 thin omitted)` connect `Communities (16 total, 0 thin omitted)` to `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-23)`?**
  _High betweenness centrality (0.046) - this node is a cross-community bridge._
- **What connects `Corpus Check`, `Summary`, `Graph Freshness` to the rest of the system?**
  _50 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `AI Dev Prompt Clipboard 📋` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Communities (16 total, 0 thin omitted)` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `app.ps1` be split into smaller, more focused modules?**
  _Cohesion score 0.1330049261083744 - nodes in this community are weakly interconnected._
- **Should `Graph Report - AI-Assisted-Dev-Prompt-Clipboard  (2026-09-23)` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._