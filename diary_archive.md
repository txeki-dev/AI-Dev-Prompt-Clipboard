# AI Dev Prompt Clipboard: Diary Archive

Historical completed sprint tasks and archived weekly summaries.

---

## 📅 Archived Sprint: Week ending 2026-09-12

## ✅ Done (2026-09-10 — System Tray, Windows Startup, App Identity, Auto-Updater & Finding #2)

1. **Windows Startup & System Tray Integration**:
   - Updated `install-shortcut.ps1` to create shortcuts in Desktop, Start Menu Programs, and the Windows `Startup` folder (`AI Prompt Clipboard.lnk` with `-Startup` switch).
   - Configured `System.Windows.Forms.NotifyIcon` with custom icon, tooltip, balloon tips, and right-click context menu (`Abrir`, `Buscar actualizaciones`, `Editar prompts.json`, `Salir`).
   - Configured `ShutdownMode = OnExplicitShutdown` so closing or hiding the window keeps the process alive in the notification area.

2. **App Identity & Single-Instance IPC**:
   - Implemented P/Invoke `SetCurrentProcessExplicitAppUserModelID` via `shell32.dll` to prevent Windows from showing the blue PowerShell terminal icon on the taskbar.
   - Implemented named Mutex and `EventWaitHandle` with a 150ms IPC listener in the WPF dispatcher, waking the existing window on secondary invocations (`Ctrl + Alt + P`).

3. **GitHub Auto-Updater (Ported from Ekin)**:
   - Implemented `Check-ForUpdates` replicating Ekin's hardened update flow (`git rev-parse`, `git fetch origin`, `git status -uno` check for "behind", dirty tree guard, confirmation dialog, `git pull --ff-only`, graphify refresh, and seamless process restart).

4. **Remediated Finding #2 (Path Quoting & Shortcut Icon Syntax)**:
   - Added escaped quotes in `Start-Process notepad.exe -ArgumentList "`"$promptsFile`""` to prevent argument splitting on space-containing paths (`Txek Systems`).
   - Hardened `install-shortcut.ps1` icon location logic to prevent duplicate comma index notation.

5. **Bugfix: Card Closure Variable Scoping & Shortcut Update Wake**:
   - Fixed PowerShell closure variable capture issue where all cards evaluated the last prompt (`REMEDIATE`). Enforced localized closures via `.GetNewClosure()` and individual element tagging.
   - Added `Trigger-BackgroundUpdateCheck` on `Show-MainWindow` so that opening via desktop shortcut or `Ctrl+Alt+P` automatically re-checks GitHub for updates in the background (throttled).

6. **Persistent Active Clipboard Indicator & Clean Feedback**:
   - Removed temporary card background flash (`#182E25`) and button text timers on copy; kept the clean green toast bar (`✓ ¡Copiado al portapapeles: [ TITLE ]!`) as requested.
   - Implemented dynamic active clipboard tracking (`Update-ActiveClipboardIndicator`, `Get-SafeClipboardText`, `Set-CardActiveState`) that identifies which prompt is currently resident in the Windows clipboard (supporting both raw prompt text and header-formatted text, normalized for CRLF/LF).
   - Card marked with an emerald border (`#34D399`) and an active badge (`📋 En portapapeles`). External clipboard text automatically clears all active card markers.
   - Wired indicator updates to `Copy-PromptToClipboard`, `Show-MainWindow`, `$window.add_Activated`, `$window.add_MouseEnter`, and post-card generation.

7. **Remediated Finding #1 (Auto-Updater Dirty Working Tree Blocker & .gitignore)**:
   - Filtered runtime configuration (`config.json`) and cache paths (`graphify-out/cache/`, `.cache/`) in `Check-ForUpdates` so that modifying UI preferences or running graphify queries does not falsely mark the repository dirty.
   - Added local configuration snapshotting and automatic restoration around `git pull --ff-only`, ensuring user settings are preserved while eliminating checkout conflicts.
   - Created comprehensive `.gitignore` covering `graphify-out/cache/`, `*.log`, `scratch/`, `test_*.ps1`, and Windows system artifacts.

