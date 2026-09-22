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

## 🔄 Auto-Actualizaciones Dual-Mode desde GitHub (Git + Fallback HTTP)

La aplicación cuenta con un motor de actualización automática híbrido y seguro:
- **Modo Git Nativo (`git clone`)**: Si el equipo cuenta con Git, comprueba y descarga actualizaciones silenciosas y atómicas (`git pull --ff-only`), validando que no existan cambios locales sin confirmar y preservando intacta la configuración del usuario (`config.json`).
- **Modo Standalone Universal (Sin Git / ZIP)**: Si el equipo **no tiene Git instalado** o se copió la aplicación directamente como carpeta/ZIP, se conecta directamente a la API pública de GitHub y descarga el archivo comprimido oficial mediante HTTPS nativo de Windows (`Invoke-RestMethod` / `Expand-Archive`), extrayendo la nueva versión, preservando tus ajustes y reiniciando la aplicación en 1 clic.
- **Comprobación asíncrona en segundo plano**: Tanto en modo Git como en modo HTTP, comprueba en segundo plano sin bloquear ni congelar la interfaz.
- **Comprobación manual**: Botón `🔄` en la barra de título o clic derecho en el icono de la bandeja -> *Buscar actualizaciones...*.

---

## ⚡ Prompts y Protocolos Incluidos (11 Protocolos)

| # | Protocolo | Tag / Protocolo | Rol | Propósito |
|---|---|---|---|---|
| 1 | **INITIAL** | `<initial_setup_hybrid>` | Principal Software Architect | Inicialización de memoria persistente con Graphify, build graph, hook y markdown inicial |
| 2 | **MIGRATE** | `<migrate_to_hybrid>` | Principal Software Architect | Migración de base de código de `context.md` estático a Graphify híbrido con backlog desacoplado |
| 3 | **INTRO** | `<session_start_hybrid>` | AI Pair Programmer | Ingesta de `GRAPH_REPORT.md` y `diary.md` para arrancar sesión |
| 4 | **RDi** | `<rdi_exploration_protocol>` | Principal Research Architect & Innovation Lead | Exploración proactiva de I+D (R&D) sobre el AST de Graphify para proponer iniciativas técnicas de alto impacto |
| 5 | **FEATURE PLAN** | `<feature_plan_tdd>` | Principal Architect, Product Triager & SDET | Descomposición de backlog en `backlog.md`/`diary.md` y creación de tests fallidos (Fase Roja) con Claude Code |
| 6 | **FEATURE BUILD** | `<feature_build_tdd>` | TDD Implementation Engineer | Implementación de código mínimo para pasar tests (Fase Verde) y refactor con Antigravity CLI |
| 7 | **AUDIT** | `<codebase_audit_hybrid>` | Principal Cybersecurity Auditor, Lead QA Engineer & Code Architect | Auditoría forense exhaustiva de ciberseguridad, cobertura QA y calidad de código con AST de Graphify |
| 8 | **REMEDIATE** | `<remediate_all_audit_findings>` | Principal Staff Engineer & Remediation Specialist | Resolución sistemática en cola de todos los hallazgos de auditoría (HIGH -> LOW) sin regresiones |
| 9 | **OUTRO** | `<session_end_hybrid>` | Consolidación & Git | QA gate de tests, consolidación de `diary.md`, archivo semanal, actualización de README y git push |
| 10 | **PRODUCT STRATEGY** | `<product_strategy_discovery>` | Chief Product Officer (CPO), Lead UX Strategist & SaaS Business Architect | Análisis proactivo de UX, flujos de usuario y capacidades de negocio viables para el backlog |
| 11 | **BUSINESS STRATEGY** | `<business_strategy_advisory>` | SaaS/B2B Tech Founder, Venture Strategist & Commercial Operations Advisor | Consultoría estratégica de negocio, monetización SaaS/B2B, licencias IP, GTM y marco operativo/fiscal |

---

## 🗺️ Pestaña DEV FLUX (Metodología de Desarrollo Híbrido)

