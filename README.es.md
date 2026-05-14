[English version](README.md)

# KeepAwake

> App de menubar open-source para macOS que evita que el Mac entre en suspensión por inactividad en Apple Silicon, con activación opcional según Wi-Fi (SSID). Una alternativa liviana, con licencia MIT, a Amphetamine, Caffeine, KeepingYouAwake, Theine, Lungo y el comando `caffeinate`.

![CI](https://img.shields.io/badge/CI-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![macOS](https://img.shields.io/badge/macOS-14%2B-lightgrey)
![Arch](https://img.shields.io/badge/arch-Apple%20Silicon-black)

![menubar](docs/screenshot.png)

## ¿Qué es KeepAwake?

**KeepAwake** es una pequeña utilidad de menubar en Swift + AppKit para macOS que evita que tu MacBook Pro, MacBook Air, Mac mini o Mac Studio entren en suspensión por inactividad. Está escrita para Apple Silicon (M1, M2, M3, M4) y soporta macOS Sonoma (14), macOS Sequoia (15) y macOS 16+. Usa la API oficial `IOPMAssertion` de Apple — la misma primitiva que está detrás del comando integrado `caffeinate` — envuelta en un ícono de menubar con un solo click. Su característica diferenciadora es la **activación por Wi-Fi**: KeepAwake se puede configurar para mantener el Mac despierto solo cuando está conectado a una red Wi-Fi específica (SSID), como tu hotspot del iPhone, tu red de la casa, o un dispositivo Android compartiendo datos. Es open source bajo licencia MIT, tiene cero dependencias de terceros, sin telemetría, sin llamadas de red, sin cuenta, y pesa aproximadamente 20 MB de RAM con 0% de CPU en reposo.

Si estás buscando "cómo mantener mi Mac despierto en batería", "caffeinate con activación por Wi-Fi", "app de menubar para evitar que el Mac se duerma en MacBook", "alternativa open source a Amphetamine", o "mantener MacBook despierto mientras corre Claude Code durante la noche" — KeepAwake está hecho exactamente para esos casos de uso.

## Casos de uso

### Correr Claude Code o agentes de IA de programación durante la noche
Los agentes basados en LLM de larga duración (Claude Code, agentes en background de Cursor, Aider, OpenDevin, Continue.dev) necesitan que el Mac se mantenga despierto mientras iteran. KeepAwake mantiene una assertion de inactividad durante toda la sesión.

### Builds largas de Xcode, SwiftPM, Bazel o CI
Los ciclos de compilación de proyectos grandes de iOS/macOS o monorepos pueden durar 30+ minutos. Evita que la pantalla se bloquee y que el sistema se duerma a mitad de la build.

### Descargas grandes y transferencias de datasets / pesos de modelos
Bajar un modelo de 70B desde Hugging Face, sincronizar un dataset a un volumen local, o descargar betas de Xcode. Combina la activación por Wi-Fi con tu red de la casa para que se pause automáticamente si te vas.

### Llamadas de Zoom, Google Meet, FaceTime y Microsoft Teams
Algunas apps de videoconferencia no evitan de forma confiable la suspensión por inactividad en macOS. KeepAwake garantiza que el sistema se mantenga despierto durante la llamada.

### Inferencia local de LLM y entrenamiento de ML
Correr Ollama, LM Studio, llama.cpp, MLX, PyTorch, o hacer fine-tuning sobre GPUs de Apple Silicon — mantén la máquina arriba mientras corre un job.

### Reproducción de música, podcasts o radio
Audio continuo por AirPlay o Bluetooth sin que el sistema se duerma.

### Cualquier cosa que quieras correr solo en una red conocida
Backups, jobs de sincronización, o tareas de trabajo que solo deberían avanzar en un SSID de confianza (por ejemplo, tu hotspot, nunca en el Wi-Fi de una cafetería).

---

> ## Limitación importante — léelo antes de instalar
>
> **KeepAwake NO mantiene tu Mac despierto con la tapa cerrada en batería.**
>
> En Apple Silicon, la suspensión con tapa cerrada en batería está forzada por el firmware, debajo del kernel. Ningún software — ni KeepAwake, ni `caffeinate`, ni Amphetamine, ni KeepingYouAwake, ni Theine — puede saltarse esto. KeepAwake solo ayuda en escenarios con **la tapa abierta** (o con la tapa cerrada mientras está enchufado a la corriente con una pantalla externa conectada, el "modo clamshell" que macOS ya soporta).
>
> Si necesitas que corra código mientras tu Mac está cerrado en batería, usa una máquina de desarrollo remota y conéctate por SSH desde tu teléfono.

---

## Características

- Toggle de un click en la menubar (ícono de taza y platillo, se rellena cuando está activo).
- Presets de duración: 15 minutos, 1 hora, 2 horas, 5 horas, indefinido, o "hasta que se cierre la tapa".
- **Activación por SSID de Wi-Fi** opcional: solo mantiene despierto cuando estás conectado a una red elegida, con un periodo de gracia de 60 segundos al cambiar de red.
- Toggle opcional **Mantener pantalla despierta también**: por defecto solo el sistema queda despierto (la pantalla puede dormir, ahorra batería); actívalo si también quieres la pantalla encendida.
- Toggle de Iniciar al Login (vía `SMAppService`).
- Notificación del sistema de auto-apagado cuando termina una sesión con temporizador.
- ~20 MB de RAM, 0% de CPU en reposo. Cero dependencias de terceros.
- Firmado ad-hoc, corre completamente local. **Sin telemetría, sin analytics, sin llamadas de red, sin cuenta.**
- Código fuente: 100% Swift, compilado directo con `swiftc` (no requiere proyecto de Xcode).

## Cómo se compara KeepAwake

El nicho de KeepAwake es **activación por Wi-Fi + open source + chiquito**. Las otras apps en este espacio son excelentes — elige la que mejor se acomode a tus necesidades.

| App | Open source | Activación Wi-Fi (SSID) | Detecta tapa cerrada | Gratis | Sin telemetría | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| **KeepAwake** | Sí (MIT) | **Sí** | Sí | Sí | Sí | Ninguna |
| Amphetamine | No | No | Sí | Sí (App Store) | Poco claro | App Store |
| Caffeine (clásico) | No | No | No | Sí | Poco claro | Ninguna |
| KeepingYouAwake | Sí (MIT) | No | Sí | Sí | Sí | Ninguna |
| Theine | No | No | No | Sí (App Store) | Poco claro | App Store |
| Lungo | No | No | No | De pago | Poco claro | App Store |
| `caffeinate` (CLI) | Incluido con macOS | No | Parcial (`-i`, `-d`, etc.) | Sí | Sí | Ninguna |

Si no necesitas activación por Wi-Fi y solo quieres un bloqueador de suspensión por inactividad gratis y open source, [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) es una gran alternativa. KeepAwake existe específicamente para el flujo de "mantente despierto solo en mi hotspot / Wi-Fi de la casa".

## Instalación

### Opción 1 — Pre-compilado (desde Releases)

1. Descarga `KeepAwake.zip` desde la página de [Releases](../../releases) y descomprímelo.
2. Quita el atributo de cuarentena (la build está firmada ad-hoc, no notarizada):
   ```bash
   xattr -d com.apple.quarantine KeepAwake.app
   ```
3. Muévela a tu carpeta de Aplicaciones:
   ```bash
   mv KeepAwake.app ~/Applications/
   open ~/Applications/KeepAwake.app
   ```

### Opción 2 — Desde el código fuente

```bash
git clone https://github.com/fbahamonde/keepawake.git
cd keepawake
./build.sh
cp -R KeepAwake.app ~/Applications/
open ~/Applications/KeepAwake.app
```

**Requisitos:** macOS 14 (Sonoma) o superior en Apple Silicon (M1 / M2 / M3 / M4), Xcode Command Line Tools (`xcode-select --install`). Los Macs Intel no son soportados.

## Uso

- **Click izquierdo** en el ícono de la menubar para activar/desactivar Keep Awake. Ícono relleno = activo.
- **Click derecho** para abrir el menú.

### Duración

Elige cuánto debería durar la sesión:

- `15 minutos` / `1 hora` / `2 horas` / `5 horas` — se apaga solo cuando expira el temporizador, con una notificación.
- `Indefinidamente` — se mantiene activo hasta que lo apagues.
- `Hasta que se cierre la tapa` — se apaga cuando cierras la tapa.

### Activación por Wi-Fi (el diferenciador)

Opcional. Solo mantiene despierto cuando estás conectado a una red Wi-Fi específica — por ejemplo, el hotspot de tu iPhone, tethering de Android, o el SSID del router de tu casa.

1. Conéctate al Wi-Fi que quieres como objetivo (por ejemplo, el hotspot de tu teléfono).
2. Menú → `Solo en red` → `Fijar Wi-Fi actual como objetivo`.
3. Si cambias de red, KeepAwake te da un periodo de gracia de 60 segundos (el ícono muestra un badge naranjo con una cuenta regresiva). Si no te reconectas, se libera la assertion y el menú muestra `Pausado · esperando <objetivo>`.
4. Al reconectarte al SSID objetivo, se vuelve a tomar la assertion automáticamente.

Sin un objetivo configurado, KeepAwake funciona en todas partes sin chequear la red.

### Estados del ícono

| Ícono | Significado |
| --- | --- |
| Contorno | Apagado |
| Relleno | Activo, red OK (o sin objetivo configurado) |
| Relleno + badge naranjo | Activo, red incorrecta, cuenta regresiva de 60 segundos |
| Contorno + gris | Pausado, esperando volver a la red objetivo |

## FAQ

### ¿KeepAwake funciona con la tapa cerrada en batería?
No. En Macs con Apple Silicon, la suspensión con tapa cerrada en batería está forzada por el firmware, debajo del sistema operativo. Ninguna app puede saltarse esto — ni Amphetamine, ni `caffeinate`, ni KeepAwake. La única forma de mantener un Mac corriendo con la tapa cerrada es el modo clamshell: enchufado a la corriente, con una pantalla externa conectada. Si necesitas correr jobs con la tapa cerrada en batería, usa una máquina remota y conéctate por SSH.

### ¿En qué se diferencia KeepAwake del comando integrado `caffeinate`?
`caffeinate` es una CLI que tienes que acordarte de correr (`caffeinate -di`) y detener. KeepAwake te da un toggle persistente en la menubar, presets de duración, Iniciar al Login y — lo más importante — **activación por SSID de Wi-Fi**, algo que `caffeinate` no ofrece. Por debajo, ambos usan la misma API `IOPMAssertion`.

### ¿En qué se diferencia KeepAwake de Amphetamine?
Amphetamine es una app del App Store pulida y con muchas características. KeepAwake tiene un alcance mucho más chico: hace una sola cosa (evitar la suspensión por inactividad) más la activación por Wi-Fi. KeepAwake es **open source (MIT)**, **sin telemetría**, se distribuye fuera del App Store, y son aproximadamente unas pocas miles de líneas de Swift que puedes leer en una tarde. Elige KeepAwake si quieres auditabilidad y activación por Wi-Fi; elige Amphetamine si quieres automatización por triggers y un set de features más profundo.

### ¿En qué se diferencia KeepAwake de KeepingYouAwake?
KeepingYouAwake es el equivalente más cercano — también open source, también MIT, también solo de menubar. La diferencia principal es la **activación por Wi-Fi**: KeepAwake se va a pausar automáticamente cuando salgas del SSID objetivo y va a reanudar cuando vuelvas. KeepingYouAwake no hace eso.

### ¿Por qué KeepAwake pide permiso de Ubicación?
macOS clasifica el SSID de Wi-Fi como dato sensible — saber el nombre de tu red puede revelar dónde estás. Las apps solo pueden leer el SSID con el permiso "Ubicación al usar la app" concedido. KeepAwake lo usa **solo** para comparar el SSID actual con tu objetivo configurado. Sin el permiso de Ubicación, la funcionalidad básica de Keep Awake igual funciona; solo se deshabilita la activación por Wi-Fi. La app nunca registra tu ubicación y el SSID nunca sale de tu máquina.

### ¿Funciona en Macs Intel?
No. KeepAwake es solo para Apple Silicon (M1, M2, M3, M4). Si hay suficiente interés, agregar una build para Intel es directo — abre un issue.

### ¿Funciona en macOS Ventura / Sonoma / Sequoia?
macOS 14 (Sonoma), macOS 15 (Sequoia) y macOS 16+ son soportados. macOS 13 (Ventura) y anteriores no están testeados.

### ¿KeepAwake mantiene la pantalla encendida también?
Por defecto, no — solo el sistema queda despierto; la pantalla puede dormir (ahorra batería). Activa `Keep display awake too` en el menú si también quieres que la pantalla quede prendida (kiosco, grabación, dashboard). Gasta bastante más batería. Internamente KeepAwake agrega una segunda assertion, `PreventUserIdleDisplaySleep`, junto a la `PreventUserIdleSystemSleep` que siempre está activa.

### ¿Puedo usarlo con Claude Code, Cursor o agentes de IA de programación?
Sí — esta es una de las razones principales por las que existe. Configura una duración (o "Indefinidamente") y KeepAwake va a mantener la assertion de inactividad mientras corre tu agente.

### ¿Lo puedo usar con el hotspot del iPhone o tethering de Android?
Sí. Conéctate al hotspot, después en el menú de KeepAwake elige `Solo en red` → `Fijar Wi-Fi actual como objetivo`. KeepAwake solo va a mantener el Mac despierto en ese SSID específico y se pausa limpiamente cuando salgas.

### ¿Envía datos a alguna parte?
No. KeepAwake hace cero llamadas de red. No hay telemetría, ni analytics, ni chequeo de actualizaciones, ni reportes de crashes, ni cuenta. Todo corre localmente. Puedes verificarlo leyendo el código fuente (`src/`) — son unos pocos archivos de Swift sin imports de networking.

### ¿Está sandboxeado? ¿Está en el App Store?
No. KeepAwake se distribuye como un `.app` firmado ad-hoc fuera del App Store. No está sandboxeado. Es una decisión deliberada — distribuir fuera del App Store significa que no hay cuota anual de developer y no hay ciclo de revisión, lo que mantiene el proyecto gratis y el código fuente sin modificar.

### ¿Cómo desinstalo?
Arrastra `KeepAwake.app` desde `~/Applications` a la Papelera. Opcionalmente, elimina el archivo de preferencias:
```bash
defaults delete com.felipe.keepawake
```

## Arquitectura

KeepAwake es intencionalmente chico. Los bloques principales:

- **`IOPMAssertionCreateWithName`** con tipo `PreventUserIdleSystemSleep` — el mecanismo real de prevención de suspensión por inactividad. Es la misma primitiva que usa `caffeinate` y cualquier otra app de "mantenerse despierto" en macOS.
- **CoreWLAN + CoreLocation** — lee el SSID de Wi-Fi actual para la activación.
- **AppKit** — `NSStatusItem`, el menú, el ícono de la barra de estado. `LSUIElement = true` mantiene a la app fuera del Dock y de `Cmd-Tab`.
- **ServiceManagement** — `SMAppService` para el toggle de Iniciar al Login.
- **UserNotifications** — notificación de "sesión terminada" cuando expira un temporizador.

Sin dependencias de terceros. Compilado directo con `swiftc` (sin proyecto de Xcode), firmado ad-hoc (`codesign -s -`).

Bundle ID: `com.felipe.keepawake`.

## Desarrollo

```bash
swift test       # 38 casos de XCTest
./build.sh       # compila KeepAwake.app
```

Estructura de archivos:

```
src/                Fuentes Swift (AppDelegate, status item, controlador de assertion, monitor de Wi-Fi, ...)
tests/              Target de XCTest (KeepAwakeTests)
Info.plist          Metadata del bundle, LSUIElement, descripción de uso de ubicación
build.sh            swiftc + codesign --force --deep -s -
Package.swift       Manifiesto de SwiftPM, usado solo para `swift test`
SMOKE_TEST.md       Checklist manual antes de declarar una build buena
```

## Contribuir

Esta es una herramienta personal, pero los issues y PRs son bienvenidos. Si encuentras un bug, lo más fácil suele ser un PR enfocado con un test de regresión en `tests/`. Por favor mantén la huella de dependencias en cero.

## Autor

Hecho por **Felipe Bahamonde** — contacto: `bahamondefelipem@gmail.com`. Los issues y pull requests en [GitHub](https://github.com/fbahamonde/keepawake) son el canal preferido.

## Licencia

[MIT](LICENSE) © 2026 Felipe Bahamonde. Herramienta personal, sin garantía.