8. **Remediated Findings #2 to #7 (Complete Forensic Audit Remediation)**:
   - **Finding #2 (Language-Agnostic Branch Check)**: Replaced string match on `behind` with Git plumbing `git rev-list --count HEAD..@{u}` and fallback to `HEAD..origin/main`, ensuring reliable update detection across all language configurations.
   - **Finding #3 (Asynchronous Update Engine)**: Implemented non-blocking background check `Check-ForUpdatesAsync` using an isolated runspace via `[powershell]::Create()`. Network I/O runs off the UI thread with zero UI freeze.
   - **Finding #4 (DragMove Guard)**: Added primary button state check (`MouseButtonState::Pressed`) and exception handling to prevent unhandled `InvalidOperationException` on titlebar clicks.
   - **Finding #5 (IPC Timer Optimization)**: Tuned `$ipcTimer` to `Background` priority, 200ms interval, and ensured explicit disposal in `Exit-Application`.
   - **Finding #6 (Clean Signature for Copy-PromptToClipboard)**: Removed dead parameters `$cardBorder` and `$copyBtn` from `Copy-PromptToClipboard` and eliminated `$thisBtn`.
   - **Finding #7 (Hotkey Collision Prevention)**: Removed duplicate `CTRL+ALT+P` assignment from Start Menu `.lnk` in `install-shortcut.ps1`, preserving single authority on Desktop shortcut.

9. **PolyForm Noncommercial License 1.0.0 (Ported & Adapted from Ekin)**:
   - Added `LICENSE` with the PolyForm Noncommercial 1.0.0 terms, configured with explicit notice: `Required Notice: Copyright 2026 Txek Systems (https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard)`.
   - Updated `README.md` with license badge and dedicated `## 📄 Licencia` section for public repository launch.

10. **Remediated Shortcut Launch Failure & Self-Healing Launcher**:
    - **Diagnóstico de causa raíz**: En equipos secundarios o al mover archivos, si `install-shortcut.ps1` se ejecutaba fuera de la raíz del proyecto o sin clonar todos los ficheros, `$scriptDir` no contenía `launch.vbs`. El instalador creaba los accesos directos sin validar la existencia de los ejecutables, provocando que Windows Script Host mostrara el error emergente *"No se encuentra el archivo de comandos ... launch.vbs"*. Además, archivos descargados de la web retenían el bloqueo Mark-of-the-Web (`Zone.Identifier`) de Windows SmartScreen.
    - **Resolución integral implementada**:
      - **Resolución inteligente de ruta**: `install-shortcut.ps1` escanea múltiples candidatos (`$AppDir`, `$PSScriptRoot`, `$MyInvocation`, `Get-Location` y subcarpetas) y valida la presencia de `app.ps1` antes de proceder. Si no se encuentra, aborta con mensaje descriptivo en lugar de crear accesos directos rotos.
      - **Auto-reparación (Self-Healing)**: Tanto `install-shortcut.ps1` como `app.ps1` detectan si `launch.vbs` falta y lo regeneran automáticamente con codificación ASCII limpia.
      - **Desbloqueo automático**: Ejecuta `Unblock-File` sobre los archivos del proyecto para evitar bloqueos por Windows SmartScreen.
      - **Ruta absoluta y fallback a PowerShell**: Usa la ruta completa a `wscript.exe` y proporciona fallback automático (o mediante `-DirectPowerShell`) para invocar directamente `powershell.exe -WindowStyle Hidden` si el motor VBScript estuviera desactivado.
      - **Lanzadores batch en 1 clic**: Se crearon `launch.bat` (arranque directo con doble clic) e `install.bat` (instalación de accesos directos en 1 clic sin tocar PowerShell).
      - **Fallback en reinicio de Auto-Updater**: Añadido fallback en `app.ps1` (`Check-ForUpdates`) para reiniciar con PowerShell directo si `launch.vbs` no existiera.

11. **Updated AUDIT & REMEDIATE Protocols (Actionable Backlog & Queue Remediation)**:
    - Actualizado protocolo `AUDITORY` (`<codebase_audit_hybrid>`): rol `Principal Security & Performance Auditor`, escaneo de God-nodes y módulos huérfanos con Graphify, logging estricto como checkboxes en `diary.md` y transición de "Active Task" a `<remediate_all_audit_findings>`.
    - Actualizado protocolo `REMEDIATE` a `<remediate_all_audit_findings>`: rol `Principal Staff Engineer & Remediation Specialist`, resolución sistemática en cola clasificada por prioridad (HIGH -> MEDIUM -> LOW), comprobación de blast radius previa a edición, verificación unitaria individual, actualización de estado en tiempo real y QA gate global.
    - Actualizados y sincronizados `prompts.json`, `README.md` y `diary.md`.

