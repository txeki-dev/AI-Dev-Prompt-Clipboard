# AI Dev Prompt Clipboard: Developer Diary

**Current Date**: 2026-09-13

---

## 📊 Current State
**AI Dev Prompt Clipboard v1.2.1 Released**:
1. **Architectural Graph & Static Analysis** (`graphify`):
   - Local AST and topological extraction mapped in `graphify-out/graph.json` and [`GRAPH_REPORT.md`](file:///C:/Users/sergi/Documents/Txek%20Systems/AI-Assisted-Dev-Prompt-Clipboard/GRAPH_REPORT.md).
   - Automatic sync enabled via Git hooks (`post-commit`, `post-checkout`, and `graphify` merge driver).
2. **Core Features**:
   - Modern WPF dark-mode GUI (`app.ps1`) with 9 AI protocols, real-time search, category filters (Workflow, TDD, Setup, Auditoría, R&D), full prompt preview flyout, and resilient clipboard copy with retry backoff.
   - **System Tray Integration**: Persistent tray icon in Windows notification area ("Mostrar iconos ocultos") with context menu (Abrir, Buscar actualizaciones, Editar, Salir) and single/double-click toggling.
   - **Windows Startup Auto-boot**: Installed to `AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup` with `-Startup` switch to silently run in background on system boot.
   - **Native App Identity**: Custom `AppUserModelID` (`TxekSystems.AIDevPromptClipboard.App.1`) decoupling the process from `powershell.exe` on the Windows taskbar and displaying the custom squircle icon.
   - **Single-Instance IPC**: Named Mutex (`Global\TxekSystems_AIDevPromptClipboard_Mutex`) and EventWaitHandle (`Global\TxekSystems_AIDevPromptClipboard_ShowEvent`) ensuring only 1 resident process runs; secondary launches (`Ctrl+Alt+P` or desktop shortcut) wake the resident instance with 0ms latency.
   - **Dual-Mode Auto-Updater Engine**: Automated silent check on launch + manual button/menu option. Dual-mode architecture supporting both native Git plumbing (`git pull --ff-only`) and Standalone HTTP Fallback via GitHub API / archive download (for non-git environments), preserving user config and hot-restarting.
3. **Repository, License & Version Control**:
   - Git repository tracking `main` synchronized with remote origin `https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard.git`.
   - Licensed under PolyForm Noncommercial 1.0.0 for public open-source distribution.

---

## 📅 Weekly Summary (Week ending 2026-09-13)
- Restructured all 8 core AI development protocols to enforce decoupled backlog architecture and strict TDD loops.
- Introduced new RDi protocol (`<rdi_exploration_protocol>`) with dedicated UI category chip (`R&D`) and tag synchronization.
- Engineered Dual-Mode Auto-Updater supporting both native Git repos and standalone non-git installations via GitHub HTTPS API.

---

## ✅ Done (2026-09-13 — Prompt Catalog Restructuring, RDi Protocol & Dual-Mode Auto-Updater)

1. **Restructured Existing 8 AI Protocols**:
   - `INTRO` (`<session_start_hybrid>`): Added explicit context awareness rule, prohibited reading `backlog.md`/`diary_archive.md` on startup to preserve token budget.
   - `FEATURE_PLAN` (`<feature_plan_tdd>`): Rolled out requirements ingestion into `backlog.md` under `## Prioritized Backlog`, single highest-priority task selection, and mandatory Red Phase failing test creation.
   - `FEATURE_BUILD` (`<feature_build_tdd>`): Strict TDD Red-Green-Refactor loop, backlog promotion from `backlog.md` into `diary.md`, and clean refactoring using Graphify.
   - `OUTRO` (`<session_end_hybrid>`): Added Step 0 QA Gate (run test suite in terminal; abort immediately on any failure), compact `diary.md` maintenance, weekly archive triggers, and Conventional Commits workflow.
   - `INITIAL` (`<initial_setup_hybrid>`): Standardized persistent memory initialization with `.graphifyignore`, graph build, git hook, and 4 structured memory files (`README.md`, `diary.md`, `backlog.md`, `diary_archive.md`).
   - `MIGRATE` (`<migrate_to_hybrid>`): Updated migration steps to decouple `backlog.md`, delete `context.md`, install Graphify git hook, and review `README.md`.
   - `AUDIT` (`<codebase_audit_hybrid>`): Formalized forensic scan with Graphify, structured logging in `diary.md` with priority checkboxes (`[HIGH]`, `[MEDIUM]`, `[LOW]`), and active handoff to remediate.
   - `REMEDIATE` (`<remediate_all_audit_findings>`): Structured priority-sorted queue remediation loop (`[HIGH]` -> `[MEDIUM]` -> `[LOW]`), blast radius verification, zero regressions, and global QA gate.

2. **Added RDi Protocol (`<rdi_exploration_protocol>`)**:
   - Role: `Principal Research Architect & Innovation Lead`.
   - Category: `R&D` (`#EC4899`).
   - Purpose: Proactive R&D exploration using Graphify AST analysis, generating 3 to 5 high-impact proposals across `[PERF]`, `[ARCH]`, `[FEAT]`, and `[RESILIENCE]`.
   - Added interactive decision prompt for user backlog approval and automatic ingestion into `backlog.md` with `[ ] PENDING` status.

3. **Application & Infrastructure Synchronization**:
   - Updated `prompts.json` with all 9 updated/new protocols.
   - Enhanced `app.ps1` with new `R&D` filter chip, dynamic counter synchronization, and initial `Update-Filter` evaluation.
   - Initialized `backlog.md` with `## Prioritized Backlog` and `## Ideas & Tech Debt` sections.
   - Updated `README.md` catalog table and UI features to reflect 9 protocols and R&D filtering.

4. **Universal Dual-Mode Auto-Updater (Git + Standalone HTTP Fallback)**:
   - Implemented `Test-IsGitRepo` to accurately determine repository status.
   - Built standalone non-git updater pipeline (`Get-LocalVersionInfo`, `Get-RemoteUpdateInfoHttp`, `Update-FromGitHubHttp`).
   - Added `version.json` tracking local release version and commit hash for standalone installs.
   - Connected `Check-ForUpdatesAsync` and `Check-ForUpdates` to automatically branch between Git fast-forward pulls and standalone HTTPS zipball downloads without third-party dependencies.
   - Preserved UTF-8 BOM encoding across all script modifications for 100% PowerShell 5.1 compatibility.

---

## 📋 Active / Pending Tasks
- **Active Task**:
  - Ninguna activa (Dual-Mode Auto-Updater implementado, catálogo de prompts reestructurado y desplegado al 100%).
- **Pending Tasks**:
  - Monitorizar feedback de usuario sobre los 9 protocolos y auto-actualizaciones en entornos secundarios.

---

## 🎯 Next Immediate Step
- Listo para arrancar sesión de desarrollo asistido con INTRO (`<session_start_hybrid>`) o ejecutar OUTRO / RDi según se requiera.
