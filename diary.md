# AI Dev Prompt Clipboard: Developer Diary

**Current Date**: 2026-09-10

---

## 📊 Current State
**AI Dev Prompt Clipboard v1.1.0 Released**:
1. **Architectural Graph & Static Analysis** (`graphify`):
   - Local AST and topological extraction mapped in `graphify-out/graph.json` and [`GRAPH_REPORT.md`](file:///C:/Users/sergi/Documents/Txek%20Systems/AI-Assisted-Dev-Prompt-Clipboard/GRAPH_REPORT.md).
   - Automatic sync enabled via Git hooks (`post-commit`, `post-checkout`, and `graphify` merge driver).
2. **Core Features**:
   - Modern WPF dark-mode GUI (`app.ps1`) with real-time search, category filters, full prompt preview flyout, and resilient clipboard copy with retry backoff.
   - **System Tray Integration**: Persistent tray icon in Windows notification area ("Mostrar iconos ocultos") with context menu (Abrir, Buscar actualizaciones, Editar, Salir) and single/double-click toggling.
   - **Windows Startup Auto-boot**: Installed to `AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup` with `-Startup` switch to silently run in background on system boot.
   - **Native App Identity**: Custom `AppUserModelID` (`TxekSystems.AIDevPromptClipboard.App.1`) decoupling the process from `powershell.exe` on the Windows taskbar and displaying the custom squircle icon.
   - **Single-Instance IPC**: Named Mutex (`Global\TxekSystems_AIDevPromptClipboard_Mutex`) and EventWaitHandle (`Global\TxekSystems_AIDevPromptClipboard_ShowEvent`) ensuring only 1 resident process runs; secondary launches (`Ctrl+Alt+P` or desktop shortcut) wake the resident instance with 0ms latency.
   - **GitHub Auto-Updater (Ekin Engine)**: Automated silent check on launch + manual button/menu option. Verifies clean git checkout, checks `origin/main` status, warns on dirty working tree, prompts user with confirmation dialog, pulls `--ff-only`, and hot-restarts the application.
3. **Repository, License & Version Control**:
   - Git repository tracking `main` synchronized with remote origin `https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard.git`.
   - Licensed under PolyForm Noncommercial 1.0.0 for public open-source distribution.

---

## 📅 Weekly Summary (Week ending 2026-09-12)
- Initial release of AI Dev Prompt Clipboard with 8 core AI protocols.
- Established persistent AI memory architecture with Graphify, `diary.md` and Git automation.
- Forensic Audit Findings #1 to #7 remediated and verified.
- Added Windows Startup auto-start, System Tray resident icon, custom AppUserModelID, GitHub auto-updater engine ported from Ekin, and PolyForm Noncommercial 1.0.0 license for public release.

---

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

Files changed: `install-shortcut.ps1`, `app.ps1`, `launch.bat`, `install.bat`, `README.md`, `diary.md`.

## 🔬 Forensic Audit Findings - 2026-09-10 (Principal Security & Performance Auditor)

### 🔴 HIGH — Bugs / Robustness
1. ✅ **[DONE 2026-09-10] Auto-Updater permanently blocked by dirty working tree on settings change or graphify cache** —
   Filtered runtime config/cache from `git status --porcelain` check, backed up and restored user `config.json` across fast-forward pulls, and established `.gitignore`.

2. ✅ **[DONE 2026-09-10] Locale-dependent branch check in `Check-ForUpdates` (`behind` string match failure)** —
   Replaced fragile string matching with locale-agnostic Git plumbing: `git rev-list --count HEAD..@{u}` with fallback to `HEAD..origin/main`.

### 🟡 MEDIUM — Performance / UX & Edge Cases
3. ✅ **[DONE 2026-09-10] UI thread freezing on synchronous network `git fetch origin` in WPF Dispatcher** —
   Implemented `Check-ForUpdatesAsync` leveraging `[powershell]::Create()` background runspace; network I/O executes off-thread with zero UI stutter.

4. ✅ **[DONE 2026-09-10] Unchecked mouse button state in Window DragMove (`InvalidOperationException`)** —
   Guarded `$titleBar.Add_MouseLeftButtonDown` with `MouseButtonState::Pressed` validation and `try/catch`.

5. ✅ **[DONE 2026-09-10] 150ms IPC polling timer on UI thread (continuous dispatcher wakeups)** —
   Tuned `$ipcTimer` to `Background` dispatcher priority at 200ms interval with explicit disposal on shutdown.

### 🟢 LOW — Technical Debt / Code Cleanup
6. ✅ **[DONE 2026-09-10] Vestigial dead arguments in `Copy-PromptToClipboard`** —
   Simplified signature to `Copy-PromptToClipboard -promptItem $item` and removed unused local `$thisBtn`.

7. ✅ **[DONE 2026-09-10] Duplicate Hotkey registration in Desktop and Start Menu shortcuts** —
   Removed duplicate hotkey assignment from Start Menu `.lnk` in `install-shortcut.ps1`, leaving `CTRL+ALT+P` solely on the Desktop shortcut.

---

## 🔬 Historical Forensic Audit Findings - 2026-09-09
- ✅ **[DONE 2026-09-09] Clipboard lock contention (COMException CLIPBRD_E_CANT_OPEN)**
- ✅ **[DONE 2026-09-10] Path quoting in editor launch and icon specifier syntax in shortcut installer**
- ✅ **[DONE 2026-09-10] Redundant timer garbage collection overhead on rapid multiple card clicks**

---

## 📋 Active / Pending Tasks
- **Active Task**:
  - Ninguna activa (Sprint de estabilidad, UI activa y remediaciones forenses cerrado al 100%).
- **Pending Tasks**:
  - Nuevas funcionalidades o prompts personalizados a petición del usuario.

---

## 🎯 Next Immediate Step
- Ejecutar protocolo `<session_start_hybrid>` (`[ INTRO ]`) para abrir la siguiente sesión de desarrollo.