12. **Remediated All Forensic Audit Findings (2026-09-10)**:
    - `[x] DONE: [HIGH] app.ps1 (Check-ForUpdatesAsync / Exit-Application)`: Añadido umbral de timeout de 30s (`$maxTicks = 60`) al timer de sondeo y cancelación/liberación explícita del runspace `$script:bgUpdatePS` en `Exit-Application`.
    - `[x] DONE: [HIGH] app.ps1 (Check-ForUpdates)`: Implementado `Restore-MergedUserConfig` que fusiona de forma segura las preferencias locales del usuario sobre el nuevo esquema de `config.json` descargado de upstream sin sobrescrituras destructivas.
    - `[x] DONE: [MEDIUM] app.ps1 (Update-ActiveClipboardIndicator)`: Pre-normalización de prompts en la construcción de tarjetas (`NormalizedPrompt` y `NormalizedHeaderPrompt`), eliminando asignaciones de memoria y reemplazos regex en cada evento de hover sobre la interfaz.
    - `[x] DONE: [MEDIUM] app.ps1 / install-shortcut.ps1`: Aplicado parámetro `-LiteralPath` en todas las operaciones de sistema de ficheros (`Set-Location`, `Test-Path`, `Get-Content`, `New-Item`), protegiendo la ejecución en rutas que contengan corchetes `[` o `]`.
    - `[x] DONE: [MEDIUM] app.ps1 (Check-ForUpdates)`: Modularizado el God-node de actualización en funciones de responsabilidad única: `Get-GitBehindCount`, `Get-GitDirtyStatus` y `Restore-MergedUserConfig`.
    - `[x] DONE: [LOW] app.ps1 (Update-Filter)`: Corregida la concordancia gramatical del contador de protocolos para mostrar `"1 protocolo"` en singular cuando solo hay un resultado coincidente.
    - `[x] DONE: [LOW] install-shortcut.ps1`: Verificación y creación preventiva de las carpetas de destino (`Desktop`, `Programs`, `Startup`) antes de crear accesos directos, compatible con entornos con redirección de carpetas o OneDrive.

---

## 🔬 Forensic Audit Findings - 2026-09-10

- [x] [HIGH] app.ps1 (Check-ForUpdatesAsync / Exit-Application): DONE: Added 30s timeout threshold and explicit runspace cancellation/disposal on shutdown.
- [x] [HIGH] app.ps1 (Check-ForUpdates): DONE: Implemented Restore-MergedUserConfig to merge user settings safely over new schema keys.
- [x] [MEDIUM] app.ps1 (Update-ActiveClipboardIndicator): DONE: Pre-cached normalized prompts on card creation; eliminated per-hover regex allocations.
- [x] [MEDIUM] app.ps1 / install-shortcut.ps1: DONE: Enforced -LiteralPath across all filesystem calls, preventing wildcard errors on bracketed paths.
- [x] [MEDIUM] app.ps1 (Check-ForUpdates): DONE: Modularized God-node into Get-GitBehindCount, Get-GitDirtyStatus, and Restore-MergedUserConfig.
- [x] [LOW] app.ps1 (Update-Filter): DONE: Added singular/plural formatting for protocol count badge ("1 protocolo" vs "N protocolos").
- [x] [LOW] install-shortcut.ps1: DONE: Added directory existence verification and creation for shell target directories before creating .lnk files.

---

## 🔬 Historical Forensic Audit Findings - Remediated Prior (2026-09-10)
- ✅ **[DONE 2026-09-10] Auto-Updater permanently blocked by dirty working tree on settings change or graphify cache**
- ✅ **[DONE 2026-09-10] Locale-dependent branch check in Check-ForUpdates (behind string match failure)**
- ✅ **[DONE 2026-09-10] UI thread freezing on synchronous network git fetch origin in WPF Dispatcher**
- ✅ **[DONE 2026-09-10] Unchecked mouse button state in Window DragMove (InvalidOperationException)**
- ✅ **[DONE 2026-09-10] 150ms IPC polling timer on UI thread (continuous dispatcher wakeups)**
- ✅ **[DONE 2026-09-10] Vestigial dead arguments in Copy-PromptToClipboard**
- ✅ **[DONE 2026-09-10] Duplicate Hotkey registration in Desktop and Start Menu shortcuts**
- ✅ **[DONE 2026-09-09] Clipboard lock contention (COMException CLIPBRD_E_CANT_OPEN)**
- ✅ **[DONE 2026-09-10] Path quoting in editor launch and icon specifier syntax in shortcut installer**
- ✅ **[DONE 2026-09-10] Redundant timer garbage collection overhead on rapid multiple card clicks**

---

## 📅 Archived Sprint: Week ending 2026-09-13

## ✅ Done (2026-09-13 — Product Strategy Initiatives v1.4.0)

1. **Integrated In-App Visual Prompt Editor & Creator (`[UX-REV]`)**:
   - Designed and integrated `PromptEditorOverlay` modal in WPF with dark-mode aesthetic.
   - Added `+ Nuevo` button in search row and `✏️` edit button on each prompt card.
   - Supports editing Title, Tag, Role, Category, Color (Hex), Description, and Multiline Prompt with `{{var}}` interpolation.
   - Implemented in-memory hot-reload via `Render-PromptCards` and `Build-CategoryChips`, updating the UI instantly without application restart.
   - Added confirmation dialog for deletion and persistence to the active pack JSON file.