La aplicación incorpora una pestaña dedicada **⚡ DEV FLUX** que visualiza el ciclo de vida completo de ingeniería entre herramientas de IA (Claude Code y Google Antigravity CLI):

```text
[ INICIO DEL PROYECTO ]
                     1. INITIAL (Nuevo)  /  2. MIGRATE (Legacy)
                     (Claude: Crea Grafo AST + 5 archivos de memoria)
                                       │
                                       ▼
                       ┌───────────────────────────────┐
                       │           3. INTRO            │
                       │ (Lectura silenciosa de estado)│
                       └───────────────┬───────────────┘
                                       │
       ┌───────────────────────────────┼───────────────────────────────┐
       ▼                               ▼                               ▼
[ INNOVACIÓN TÉCNICA ]      [ ESTRATEGIA DE PRODUCTO ]     [ NEGOCIO & LICENCIAS ]
       4. RDi                   10. PRODUCT_STRATEGY        11. BUSINESS_STRATEGY
(CTO: Perf / Concurrencia)     (CPO: UX / Capabilities)     (CEO: Monetización / GTM)
       │                               │                               │
       │                               │                   ┌───────────┴───────────┐
       │                               │                   ▼                       ▼
       │                               │             [ BUSINESS.md ]               │
       │                               │             (Modelo & Pricing)            │
       └───────────────────────┬───────┴───────────────────────────────────────────┘
                               ▼
                        [ backlog.md ] ◄────────────────── [ 7. AUDIT ]
                 (Cola de Tareas Priorizadas)          (Diagnóstico Read-Only)
                               │                                   │
                               ▼                                   ▼
                 [ 5. FEATURE_PLAN (TDD Red) ]             [ 8. REMEDIATE ]
                  (Claude: Diseña & Rompe Tests)          (Cirugía en Cascada)
                               │                                   │
                     (Relevo en Filesystem)                        │
                               ▼                                   │
                 [ 6. FEATURE_BUILD (TDD Green) ]                  │
                  (Gemini: Pica código & Pone Verde)               │
                               │                                   │
                               └─────────────────┬─────────────────┘
                                                 ▼
                                  ┌───────────────────────────────┐
                                  │           9. OUTRO            │
                                  │    - QA Gate (Tests 100%)     │
                                  │    - Archivo de tareas        │
                                  │    - git commit & push        │
                                  │    - Hook actualiza Graphify  │
                                  └───────────────────────────────┘
```

- **Diagrama de Flujo Oficial en 5 Fases**: Mapeo visual monoespaciado integral desde el inicio (`INITIAL` / `MIGRATE`), sesión (`INTRO`), bifurcación estratégica (`RDi`, `PRODUCT_STRATEGY`, `BUSINESS_STRATEGY`), auditoría y TDD (`AUDIT`, `REMEDIATE`, `FEATURE_PLAN`, `FEATURE_BUILD`) hasta la consolidación (`OUTRO`).
- **Accesos Rápidos Interactivos por Fase**: Botones dedicados para las 5 fases. Un clic izquierdo copia el protocolo al portapapeles (con QuickFill si tiene variables); un clic derecho salta directamente a la pestaña `📋 Protocolos` filtrando la categoría correspondiente.
- **Vínculo Directo al Catálogo**: Botón `📋 Ver Catálogo Completo` para navegar fluidamente entre el mapa de flujo y la lista completa de prompts.

---

## 🎨 Características de la Interfaz

