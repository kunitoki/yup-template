<p align="center">
  <img src="assets/app-icon.png" alt="YUP Template" width="160" height="160">
</p>

<h1 align="center">YUP Application and Plugin Template</h1>

<p align="center">
  <a href="https://github.com/kunitoki/yup-template/actions/workflows/build_macos.yml"><img src="https://github.com/kunitoki/yup-template/actions/workflows/build_macos.yml/badge.svg" alt="macOS"></a>
  <a href="https://github.com/kunitoki/yup-template/actions/workflows/build_windows.yml"><img src="https://github.com/kunitoki/yup-template/actions/workflows/build_windows.yml/badge.svg" alt="Windows"></a>
  <a href="https://github.com/kunitoki/yup-template/actions/workflows/build_linux.yml"><img src="https://github.com/kunitoki/yup-template/actions/workflows/build_linux.yml/badge.svg" alt="Linux"></a>
  <a href="https://github.com/kunitoki/yup-template/actions/workflows/build_ios.yml"><img src="https://github.com/kunitoki/yup-template/actions/workflows/build_ios.yml/badge.svg" alt="iOS"></a>
  <a href="https://github.com/kunitoki/yup-template/actions/workflows/build_android.yml"><img src="https://github.com/kunitoki/yup-template/actions/workflows/build_android.yml/badge.svg" alt="Android"></a>
  <a href="https://github.com/kunitoki/yup-template/actions/workflows/build_wasm.yml"><img src="https://github.com/kunitoki/yup-template/actions/workflows/build_wasm.yml/badge.svg" alt="WebAssembly"></a>
  <a href="https://github.com/kunitoki/yup-template/actions/workflows/coverage.yml"><img src="https://github.com/kunitoki/yup-template/actions/workflows/coverage.yml/badge.svg" alt="Coverage"></a>
</p>