2. **Built Multi-Workspace & Team Profiles Engine (`[BIZ-CAP]`)**:
   - Created `packs/` directory structure with modular pack loader (`Get-AvailableWorkspaces`, `Switch-Workspace`).
   - Pre-seeded 3 curated packs:
     - `core-engineering.json`: 10 core dev lifecycle protocols.
     - `frontend-ui.json`: 4 specialized frontend, design system, and accessibility protocols.
     - `security-devops.json`: 4 specialized DevSecOps, threat modeling, and container hardening protocols.
   - Added workspace dropdown `CmbWorkspace` in navigation bar alongside `📤 Exportar` and `📥 Importar` buttons.
   - Integrated workspace persistence in `config.json` (`ActivePack`).

3. **Created Developer Productivity & Telemetry Dashboard (`[DATA-EXP]`)**:
   - Added third navigation tab `📊 Métricas` (`TabMetrics`) and view grid `ViewMetrics`.
   - Local JSON telemetry store in `metrics.json` tracking total prompt copies, TDD cycles, frequency by prompt ID, and category breakdown.
   - 4 live KPI cards: Total Copiados, Ciclos TDD, Ratio Disciplina TDD %, and Protocolo #1.
   - Visual distribution bar charts and recent activity feed.
   - Added `📋 Copiar Resumen Markdown` button exporting formatted standup/retrospective markdown directly to clipboard.

4. **Engineered DEV FLUX Smart Sequence Stepper (`[AUTOMATION]`)**:
   - Defined progression state machine: `initial -> intro -> feature_plan -> feature_build -> audit -> remediate -> outro` (with non-linear bridges for `rdi`, `product_strategy`, and `migrate`).
   - Integrated clickable `NextPhasePill` in footer status bar with dynamic phase label.
   - Hooked global keyboard accelerator **`Ctrl + Alt + N`** to step to the next phase automatically.

5. **Engineered Forensic Remediation for Auto-Updater & Mutex Race Condition (`[REMEDIATION]`)**:
   - Preserved mandatory UTF-8 BOM encoding across `app.ps1` to prevent Windows PowerShell 5.1 parser crashes on unicode emojis and accents.
   - Fixed regex wildcard matching bug in `Get-GitDirtyStatus` (`-match '^\?\?\s+'`) so untracked files no longer falsely flag working tree as dirty.
   - Resolved shutdown/restart race condition by placing Mutex and tray icon release at the very beginning of `Exit-Application` and `Restart-Application` (non-blocking).
   - Added 500ms `WaitOne` grace period in single-instance mutex initialization to absorb rapid process restarts.
   - Enhanced `Check-ForUpdatesAsync` to detect local disk file modifications alongside remote git behind commits.
   - Hardened `Show-MainWindow` with momentary `Topmost` foreground elevation.

6. **Upgraded Protocol Suite to 11 Protocols & Extended DEV FLUX Map (`[PROTOCOLS]`)**:
   - Refactored `AUDIT` (`<codebase_audit_hybrid>`): comprehensive forensic audit spanning cybersecurity, QA coverage gaps, test fragility, and code quality using Graphify AST analysis.
   - Introduced 11th protocol `BUSINESS STRATEGY` (`<business_strategy_advisory>`): SaaS/B2B founder consultation covering monetization tiers, licensing architectures, GTM ICP, fiscal setups, and `BUSINESS.md` persistence.
   - Updated DEV FLUX map across `app.ps1` (embedded ASCII diagram card + `BtnFluxBiz` interactive quick-launch button + stepper progression) and `README.md`.