- **Sistema de Triple Pestaña**: Alterna fluidamente entre `📋 Protocolos` (catálogo y tarjetas), `⚡ DEV FLUX` (mapa de arquitectura de trabajo) y `📊 Métricas` (panel de productividad local). Atajo de teclado: **`Ctrl + Tab`** para alternar pestañas y **`Shift + Tab`** para ciclar dinámicamente entre categorías de protocolos.
- **Editor Visual Integrado (`+ Nuevo` / `✏️`)**: Crea, edita y elimina protocolos en caliente desde la propia interfaz con soporte de variables `{{variables}}`, color hexadecimal y recarga en memoria instantánea sin reiniciar.
- **Motor de Workspaces & Packs Modulares (`packs/`)**: Selector de perfiles de trabajo (`Core Engineering`, `Frontend UI`, `Security & DevOps`) con importación (`📥`) y exportación (`📤`) de packs JSON para compartir entre equipos.
- **Panel de Métricas y Telemetría (`📊 Métricas`)**: Indicadores KPI en tiempo real (total invocaciones, ciclos TDD, ratio de disciplina, protocolo #1, distribución por categoría e historial) y botón `📋 Copiar Resumen Markdown` para standups y reportes de sesión.
- **DEV FLUX Smart Sequence Stepper**: Píldora interactiva en la barra inferior y atajo de teclado **`Ctrl + Alt + N`** para avanzar automáticamente a la siguiente fase del ciclo recomendada (`initial -> intro -> feature_plan -> feature_build -> audit -> remediate -> outro`).
- **Icono Propio de Aplicación**: Mediante `AppUserModelID`, Windows reconoce la aplicación como un proceso independiente en la barra de tareas y bandeja, mostrando su icono exclusivo en lugar del terminal de PowerShell.
- **Instancia Única con Activación IPC**: Solo se ejecuta un proceso en segundo plano (vía `Mutex` y `EventWaitHandle`). Pulsar `Ctrl + Alt + P` o abrir el acceso directo despierta la ventana residente al instante con 0ms de retardo.
- **Indicador de Prompt Activo en el Portapapeles**: Resalta automáticamente con borde verde esmeralda y la insignia `📋 En portapapeles` cuál de los protocolos reside actualmente en el portapapeles de Windows, sincronizado en tiempo real.
- **Copia instantánea protegida**: Algoritmo con reintentos contra bloqueos transitorios del portapapeles de Windows (`CLIPBRD_E_CANT_OPEN`) y feedback en la barra inferior en verde (`✓ ¡Copiado al portapapeles!`).
- **Vista Previa (`👁️`)**: Visualiza el texto íntegro en fuente monoespaciada antes de copiarlo.
- **Buscador y Filtros Dinámicos por Categoría**: Píldoras interactivas con conteo en tiempo real (`Todos (11)`, `Workflow (2)`, `TDD (2)`, `Setup (2)`, `Auditoría (2)`, `R&D (1)`, `Estrategia (2)`). Navega rápidamente entre ellas con **`Shift + Tab`** en la pestaña de Protocolos.
- **Fijar ventana (`📌 Always on Top`)**: Mantenla flotando sobre tu editor de código o chat de IA.
- **Opciones persistentes** (guardadas en `config.json`):
  - `Ocultar al copiar`: Si está marcado, la ventana se oculta a la bandeja tras copiar un prompt.
  - `Cabecera [ TITULO ]`: Permite decidir si copiar únicamente el cuerpo del protocolo (`Execute the ...`) o incluir la cabecera.
- **Personalización sencilla (`⚙️`)**: Haz clic en el engranaje para abrir el archivo JSON en el Bloc de Notas.

---

## 🛠️ Estructura del Proyecto

- `app.ps1`: Aplicación principal desarrollada con PowerShell nativo, WPF, WinForms NotifyIcon, motor de packs y auto-updater Git/HTTP.
- `packs/`: Directorio de packs modulares preconfigurados (`core-engineering.json`, `frontend-ui.json`, `security-devops.json`).
- `dev_flux.png`: Diagrama visual oficial de la metodología de desarrollo híbrido.
- `setup.ps1`: Instalador web automatizado de 1 línea para instalar en AppData sin necesidad de Git ni descompresión manual.
- `installer.iss`: Script de Inno Setup para compilar el instalador ejecutable de Windows (`AI-Prompt-Clipboard-Setup.exe`).
- `tests/`: Suite de pruebas unitarias automatizadas (`app.Tests.ps1`) y lanzador en 1 clic (`run-tests.bat`).
- `launch.bat`: Lanzador ejecutable directo para iniciar la aplicación con doble clic desde el Explorador de Windows (Zero-VBS).
- `install.bat`: Instalador en 1 solo clic que registra automáticamente los accesos directos sin necesidad de abrir PowerShell.
- `install-shortcut.ps1`: Script automatizado para registrar los accesos directos corporativos (Escritorio, Menú Inicio y Startup).
- `prompts.json`: Base de datos editable con los prompts principales del workspace predeterminado.
- `metrics.json`: Almacén local de telemetría y productividad del desarrollador.
- `config.json`: Almacena las preferencias del usuario (modo siempre visible, cerrar al copiar, pack activo, etc.).
- `version.json`: Control de versión y commit SHA para clientes standalone sin Git.
- `icon.ico`: Icono de alta resolución personalizado para la aplicación.

---

## 💻 Instalación y Configuración de Atajo

Dispones de varias formas sencillas de instalar y configurar la aplicación según tu perfil:

### 🌟 Método 1: Instalador Automático de 1 Línea (Recomendado para usuarios no técnicos / Sin Git)
No requiere descargar manualmente archivos ZIP ni tener Git instalado. La aplicación se descarga, configura y se instala automáticamente en `%LOCALAPPDATA%\Programs\AI-Dev-Prompt-Clipboard`:

1. Presiona las teclas **`Windows + R`** para abrir la ventana *Ejecutar*.
2. Pega el siguiente comando y presiona **Enter**:
   ```cmd
   powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/txeki-dev/AI-Dev-Prompt-Clipboard/main/setup.ps1 | iex"
   ```
*(O bien abre una consola PowerShell y ejecuta: `irm https://raw.githubusercontent.com/txeki-dev/AI-Dev-Prompt-Clipboard/main/setup.ps1 | iex`)*

> [!TIP]
> Este instalador descarga la versión más reciente, la extrae en una ubicación protegida de limpiezas accidentales, crea los accesos directos en el **Escritorio** con el atajo global **`Ctrl + Alt + P`**, en el **Menú Inicio**, la configura para **iniciar con Windows** en la bandeja del sistema y la abre de inmediato.

---

### 📦 Método 2: Instalador de Windows `.exe` (Clásico)
Para quienes prefieren el instalador ejecutable de Windows de toda la vida:
1. Ve a la sección de **[Releases](https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard/releases)** del repositorio.
2. Descarga **`AI-Prompt-Clipboard-Setup.exe`**.
3. Haz doble clic y sigue el asistente gráfico (*Siguiente ➔ Instalar ➔ Finalizar*).
- *Incluye desinstalador limpio en "Configuración ➔ Aplicaciones instaladas" de Windows y no requiere permisos de Administrador.*
- *Puedes compilar este instalador localmente en cualquier momento usando Inno Setup y el archivo [`installer.iss`](installer.iss).*

---

### 📂 Método 3: Descarga en ZIP (Manual en 1 clic)
1. Descarga el archivo comprimido oficial: **[Descargar ZIP](https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard/archive/refs/heads/main.zip)**.
2. Haz clic derecho sobre el archivo ZIP descargado y selecciona **"Extraer todo..."**.
3. Entra en la carpeta extraída y haz doble clic sobre **`install.bat`**.

---

### 👨‍💻 Método 4: Para Desarrolladores (Git Clone)
Si eres desarrollador y cuentas con Git en tu sistema:
```bash
git clone https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard.git
cd AI-Dev-Prompt-Clipboard
.\install-shortcut.ps1 -Hotkey "CTRL+ALT+P"
```
*(Puedes personalizar el atajo global pasando cualquier combinación como `-Hotkey "CTRL+ALT+A"` o `-Hotkey "CTRL+SHIFT+P"`)*.

---

## 📄 Licencia

Este proyecto está bajo la licencia **[PolyForm Noncommercial License 1.0.0](LICENSE)**. Permite el uso personal, estudio y modificación sin fines comerciales. Para consultas sobre usos comerciales, ponte en contacto con Txek Systems.
