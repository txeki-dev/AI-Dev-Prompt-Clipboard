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
3. **Repository & Version Control**:
   - Git repository tracking `main` synchronized with remote origin `https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard.git`.

---

## 📅 Weekly Summary (Week ending 2026-09-12)
- Initial release of AI Dev Prompt Clipboard with 8 core AI protocols.
- Established persistent AI memory architecture with Graphify, `diary.md` and Git automation.
- Forensic Audit Findings #1 and #2 remediated and verified.
- Added Windows Startup auto-start, System Tray resident icon, custom AppUserModelID, and GitHub auto-updater engine ported from Ekin.

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

Files changed: `app.ps1`, `install-shortcut.ps1`, `launch.vbs`, `README.md`, `diary.md`.

---

## 🔬 Forensic Audit Findings - 2026-09-09 (Principal Security & Performance Auditor)

### 🔴 HIGH — Bugs / Robustness
1. ✅ **[DONE 2026-09-09] Clipboard lock contention (COMException CLIPBRD_E_CANT_OPEN) can fail copy operations on Windows** —
   Resolved with 5-attempt retry loop, 40ms backoff, and `SetDataObject($textToCopy, $true)`.

### 🟡 MEDIUM — Robustness / Edge cases
2. ✅ **[DONE 2026-09-10] Path quoting in editor launch and icon specifier syntax in shortcut installer** —
   Resolved with `-ArgumentList` quoting in `app.ps1` and sanitized `$iconLocation` in `install-shortcut.ps1`.

### 🟢 LOW — UX / Optimization
3. ✅ **[DONE 2026-09-10] Redundant timer garbage collection overhead on rapid multiple card clicks** —
   Eliminated transient card background revert timers and button reset timers in `Copy-PromptToClipboard`, relying solely on the single shared status bar reset timer and active state tracking.

---

## 📋 Active / Pending Tasks
- **Active Task**:
  - Ninguna en curso (todas las peticiones del usuario y remediaciones concluidas).
- **Pending Tasks**:
  - Push changes to remote `https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard.git`.

---

## 🎯 Next Immediate Step
- Push release v1.2.0 with persistent clipboard indicator to GitHub origin/main.