7. **DEV FLUX Cleanup & Reactive Category Filter Chips Engine (`[UI/UX]`)**:
   - Removed legacy `dev_flux.png` visual rendering and `BtnOpenFullFlux` button from DEV FLUX tab.
   - Upgraded DEV FLUX view to exclusively display the clean monospace ASCII architecture map with direct navigation button `📋 Ver Catálogo Completo` to switch to Prompts tab.
   - Reorganized "ACCESOS RÁPIDOS POR FASE" into 5 distinct architectural phases strictly aligned with the workflow map:
     - *Fase 1: Inicio Proyecto* (`INITIAL`, `MIGRATE`).
     - *Fase 2: Sesión* (`INTRO`).
     - *Fase 3: Innovación & Estrategia* (`RDi`, `PRODUCT_STRATEGY`, `BUSINESS_STRATEGY`).
     - *Fase 4: Diagnóstico & TDD* (`AUDIT`, `REMEDIATE`, `FEATURE_PLAN`, `FEATURE_BUILD`).
     - *Fase 5: Cierre de Sesión* (`OUTRO`).
   - Diagnosed and resolved the root cause of non-responsive category chips (`TODOS`, `WORKFLOW`, `TDD`, `SETUP`, `AUDITORÍA`, `R&D`, `ESTRATEGIA`): eliminated the PowerShell `.GetNewClosure()` dynamic module scope trap that kept `$script:currentCategory` permanently locked to `"All"` in script scope.
   - Implemented centralized `Set-CategoryFilter` function with instantaneous `PreviewMouseLeftButtonDown` routing, smooth hover states, and real-time protocol count badges (`Todos (11)`, `Workflow (2)`, `TDD (2)`, `Setup (2)`, `Auditoría (2)`, `R&D (1)`, `Estrategia (2)`).
   - Enhanced DEV FLUX phase buttons with dual interaction: Left-click copies prompt to clipboard (with QuickFill if templated), Right-click automatically switches to `📋 Protocolos` and filters the target category.
   - Preserved mandatory UTF-8 with BOM on `app.ps1`, verified with 0 AST errors.

8. **Smooth Two-Finger Touchpad & Mouse Wheel Scrolling Engine for DEV FLUX (`[UI/UX]`)**:
   - Diagnosed root cause of scrolling failure in DEV FLUX: nested `AsciiDiagramScrollViewer` intercepted all `MouseWheel` events and marked them as handled, preventing the outer `DevFluxScrollViewer` from scrolling when the cursor hovered over the ASCII diagram card (~80% of the screen).
   - Hooked `Add_PreviewMouseWheel` on `AsciiDiagramScrollViewer` to capture tunneling vertical scroll deltas from precision touchpads and mouse wheels, smoothly routing them to `$devFluxScrollViewer.ScrollToVerticalOffset($devFluxScrollViewer.VerticalOffset - ($e.Delta * 0.85))`.
   - Preserved horizontal diagram panning when Shift is held (`Shift + Wheel/Touchpad`).
   - Configured `Background="Transparent"` and `Focusable="True"` on `DevFluxScrollViewer` and ensured keyboard/touch focus is set upon tab selection (`Select-Tab -tabName "DevFlux"`).
   - Validated complete clean execution with 0 PowerShell AST parser errors, clean UTF-8 with BOM, and tested live touchpad delta simulation.

9. **Triple-Tab Keyboard Switching Engine (`Ctrl + Tab` / `Shift + Tab`) (`[UI/UX]`)**:
   - Added `Switch-NextTab` function with bidirectional modular index cycling across `PROTOCOLOS` (1), `DEV FLUX` (2), and `MÉTRICAS` (3).
   - Hooked `$window.Add_PreviewKeyDown` to intercept tunneling `Tab` events before WPF's internal `KeyboardNavigation` manager swallows them.
   - Bound **`Ctrl + Tab`** (and **`Ctrl + Shift + Tab`**) to cycle main tabs.
   - Preserved standard focus navigation in input fields when modal overlays (Prompt Editor, QuickFill, Preview) are active.
   - Tested live with simulated tab events, verified 0 AST parser errors, and updated `README.md`.

10. **Emoji Glyph Rendering, Hardened Win32/WinForms Clipboard Engine & Category Cycling (`[UI/UX]`)**:
    - Fixed broken `"([char]::... Copiar"` text and missing glyph boxes (`□`) by setting explicit `FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"` across all buttons (`$btnPreview` 👁️, `$btnEdit` ✏️, `$btnCopy` 📋/⚡, `$lblActive` 📋).
    - Eliminated `CLIPBRD_E_CANT_OPEN` COM exceptions by switching `Copy-PromptToClipboard` and `Get-SafeClipboardText` to `System.Windows.Forms.Clipboard.SetDataObject(..., $true, 10, 50)` with built-in retry backoff.
    - Fixed card click behavior: clicking anywhere on a prompt card directly copies it to the clipboard and immediately lights up the card border green (`#34D399`) with the `📋 En portapapeles` badge. Clicking `⚡ Rellenar` opens the QuickFill parameter form.
    - Implemented **`Shift + Tab`** category cycling inside `PROTOCOLOS` (`Switch-NextCategory`), dynamically stepping through all category chips (`Todos -> Workflow -> TDD -> Setup -> Auditoría -> R&D -> Estrategia -> Todos`) with instant reactive filtering.

