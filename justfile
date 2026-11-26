alias c := clean

gtest_filter := "*"

# Default build/<platform> folder for the host (matches the generator recipes below).
platform := if os() == "macos" { "mac" } else if os() == "linux" { "linux" } else if os() == "windows" { "win" } else { "ninja" }

# Project / target name, read from CMakeLists.txt (the single source of truth).
project := `sed -n -E 's/^[[:space:]]*set[[:space:]]*\([[:space:]]*PROJECT_NAME[[:space:]]+"([^"]*)".*/\1/p' CMakeLists.txt | head -n1`

# Extra arguments for the configure recipes, e.g.
#   just cmake_args="-DENABLE_LTO=ON -DPLUGIN_COPY_AFTER_BUILD=OFF" mac
cmake_args := ""

[doc("list available recipes")]
default:
  @just --list

# =============================================================================
# CONFIGURE PER PLATFORM
# =============================================================================
[doc("generate project using Ninja multi config")]
ninja PROFILING="OFF":
  cmake -G "Ninja Multi-Config" -B build/ninja -DYUP_ENABLE_PROFILING={{PROFILING}} -DBUILD_BENCHMARKS=ON {{cmake_args}}

[doc("generate and open project in macOS using Xcode")]
mac PROFILING="OFF":
  cmake -G Xcode -B build/mac -DYUP_ENABLE_PROFILING={{PROFILING}} -DBUILD_BENCHMARKS=ON {{cmake_args}}
  -open build/mac/{{project}}.xcodeproj

[doc("generate and open project in Windows using Visual Studio")]
win PROFILING="OFF":
  cmake -G "Visual Studio 18 2026" -B build/win -DYUP_ENABLE_PROFILING={{PROFILING}} -DBUILD_BENCHMARKS=ON {{cmake_args}}
  -start build/win/{{project}}.slnx

[doc("generate project in Linux using Ninja")]
linux PROFILING="OFF":
  cmake -G "Ninja Multi-Config" -B build/linux -DYUP_ENABLE_PROFILING={{PROFILING}} -DBUILD_BENCHMARKS=ON {{cmake_args}}

[doc("generate and open project for iOS using Xcode")]
[macos]
ios PLATFORM="OS64":
  cmake -G Xcode -B build/ios -DCMAKE_TOOLCHAIN_FILE=yup/cmake/toolchains/ios.cmake -DPLATFORM={{PLATFORM}} {{cmake_args}}
  -open build/ios/{{project}}.xcodeproj

[doc("generate and open project for iOS Simulator macOS using Xcode")]
[macos]
ios_simulator PLATFORM="SIMULATORARM64":
  cmake -G Xcode -B build/ios_sim -DCMAKE_TOOLCHAIN_FILE=yup/cmake/toolchains/ios.cmake -DPLATFORM={{PLATFORM}} {{cmake_args}}
  -open build/ios_sim/{{project}}.xcodeproj

[doc("generate and open project for Android using Android Studio (macos)")]
[macos]
android:
  cmake -G Xcode -B build/android -DYUP_TARGET_ANDROID=ON {{cmake_args}}
  -open -a /Applications/Android\ Studio.app build/android

[doc("generate and open project for Android using Android Studio (windows)")]
[windows]
android:
  cmake -G "Visual Studio 18 2026" -B build/android -DYUP_TARGET_ANDROID=ON {{cmake_args}}
  -start "C:\\Program Files\\Android\\Android Studio\\bin\\studio64.exe" build\\android

[doc("generate and open project for Android using Android Studio (linux)")]
[linux]
android:
  cmake -G "Unix Makefiles" -B build/android -DYUP_TARGET_ANDROID=ON {{cmake_args}}

[doc("generate and build project for WASM")]
emscripten CONFIG="Debug":
  emcc -v
  emcmake cmake -G "Ninja Multi-Config" -B build/emscripten {{cmake_args}}
  cmake --build build/emscripten --config {{CONFIG}}

[doc("run tests for WASM")]
emscripten_test CONFIG="Debug":
  @just emscripten {{CONFIG}}
  cd build/emscripten/tests/{{CONFIG}} && node {{project}}_tests.js --gtest_filter={{gtest_filter}}

[doc("serve project for WASM")]
emscripten_serve:
  python3 -m http.server -d .

# =============================================================================
# BUILD / TEST / PACKAGE
# =============================================================================

[doc("build everything that is enabled (application + plugin formats)")]
build PLATFORM=platform CONFIG="Release":
  cmake --build build/{{PLATFORM}} --config {{CONFIG}} --target {{project}}_all

[doc("build only the standalone application")]
build-app PLATFORM=platform CONFIG="Release":
  cmake --build build/{{PLATFORM}} --config {{CONFIG}} --target {{project}}_app

[doc("build only the plugin (all enabled formats)")]
build-plugin PLATFORM=platform CONFIG="Release":
  cmake --build build/{{PLATFORM}} --config {{CONFIG}} --target {{project}}

[doc("build and run the test suite")]
test PLATFORM=platform CONFIG="Debug":
  cmake --build build/{{PLATFORM}} --config {{CONFIG}} --target {{project}}_tests
  GTEST_FILTER="{{gtest_filter}}" ctest --test-dir build/{{PLATFORM}}/tests -C {{CONFIG}} --output-on-failure

[doc("build and run the DSP micro-benchmarks (google/benchmark)")]
bench PLATFORM=platform CONFIG="Release":
  cmake --build build/{{PLATFORM}} --config {{CONFIG}} --target {{project}}_benchmarks_run

[confirm("Are you sure you want to clean the build folder? [y/N]")]
[doc("clean project build artifacts for a specific platform")]
clean PLATFORM="*":
  rm -Rf build/{{PLATFORM}}

# =============================================================================
# PACKAGING
# =============================================================================

[doc("generate platform icons (.icns/.ico) from assets/app-icon.png")]
icons:
  ./packaging/icons/generate_icons.sh

[doc("build a macOS installer package (.pkg)")]
[macos]
package-macos CONFIG="Release":
  ./packaging/macos/build_pkg.sh {{CONFIG}} build/mac

[doc("build a Linux tarball and Debian package")]
[linux]
package-linux CONFIG="Release":
  ./packaging/linux/build_archive.sh {{CONFIG}} build/linux
  ./packaging/linux/build_deb.sh {{CONFIG}} build/linux

[doc("build a Windows installer (requires Inno Setup)")]
[windows]
package-win CONFIG="Release":
  pwsh packaging/windows/build_installer.ps1 -Config {{CONFIG}} -BuildDir build/win

[doc("archive the Emscripten WASM standalone build (.tar.gz)")]
package-wasm CONFIG="Release":
  ./packaging/wasm/build_archive.sh {{CONFIG}} build/emscripten

# =============================================================================
# DEVELOPER TOOLING
# =============================================================================

[doc("rename the project: `just rename --help` lists the options")]
rename *ARGS:
  python3 scripts/rename_project.py {{ARGS}}

# CI runs `format-check` with the clang-format version pinned in
# .github/workflows/format.yml: use the same one to get the same result.
[doc("format all source files with clang-format")]
format:
  find source tests benchmarks -type f \( -name '*.h' -o -name '*.cpp' \) -print0 | xargs -0 clang-format -i

[doc("check source formatting without modifying files")]
format-check:
  find source tests benchmarks -type f \( -name '*.h' -o -name '*.cpp' \) -print0 | xargs -0 clang-format --dry-run --Werror
