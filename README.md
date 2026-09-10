# AI Dev Prompt Clipboard 📋

[![License](https://img.shields.io/badge/license-PolyForm--Noncommercial-lightgrey)](LICENSE)

Una interfaz gráfica ligera, rápida y moderna para Windows diseñada para copiar al portapapeles tus protocolos y prompts de desarrollo asistido con IA con un solo clic o mediante un atajo global de teclado.

---

## 🚀 Acceso Rápido y Métodos de Inicio

La aplicación cuenta con integración nativa en Windows:

1. **Inicio Automático con Windows (Startup)**: Al instalarse, se añade a la carpeta de Inicio de Windows (`Startup`) para ejecutarse en segundo plano discretamente al encender el PC.
2. **Bandeja del Sistema ("Mostrar iconos ocultos")**: Icono residente en la bandeja junto al reloj de Windows con menú contextual (clic derecho para abrir, buscar actualizaciones o salir).
3. **Atajo Global de Teclado**: Presiona **`Ctrl + Alt + P`** en cualquier momento y desde cualquier aplicación de Windows para abrir la paleta instantáneamente sin latencia.
4. **Acceso directo en el Escritorio y Menú Inicio**: Doble clic en el icono **`AI Prompt Clipboard`** en tu Escritorio o búscalo en el Menú Inicio pulsando la tecla `Win`.

---

## 🔄 Auto-Actualizaciones desde GitHub (Motor Ekin)

La aplicación cuenta con el mismo motor de actualización automática y seguro de [Ekin](https://github.com/txeki-dev/Ekin):
- **Comprobación asíncrona en segundo plano**: Al arrancar y al restaurar la ventana, comprueba de forma no bloqueante si hay nuevas versiones en GitHub mediante fontanería nativa de Git agnóstica al idioma (`git rev-list`), sin congelar la interfaz.
- **Comprobación manual**: Botón `🔄` en la barra de título o clic derecho en el icono de la bandeja -> *Buscar actualizaciones...*.
- **Protección contra pérdida de datos**: Valida que no existan cambios locales sin confirmar en el código antes de descargar nada (`git pull --ff-only`), preservando intacta la configuración del usuario (`config.json`). Si hay una nueva versión disponible, te solicitará confirmación antes de instalarla y se reiniciará sola.

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
| 7 | **AUDITORY** | `<codebase_audit_hybrid>` | Principal Security & Performance Auditor | Auditoría forense de arquitectura, código muerto, bugs y generación de backlog accionable |
| 8 | **REMEDIATE** | `<remediate_all_audit_findings>` | Principal Staff Engineer & Remediation Specialist | Resolución sistemática en cola de todos los hallazgos de auditoría (HIGH -> LOW) sin regresiones |

---

## 🎨 Características de la Interfaz

- **Icono Propio de Aplicación**: Mediante `AppUserModelID`, Windows reconoce la aplicación como un proceso independiente en la barra de tareas y bandeja, mostrando su icono exclusivo en lugar del terminal de PowerShell.
- **Instancia Única con Activación IPC**: Solo se ejecuta un proceso en segundo plano (vía `Mutex` y `EventWaitHandle`). Pulsar `Ctrl + Alt + P` o abrir el acceso directo despierta la ventana residente al instante con 0ms de retardo.
- **Indicador de Prompt Activo en el Portapapeles**: Resalta automáticamente con borde verde esmeralda y la insignia `📋 En portapapeles` cuál de los protocolos reside actualmente en el portapapeles de Windows, sincronizado en tiempo real.
- **Copia instantánea protegida**: Algoritmo con reintentos contra bloqueos transitorios del portapapeles de Windows (`CLIPBRD_E_CANT_OPEN`) y feedback en la barra inferior en verde (`✓ ¡Copiado al portapapeles!`).
- **Vista Previa (`👁️`)**: Visualiza el texto íntegro en fuente monoespaciada antes de copiarlo.
- **Buscador y Filtros por Categoría**: Filtra por `Workflow`, `TDD`, `Setup` y `Auditoría` o busca palabras clave.
- **Fijar ventana (`📌 Always on Top`)**: Mantenla flotando sobre tu editor de código o chat de IA.
- **Opciones persistentes** (guardadas en `config.json`):
  - `Ocultar al copiar`: Si está marcado, la ventana se oculta a la bandeja tras copiar un prompt.
  - `Cabecera [ TITULO ]`: Permite decidir si copiar únicamente el cuerpo del protocolo (`Execute the ...`) o incluir la cabecera.
- **Personalización sencilla (`⚙️`)**: Haz clic en el engranaje para abrir `prompts.json` en el Bloc de Notas.

---

## 🛠️ Estructura del Proyecto

- `app.ps1`: Aplicación principal desarrollada con PowerShell nativo, WPF, WinForms NotifyIcon y motor de actualización Git.
- `launch.vbs`: Lanzador silencioso que evita cualquier parpadeo de consola negra de PowerShell (con auto-reparación integrada).
- `launch.bat`: Lanzador ejecutable directo para iniciar la aplicación con doble clic desde el Explorador de Windows.
- `install.bat`: Instalador en 1 solo clic que registra automáticamente los accesos directos sin necesidad de abrir PowerShell.
- `install-shortcut.ps1`: Script automatizado y auto-reparador para registrar los accesos directos (Escritorio, Menú Inicio y Startup).
- `prompts.json`: Base de datos editable con todos los prompts, roles, tags y categorías.
- `config.json`: Almacena las preferencias del usuario (modo siempre visible, cerrar al copiar, etc.).
- `icon.ico`: Icono de alta resolución personalizado para la aplicación.

---

## 💻 Instalación y Configuración de Atajo

### Opción 1: Doble clic (Recomendado)
Haz doble clic en **`install.bat`** en la carpeta del repositorio.

### Opción 2: PowerShell (Personalizando atajo)
```powershell
.\install-shortcut.ps1 -Hotkey "CTRL+ALT+P"
```

---

## 📄 Licencia

Este proyecto está bajo la licencia **[PolyForm Noncommercial License 1.0.0](LICENSE)**. Permite el uso personal, estudio y modificación sin fines comerciales. Para consultas sobre usos comerciales, ponte en contacto con Txek Systems.