11. **Comprehensive Codebase Remediation across Security, QA, and Architecture (`[REMEDIATION]`)**:
    - `[x] [HIGH] [SECURITY]` `app.ps1` (`Update-FromGitHubHttp`): Enforced SHA-256 cryptographic hash computation, zip magic byte verification (`PK 0x03 0x04`), and Zip-Slip path traversal protection on downloaded update archives.
    - `[x] [HIGH] [SECURITY]` `launch.vbs` (`WshShell.Run`): Implemented strict quote escaping (`Replace(arg, """", """""")`) and boundary quoting across `launch.vbs` and self-healing templates in `app.ps1` and `install-shortcut.ps1`, preventing command injection.
    - `[x] [HIGH] [BUG]` `app.ps1` (`Update-FromGitHubHttp`): Engineered safe rename-then-copy mechanism (`.old` swap) to prevent Windows file-locking `IOException` on active running script files (`app.ps1`), with automatic cleanup of `.old` artifacts on process startup.
    - `[x] [HIGH] [BUG]` `app.ps1` (`Restore-MergedUserConfig`): Added strict null and whitespace checks on `$configBackupJson` to guarantee `config.json` is never overwritten with an empty payload.
    - `[x] [MEDIUM] [QA]` `tests/app.Tests.ps1` & `tests/run-tests.bat`: Engineered automated unit and regression test suite with 10 test suites and 38 deterministic assertions (AST syntax, template tokens, smart suggestions, git dirty filters, config merging, category cycling, tab cycling, sequence stepper, pack discovery, and metrics), achieving 100% Green QA gate.
    - `[x] [MEDIUM] [BUG]` `app.ps1` (`BtnOpenFolder` & Tray `menuEdit`): Replaced hardcoded `prompts.json` path with `$script:activePromptsPath`, ensuring the currently active workspace pack is opened for editing.
    - `[x] [MEDIUM] [TECH-DEBT]` `app.ps1` (`Check-ForUpdates`): Decoupled monolithic God-node into modular single-purpose helper functions: `Invoke-GitUpdateStep` and `Invoke-HttpUpdateStep`, orchestrated by a lean coordinator.
    - `[x] [MEDIUM] [TECH-DEBT]` `app.ps1` (Error Handling Hygiene): Replaced bare `catch {}` blocks in `Save-Config`, `Save-Metrics`, and `Load-Metrics` with diagnostic warnings and status feedback.
    - `[x] [LOW] [CLEANUP]` `app.ps1` (`PromptCountBadge`): Converted hardcoded `"10 protocolos"` in XAML to dynamic count binding on startup and upon switching workspace packs.
    - `[x] [LOW] [CLEANUP]` `app.ps1` (`NativeClipboardHelper` & HwndSource Hook): Added proper hook removal (`$source.RemoveHook`) and unmanaged resource disposal (`$source.Dispose()`) across window close, exit, and restart sequences.

12. **Universal Non-Technical Installer Ecosystem (`setup.ps1` & Inno Setup `.iss`) (`[DISTRIBUTION]`)**:
    - Built `setup.ps1` automated 1-line web installer (`Win + R` / PowerShell) that downloads from GitHub, installs to `%LOCALAPPDATA%\Programs\AI-Dev-Prompt-Clipboard`, preserves configs, unlocks SmartScreen, creates shortcuts, and launches the app.
    - Created Inno Setup script `installer.iss` producing `AI-Prompt-Clipboard-Setup.exe` with standard Windows wizard, non-admin installation, desktop/startup shortcuts with `Ctrl+Alt+P`, and clean uninstaller in Windows Settings.
    - Configured GitHub Actions workflow `.github/workflows/build-installer.yml` to automatically compile and publish the Windows Setup `.exe`.
    - Integrated `setup.ps1` into automated test suite (`tests/app.Tests.ps1`, 39/39 passing).
    - Extensively documented all 4 installation tiers (One-Liner, `.exe` Setup, ZIP, Git Clone) in `README.md`.

