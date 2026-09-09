# AI Dev Prompt Clipboard 📋

Una interfaz gráfica ligera, rápida y moderna para Windows diseñada para copiar al portapapeles tus protocolos y prompts de desarrollo asistido con IA con un solo clic o mediante un atajo global de teclado.

---

## 🚀 Acceso Rápido y Atajo de Windows

La aplicación se encuentra instalada con los siguientes métodos de acceso:

1. **Atajo Global de Teclado**: Presiona **`Ctrl + Alt + P`** en cualquier momento y desde cualquier aplicación de Windows para abrir la paleta al instante.
2. **Acceso directo en el Escritorio**: Doble clic en el icono **`AI Prompt Clipboard`** en tu Escritorio.
3. **Menú Inicio**: Presiona la tecla **`Win`** y busca `"AI Prompt Clipboard"`.

---

## ⚡ Prompts y Protocolos Incluidos (8 Protocolos)

| # | Protocolo | Tag / Protocolo | Rol | Propósito |
|---|---|---|---|---|
| 1 | **INTRO** | `<session_start_hybrid>` | AI Pair Programmer | Ingesta de `GRAPH_REPORT.md` y `diary.md` para arrancar sesión |
| 2 | **FEATURE PLAN** | `<feature_plan_tdd>` | Principal Architect & SDET | Descomposición de backlog en `diary.md` y creación de tests fallidos (Fase Roja) |
| 3 | **FEATURE BUILD** | `<feature_build_tdd>` | TDD Implementation Engineer | Implementación de código mínimo para pasar tests (Fase Verde) y refactor |
| 4 | **OUTRO** | `<session_end_hybrid>` | Consolidación & Git | Cierre de sprint en `diary.md`, archivo semanal, actualización de README y git push |
| 5 | **INITIAL** | `<initial_setup_hybrid>` | Principal Software Architect | Inicialización de memoria persistente con Graphify, build graph y markdown inicial |
| 6 | **MIGRATE** | `<migrate_to_hybrid>` | Principal Software Architect | Migración de base de código de `context.md` estático a Graphify híbrido |
| 7 | **AUDITORY** | `<codebase_audit_hybrid>` | Security & Performance Auditor | Auditoría forense de arquitectura, código muerto, bugs y deuda técnica |
| 8 | **REMEDIATE** | `<remediate_audit_hybrid>` | Remediation Specialist | Resolución sistemática y aislada de los hallazgos de la auditoría uno a uno |

---

## 🎨 Características de la Interfaz

- **Copia instantánea**: Haz clic en cualquier tarjeta o en su botón `📋 Copiar`. Recibirás una respuesta visual en verde (`✓ ¡Copiado!`) y el texto se enviará al portapapeles.
- **Vista Previa (`👁️`)**: Visualiza el texto íntegro en fuente monoespaciada antes de copiarlo.
- **Buscador en tiempo real**: Encuentra rápidamente cualquier protocolo tecleando palabras como `"tdd"`, `"audit"`, `"intro"`, etc.
- **Filtros por Categoría**: Botones de acceso directo para `Workflow`, `TDD`, `Setup` y `Auditoría`.
- **Fijar ventana (`📌 Always on Top`)**: Mantenla flotando sobre tu editor de código o chat de IA sin que se oculte al hacer clic en otra ventana.
- **Opciones persistentes** (guardadas en `config.json`):
  - `Cerrar al copiar`: Si está marcado, la ventana se minimiza/cierra automáticamente 300ms tras copiar.
  - `Cabecera [ TITULO ]`: Permite decidir si copiar únicamente el cuerpo del protocolo (`Execute the ...`) o incluir la cabecera (ej: `[ INTRO ]`).
- **Personalización sencilla (`⚙️`)**: Haz clic en el engranaje para abrir `prompts.json` en el Bloc de Notas y agregar o modificar tus propios prompts.

---

## 🛠️ Estructura del Proyecto

- `app.ps1`: Aplicación principal desarrollada con PowerShell nativo y WPF (Windows Presentation Foundation).
- `launch.vbs`: Lanzador silencioso que evita cualquier parpadeo de consola negra de PowerShell.
- `prompts.json`: Base de datos editable con todos los prompts, roles, tags y categorías.
- `config.json`: Almacena las preferencias del usuario (modo siempre visible, cerrar al copiar, etc.).
- `install-shortcut.ps1`: Script automatizado para registrar o reinstalar los accesos directos y atajos globales.
- `icon.ico`: Icono de alta resolución personalizado para la aplicación.

---

## 🔄 Reinstalación o Cambio de Atajo

Si deseas cambiar la combinación de teclas o reinstalar el acceso directo:
Abre PowerShell en este directorio y ejecuta:
```powershell
.\install-shortcut.ps1 -Hotkey "CTRL+ALT+P"
```
*(Puedes reemplazar `"CTRL+ALT+P"` por la combinación que prefieras, como `"CTRL+ALT+I"` o `"CTRL+SHIFT+P"`)*.
