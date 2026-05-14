[English version](README.md)

# KeepAwake

App de menubar para macOS que evita que el Mac se duerma por inactividad, con gating opcional por red Wi-Fi.

![CI](https://img.shields.io/badge/CI-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![macOS](https://img.shields.io/badge/macOS-14%2B-lightgrey)
![Arch](https://img.shields.io/badge/arch-Apple%20Silicon-black)

![menubar](docs/screenshot.png)

---

> ## Límite importante
>
> **KeepAwake NO mantiene el Mac despierto con la tapa cerrada en batería.**
>
> En Apple Silicon, el dormir con tapa cerrada en batería lo fuerza el firmware, por debajo del kernel. Ningún software — ni KeepAwake, ni `caffeinate`, ni Amphetamine — puede saltárselo. KeepAwake solo sirve con la **tapa abierta** (o con tapa cerrada si estás enchufado a corriente con monitor externo, que es el modo clamshell que macOS ya soporta).
>
> Si necesitas que el código siga corriendo con el Mac cerrado en batería, usa una máquina remota y conéctate por SSH desde el celular.

## Características

- Toggle de un click en la menubar (icono de taza, se rellena cuando está activo).
- Duraciones preconfiguradas: 15 min, 1h, 2h, 5h, indefinido, o "hasta que se cierre la tapa".
- Gating opcional por Wi-Fi: mantener despierto solo en una SSID específica, con 60s de gracia al cambiar de red.
- Toggle de "Launch at Login".
- Notificación cuando termina una sesión con timer.
- ~20 MB de RAM, 0% CPU en reposo. Cero dependencias externas.
- Firmado ad-hoc, corre 100% local, sin telemetría.

## Instalación

### Binario pre-compilado (desde Releases)

1. Descarga `KeepAwake.zip` de la página de [Releases](../../releases) y descomprímelo.
2. Saca el atributo de cuarentena (el build es ad-hoc, no está notarizado):
   ```bash
   xattr -d com.apple.quarantine KeepAwake.app
   ```
3. Muévelo a tu carpeta de Applications:
   ```bash
   mv KeepAwake.app ~/Applications/
   open ~/Applications/KeepAwake.app
   ```

### Desde el código fuente

```bash
git clone https://github.com/fbahamonde/keepawake.git
cd keepawake
./build.sh
cp -R KeepAwake.app ~/Applications/
open ~/Applications/KeepAwake.app
```

Requisitos: macOS 14+ en Apple Silicon, Xcode Command Line Tools (`xcode-select --install`).

## Uso

- **Click izquierdo** en el icono = enciende/apaga Keep Awake. Icono relleno = encendido.
- **Click derecho** = abre el menú.

### Duración

Elige cuánto rato quieres mantener despierto el Mac:

- `15 minutes` / `1 hour` / `2 hours` / `5 hours` — se apaga solo al expirar, con notificación.
- `Indefinitely` — sigue encendido hasta que tú lo apagues.
- `Until lid closes` — se apaga cuando cierras la tapa.

### Gating por Wi-Fi

Opcional. Mantiene despierto solo si estás conectado a una red específica.

1. Conéctate a la Wi-Fi que quieres usar como target (por ejemplo, el hotspot de tu celular).
2. Menú → `Only on network` → `Set current Wi-Fi as target`.
3. Si te cambias de red, KeepAwake te da 60 segundos de gracia (el icono muestra un badge naranja con cuenta regresiva). Si no vuelves, libera el assertion y el menú muestra `Paused · waiting for <target>`.
4. Al reconectarte a la red target, vuelve a tomar el assertion solo.

Sin red target configurada, KeepAwake funciona en cualquier parte, sin validar la red.

### Estados del icono

| Icono | Significado |
| --- | --- |
| Outline | Apagado |
| Relleno | Encendido, red OK (o sin target) |
| Relleno + badge naranja | Encendido, red incorrecta, cuenta regresiva 60s |
| Outline + gris | Pausado, esperando volver a la red target |

## ¿Por qué pide permiso de Ubicación?

macOS clasifica el nombre de tu red Wi-Fi (SSID) como dato sensible — saber a qué red estás conectado puede revelar dónde estás. Las apps solo pueden leer el SSID si tienen el permiso de "Ubicación cuando se usa". KeepAwake lo usa **únicamente** para comparar la SSID actual contra la que configuraste.

Sin el permiso, el keep-awake básico sigue funcionando; solo se desactiva el gating por Wi-Fi. La app nunca guarda tu ubicación y la SSID nunca sale de tu Mac.

## Desarrollo

```bash
swift test       # 38 tests XCTest
./build.sh       # construye KeepAwake.app
```

Estructura:

```
src/                Fuentes Swift (AppDelegate, status item, controller de assertion, monitor Wi-Fi, ...)
tests/              Target XCTest (KeepAwakeTests)
Info.plist          Metadata del bundle, LSUIElement, descripción del uso de ubicación
build.sh            swiftc + codesign --force --deep -s -
Package.swift      Manifiesto SwiftPM, solo para `swift test`
SMOKE_TEST.md       Checklist manual antes de dar un build por bueno
```

## Arquitectura

- **`IOPMAssertionCreateWithName`** (`PreventUserIdleSystemSleep`) — el mecanismo real de "keep awake".
- **CoreWLAN + CoreLocation** — leer la SSID actual para el gating Wi-Fi.
- **AppKit** — `NSStatusItem`, menú, notificaciones. `LSUIElement = true` mantiene la app fuera del Dock y del `Cmd-Tab`.
- **ServiceManagement** — toggle de "Launch at Login" (`SMAppService`).
- **UserNotifications** — notificación de "sesión terminada" cuando expira un timer.

Cero dependencias externas. Compilado con `swiftc` directo (sin proyecto Xcode), firmado ad-hoc (`codesign -s -`).

Bundle ID: `com.felipe.keepawake`.

## Contribuir

Es una herramienta personal, pero issues y PRs son bienvenidos. Si encuentras un bug, lo ideal es un PR chico con un test de regresión en `tests/`. Por favor mantén el footprint de dependencias en cero.

## Licencia

[MIT](LICENSE) © 2026 Felipe Bahamonde. Herramienta personal, sin garantía.