13. **Comprehensive Forensic Remediation (Session 2) across Security, Architecture, and QA Gate (`[REMEDIATION]`)**:
    - `[x] [HIGH] [SECURITY]` `app.ps1` (`Update-FromGitHubHttp`) & `setup.ps1`: Enforced in-memory pre-extraction Zip-Slip traversal validation on all archive entries using `ZipFile::OpenRead` prior to disk extraction.
    - `[x] [HIGH] [BUG]` `app.ps1` (`Save-CurrentPromptEditor`, `Delete-CurrentPromptEditor`, `Switch-Workspace`): Unified variable scoping to `$script:prompts` across all mutation and serialization points, ensuring added/deleted prompts reliably persist to disk and workspace packs update cleanly.
    - `[x] [HIGH] [BUG]` `app.ps1` (Window Lifecycle & Alt+F4): Registered `$window.Add_Closing` handler to intercept Alt+F4 and OS close commands, safely redirecting to `Hide-MainWindow` and preserving the resident WPF window HWND.
    - `[x] [HIGH] [BUG]` `installer.iss` vs `setup.ps1`: Unified Inno Setup install destination to `{localappdata}\Programs\AI-Dev-Prompt-Clipboard`, perfectly aligning with `setup.ps1` and eliminating dual parallel installations.
    - `[x] [MEDIUM] [QA]` `tests/app.Tests.ps1`: Upgraded test suite to dynamically extract and execute production functions (`Get-TemplateTokens`, `Get-SmartSuggestion`, `Get-NextPhasePrompt`) directly from `app.ps1` AST in isolation, eliminating duplicate mock implementations.
    - `[x] [MEDIUM] [QA]` `tests/app.Tests.ps1` (Business Rules Divergence): Synchronized sequence stepper assertions with canonical production DEV FLUX rules (`outro -> feature_plan`, `rdi -> product_strategy -> business_strategy -> feature_plan`) and aligned TDD discipline ratio calculation (30%).
    - `[x] [MEDIUM] [BUG]` `app.ps1` (`Check-ForUpdatesAsync`): Initialized `$script:scriptFile` and `$script:startupScriptWriteTime` at process startup, enabling accurate local disk file modification detection.
    - `[x] [MEDIUM] [BUG]` `setup.ps1`: Added proactive process termination of running background instances, safe file copy with `.old` swap fallback, and smart non-destructive config schema merging.
    - `[x] [MEDIUM] [BUG]` `.github/workflows/build-installer.yml`: Replaced hardcoded x86 ISCC path with dynamic detection across Inno Setup 6/7, 32-bit/64-bit, chocolatey bin, and system PATH.
    - `[x] [MEDIUM] [TECH-DEBT]` `app.ps1` (`btnExportMetrics`): Extracted shared `Set-SafeClipboardText` helper with retry-backoff loop across `Copy-PromptToClipboard` and metrics export, eliminating `CLIPBRD_E_CANT_OPEN` failures.
    - `[x] [LOW] [CLEANUP]` `GRAPH_REPORT.md` (AST Extraction Metadata): Verified and documented `setup.ps1` and `install-shortcut.ps1` as standalone CLI/Web entrypoints in knowledge graph and project documentation.

14. **CI/CD Inno Setup Hotfix & Packaging Gate (`[CI/CD]` / `[REMEDIATION]`)**:
    - **Diagnóstico de causa raíz**: El workflow de GitHub Actions fallaba en el paso `Compile Inno Setup (.exe)` (Job ID `103765351183`) con `Error on line 49 in installer.iss: Source file "metrics.json" does not exist`. `metrics.json` es telemetría de ejecución ignorada por `.gitignore`, por lo que en el runner limpio de GitHub Actions no existía en disco.
    - **Remediación en `installer.iss`**: Se eliminó `metrics.json` de la sección `[Files]`. La telemetría es auto-generada por `app.ps1` en el primer uso y preservada de forma natural en las actualizaciones.
    - **Robustecimiento de CI/CD (`build-installer.yml`)**: Creación defensiva previa de la carpeta `dist/`, validación explícita de `$LASTEXITCODE` tras invocar `iscc.exe`, y corrección de la condición y nombres de tags para publicación en GitHub Releases (`refs/tags/v*`).
    - **Suite 11 en `tests/app.Tests.ps1`**: Implementada nueva suite automatizada con 4 aserciones que verifican la integridad de packaging de Inno Setup (45/45 aserciones pasando).
    - **Publicación Exitosa de v1.4.0**: Binario oficial `AI-Prompt-Clipboard-Setup.exe` (2.07 MB) compilado y publicado automáticamente en GitHub Releases.

---