A cross-platform **application** and **audio plugin** template built with the [YUP](https://github.com/kunitoki/yup)
framework. A single source tree builds both a standalone application ("Hello, YUP!" window) and a
small polyphonic instrument plugin you can rename and extend. Keep both, or switch off the one you
don't need with `-DBUILD_APP=OFF` / `-DBUILD_PLUGIN=OFF`.

> Plugin formats: **CLAP · VST3 · AU · AUv3 · LV2 · AAX · Standalone** — targeting macOS, Windows,
> Linux, iOS, Android and WebAssembly.

> [!TIP]
> This is a **template repository**. Click **Use this template** on GitHub to create your own
> application or plugin repository from it — see [Getting started](#getting-started).

---

## What's inside

The template is a complete, working application and synthesizer so you have something that runs and
makes sound on day one:

- **`source/app/`** — a standalone `YUPApplication` with a `DocumentWindow` (`MainWindow`), the
  starting point for a desktop, mobile or web application.
- **`PluginProcessor`** — a polyphonic instrument with four automatable parameters (`Gain`,
  `Waveform`, `Attack`, `Release`), each exposed to the host with proper units and value strings.
- **`PluginEditor`** — a resizable UI (knobs + playable keyboard) that preserves its aspect ratio and
  scales cleanly at any size.
- **`source/shared/dsp/SynthVoice.h`** — a header-only, standard-library-only oscillator + envelope engine,
  trivial to unit test and to replace with your own DSP. Code in `source/shared/` is visible to both
  the application and the plugin.
- **Tests** — a GoogleTest suite wired into YUP's shared test runner (no vendored `main.cpp`).
- **Packaging** — ready-to-run installer scripts for macOS, Windows, Linux, iOS, Android and WebAssembly
  that ship the application and the plugin together.
- **CI** — GitHub Actions for every platform, including build, test, coverage and packaging.

## Prerequisites

- **CMake** ≥ 3.31
- A C++20 toolchain:
  - macOS: Xcode (with command line tools)
  - Windows: Visual Studio 2022/2026
  - Linux: GCC/Clang + the audio/X11/GL dev packages (see `.github/workflows/build_linux.yml`)
- [`just`](https://github.com/casey/just) *(optional, for the convenience recipes below)*

## Getting started

This is a **GitHub template repository** — don't fork it. Click
**[Use this template](https://github.com/kunitoki/yup-template/generate)** → *Create a new
repository* to start your own project from it, then clone your new repository.

Because the project uses YUP as a git submodule, clone recursively:

```bash
git clone --recursive https://github.com/<you>/<your-project>.git
cd <your-project>
```

Already cloned without `--recursive`? Pull the submodule in:

```bash
git submodule update --init --recursive
```

## Building

Like YUP itself, every platform is generated into its own `build/<platform>` folder (`mac`, `win`,
`linux`, `ninja`, `ios`, `ios_sim`, `android`, `emscripten`), so several platforms can live side by
side.

Using `just` (recommended):

```bash
just mac                  # generate + open an Xcode project in build/mac (macOS)
just win                  # generate + open a Visual Studio solution in build/win (Windows)
just linux                # generate a Ninja build in build/linux (Linux)
just ninja                # generate a Ninja build in build/ninja (any host)
just build                # build the application and every enabled plugin format (Release)
just build-app            # build only the application
just build-plugin         # build only the plugin
just build ninja Debug    # pick the build/<platform> folder and the configuration
just clean mac            # wipe build/mac (or `just clean` to wipe everything)
```

`PLATFORM` defaults to the host's native folder: `mac` on macOS, `win` on Windows and `linux` on
Linux.

Using CMake directly:

```bash
cmake -G "Ninja Multi-Config" -B build/ninja
cmake --build build/ninja --config Release --target <PROJECT_NAME>_all
```

| Target | Builds |
|--------|--------|
| `<PROJECT_NAME>_all` | Everything that is enabled |
| `<PROJECT_NAME>_app` | The standalone application (`BUILD_APP`) |
| `<PROJECT_NAME>` | Every enabled plugin format (`BUILD_PLUGIN`) |

Built artifacts land under `build/<platform>/<Config>/` (VST3 under `build/<platform>/VST3/<Config>/`).
On macOS the plugins are also copied into your user plugin folders automatically after each build.

> [!NOTE]
> **Android** produces a single Gradle project per build folder, so only one of the two targets can be
> the APK. The application wins when both are enabled; configure with `-DBUILD_APP=OFF` to ship the
> plugin's standalone instead.

## Testing

```bash
just test                 # build + run the test suite via CTest (Debug)
just test mac Release     # ...from a specific build folder and configuration
just bench                # build + run the DSP micro-benchmarks in build/bench
```

Or directly:

```bash
cmake --build build/ninja --config Debug --target <PROJECT_NAME>_tests
ctest --test-dir build/ninja/tests -C Debug --output-on-failure
```

For WebAssembly: `just emscripten_test`. The plugin tests are skipped when `BUILD_PLUGIN` is off.

## Packaging

The `packaging/` directory contains scripts that collect the built artifacts into native installers
that ship the application and the plugin together. Build the project first, then:

```bash
just icons          # (re)generate app-icon.icns / app-icon.ico from assets/app-icon.png
just package-macos  # macOS .pkg from build/mac
just package-linux  # Linux .tar.gz + .deb from build/linux
just package-win    # Windows installer from build/win
just package-wasm   # WebAssembly .tar.gz from build/emscripten
```

| Platform | Output | Requires |
|----------|--------|----------|
| macOS   | `.pkg` installer (application + plugins + plugin standalone) | Xcode command line tools |
| Linux   | `.tar.gz` archive **and** `.deb` package                      | `dpkg-deb` |
| Windows | `.exe` installer                                              | [Inno Setup 6](https://jrsoftware.org/isinfo.php) |
| iOS     | One unsigned `.ipa` per application                           | Xcode |
| Android | `.apk`                                                        | Android SDK / NDK |
| WebAssembly | `.tar.gz` with one folder per application                 | Emscripten |

Installers are written to `dist/`. See [`packaging/README.md`](packaging/README.md) for details,
signing options and layout.

## Configuration

Edit the variables near the top of `CMakeLists.txt` to make the template your own. This is the
**only** place you need to touch: the sources (via the `YupApp_*` / `YupPlugin_*` macros), the
`justfile`, the CI workflows and the packaging scripts all read these values from here. Keep them
plain literal strings, the scripts can't expand `${...}` references.

| Variable | Description |
|----------|-------------|
| `PROJECT_NAME` | Internal name and target prefix (no spaces) |
| `PRODUCT_NAME` / `PRODUCT_DESCRIPTION` | Name and description of the whole product (installers, archives) |
| `COMPANY_NAME` | Vendor / author name |
| `BUNDLE_ID` | Reverse-domain identifier of the product (installer package) |
| `PRODUCT_URL` / `PRODUCT_EMAIL` | Website and contact metadata |
| `APP_PRODUCT_NAME` / `APP_BUNDLE_ID` | Name and identifier of the standalone application |
| `PLUGIN_PRODUCT_NAME` / `PLUGIN_BUNDLE_ID` | Name and identifier of the plugin (and its standalone) |
| `PLUGIN_DESCRIPTION` | Plugin description |
| `PLUGIN_CODE` / `PLUGIN_MANUFACTURER_CODE` | Four-character AU/AAX codes (stable once shipped) |
| `INSTALLER_GUID` | Windows installer AppId - generate your own (`powershell [guid]::NewGuid()`) and keep it stable |

`APP_PRODUCT_NAME` and `PLUGIN_PRODUCT_NAME` name the generated executables, so they must differ when
both targets are built.

The version lives in the `VERSION` file (`MAJOR.MINOR.PATCH`) and can be overridden with
`-DTARGET_VERSION=...`. The version parsing and the Apple deployment target detection are shared
macros in `cmake/utilities.cmake`.

Toggle targets, formats and features with CMake options, e.g. `-DPLUGIN_BUILD_VST3=OFF`:

`BUILD_APP`, `BUILD_PLUGIN`, `PLUGIN_BUILD_CLAP`, `PLUGIN_BUILD_VST3`, `PLUGIN_BUILD_AU`,
`PLUGIN_BUILD_AUV3`, `PLUGIN_BUILD_LV2`, `PLUGIN_BUILD_STANDALONE`, `BUILD_TESTS`, `BUILD_BENCHMARKS`,
`ENABLE_COVERAGE`, `ENABLE_CODE_SIGNING`.

## Project layout

```
.
├── CMakeLists.txt          # Project configuration, the application and plugin targets
├── VERSION                 # Single source of truth for the version
├── cmake/utilities.cmake   # Shared CMake helper macros
├── assets/                 # Application icon (png/ico/icns)
├── source/
│   ├── app/                # Standalone application (YUPApplication + MainWindow)
│   ├── plugin/             # Plugin processor and editor
│   └── shared/             # Code shared by both targets
│       └── dsp/            # Header-only synth engine
├── tests/                  # GoogleTest suite
├── benchmarks/             # google/benchmark DSP micro-benchmarks
├── packaging/              # Installer scripts for every platform
├── .github/workflows/      # Per-platform CI
└── yup/                    # YUP framework (git submodule)
```

## License

This template is distributed under the terms of the [LICENSE](LICENSE) file. YUP has its own license;
see the [YUP repository](https://github.com/kunitoki/yup).