## 🔬 Forensic Audit Findings - Remediated (2026-09-13 Session 2)
- [x] [HIGH] [CI/CD] `installer.iss`: Empaquetado de archivo no versionado (`metrics.json`) provocaba fallo de compilación en GitHub Actions (`Exit code 1`) al no existir en checkout limpio.
- [x] [HIGH] [SECURITY] `app.ps1` (`Update-FromGitHubHttp`) & `setup.ps1`: Enforced in-memory pre-extraction Zip-Slip traversal validation on all archive entries using ZipFile::OpenRead prior to disk extraction.
- [x] [HIGH] [BUG] `app.ps1` (`Save-CurrentPromptEditor`, `Delete-CurrentPromptEditor`, `Switch-Workspace`): Unified variable scoping to `$script:prompts` across all mutation and serialization points, ensuring added/deleted prompts reliably persist to disk and workspace packs update cleanly.
- [x] [HIGH] [BUG] `app.ps1` (Window Lifecycle & Alt+F4): Registered `$window.Add_Closing` handler to intercept Alt+F4 and OS close commands, safely redirecting to `Hide-MainWindow` and preserving the resident WPF window HWND.
- [x] [HIGH] [BUG] `installer.iss` vs `setup.ps1`: Unified Inno Setup install destination to `{localappdata}\Programs\AI-Dev-Prompt-Clipboard`, perfectly aligning with `setup.ps1` and eliminating dual parallel installations.
- [x] [MEDIUM] [QA] `tests/app.Tests.ps1`: Upgraded test suite to dynamically extract and execute production functions (`Get-TemplateTokens`, `Get-SmartSuggestion`, `Get-NextPhasePrompt`) directly from `app.ps1` AST in isolation, eliminating duplicate mock implementations.
- [x] [MEDIUM] [QA] `tests/app.Tests.ps1` (Business Rules Divergence): Synchronized sequence stepper assertions with canonical production DEV FLUX rules (`outro -> feature_plan`, `rdi -> product_strategy -> business_strategy -> feature_plan`) and aligned TDD discipline ratio calculation (30%).
- [x] [MEDIUM] [BUG] `app.ps1` (`Check-ForUpdatesAsync`): Initialized `$script:scriptFile` and `$script:startupScriptWriteTime` at process startup, enabling accurate local disk file modification detection.
- [x] [MEDIUM] [BUG] `setup.ps1`: Added proactive process termination of running background instances, safe file copy with `.old` swap fallback, and smart non-destructive config schema merging.
- [x] [MEDIUM] [BUG] `.github/workflows/build-installer.yml`: Replaced hardcoded x86 ISCC path with dynamic detection across Inno Setup 6/7, 32-bit/64-bit, chocolatey bin, and system PATH.
- [x] [MEDIUM] [TECH-DEBT] `app.ps1` (`btnExportMetrics`): Extracted shared `Set-SafeClipboardText` helper with retry-backoff loop across `Copy-PromptToClipboard` and metrics export, eliminating `CLIPBRD_E_CANT_OPEN` failures.
- [x] [LOW] [CLEANUP] `GRAPH_REPORT.md` (AST Extraction Metadata): Verified and documented `setup.ps1` and `install-shortcut.ps1` as standalone CLI/Web entrypoints in knowledge graph and project documentation.

---

## 🔬 Historical Forensic Audit Findings - Remediated (2026-09-13 Session 1)
- [x] [HIGH] [SECURITY] `app.ps1` (`Update-FromGitHubHttp`): Missing cryptographic checksum (SHA-256) validation on downloaded update archive from GitHub HTTP endpoint prior to extraction and execution.
- [x] [HIGH] [SECURITY] `launch.vbs` (`WshShell.Run`): Insufficient argument sanitization and quote escaping in VBS wrapper allows potential parameter injection into hidden `powershell.exe` execution.
- [x] [HIGH] [BUG] `app.ps1` (`Update-FromGitHubHttp`): In-place recursive copy of running script files (`app.ps1`) causes `IOException` due to Windows file-locking, leading to failed updates and inconsistent disk state.
- [x] [HIGH] [BUG] `app.ps1` (`Restore-MergedUserConfig`): Fallback catch handler writes `$configBackupJson` without null-check; if null or unreadable, it overwrites `config.json` with empty content.
- [x] [MEDIUM] [QA] `Repository Root` (Test Automation): Zero unit or integration tests (0% automated test coverage); core state machines, templating engines, and update parsers have no automated test suite.
- [x] [MEDIUM] [BUG] `app.ps1` (`BtnOpenFolder` & Tray `menuEdit`): Hardcoded launch path `notepad.exe "$promptsFile"` ignores active workspace pack (`$script:activePromptsPath`), always opening default prompts.
- [x] [MEDIUM] [TECH-DEBT] `app.ps1` (`Check-ForUpdates`): God-node with 10 outgoing dependencies coupling Git CLI execution, HTTP endpoints, WPF UI message boxes, and process restart logic into a single monolithic function.
- [x] [MEDIUM] [TECH-DEBT] `app.ps1` (Error Handling Hygiene): 42 bare `catch {}` blocks suppress critical I/O, network, and parser errors, preventing diagnostic telemetry and user feedback.
- [x] [LOW] [CLEANUP] `app.ps1` (`PromptCountBadge`): Initial XAML defines hardcoded `"10 protocolos"` badge, causing count mismatch with the 11 loaded protocols prior to dynamic filter refresh.
- [x] [LOW] [CLEANUP] `app.ps1` (`NativeClipboardHelper` & HwndSource Hook): Omission of `$source.RemoveHook($script:clipHook)` and `$source.Dispose()` in window closing sequence.
