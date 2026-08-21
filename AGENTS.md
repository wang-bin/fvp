# AGENTS.md

## Cursor Cloud specific instructions

`fvp` is a **Flutter plugin** (a `video_player` implementation + backend player API) backed by
the native `libmdk`/`mdk-sdk` C/C++ SDK via Dart FFI. There is **no backend server, database, or
listening port** — "running" the product means running the demo app in `example/`.

### Environment already provisioned (by the startup update script + one-off setup)
- Flutter SDK (stable) is installed at `/opt/flutter` and symlinked onto `PATH` via
  `/usr/local/bin/flutter` and `/usr/local/bin/dart`, so `flutter`/`dart` work in any shell
  (no PATH export needed). Linux desktop is enabled (`flutter config --enable-linux-desktop`).
- Linux native build toolchain is installed: `cmake`, `clang`, `ninja-build`, `pkg-config`,
  `libgtk-3-dev`, `libpulse-dev`. Note `libstdc++-14-dev` is required (not just `-13`): clang 18
  selects the GCC 14 toolchain, and without `libstdc++-14-dev` the C++ link step fails with
  `cannot find -lstdc++`.
- The update script runs `flutter pub get` for the plugin and `example/`.

### Running / building the example app (dev mode)
Run from `example/` with an X display (the VM provides `DISPLAY=:1`):
```
cd example
DISPLAY=:1 flutter run -d linux      # dev mode (hot reload)
flutter build linux --debug          # build only
```
Standard test/lint commands (see `.github/workflows/build.yml`):
```
flutter analyze          # lint (run from repo root)
cd example && flutter test
```

### Non-obvious gotchas
- **First native build downloads `mdk-sdk`**: on the first `flutter build/run linux`, `cmake/deps.cmake`
  downloads the native SDK archive from SourceForge (needs outbound network). It is cached under
  `example/linux/flutter/ephemeral/.../mdk-sdk` afterward. Use `FVP_DEPS_URL` + `FVP_DEPS_SHA256`
  (or `FVP_DEPS_LATEST=1`) to pin/override the SDK source.
- **Never reuse a broken CMake cache**: the Flutter Linux `CMakeLists.txt` only forces
  `CMAKE_INSTALL_PREFIX` to the bundle dir when `CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT` is
  true (i.e. the *first* configure). If a first configure fails partway (e.g. missing toolchain)
  and you fix the toolchain and re-run, the stale cache keeps `CMAKE_INSTALL_PREFIX=/usr/local` and
  the build fails with `Permission denied` copying to `/usr/local/fvp_example`. Fix: delete
  `example/build/linux` and rebuild clean.
- **Harmless runtime warnings** on this headless-GPU VM: `libEGL warning: DRI3 error`,
  `Failed to open VDPAU backend libvdpau_nvidia.so`, and `Unable to access driver information using
  'eglinfo'` in `flutter doctor`. Rendering falls back to software and video still plays.
- **Android toolchain is not installed** (`flutter doctor` shows Android as missing). Only the
  Linux desktop / web targets are set up here.
- **Pre-existing stale test**: `example/test/player_test.dart` fails on a clean checkout — it
  expects `VideoPlayerPlatform.instance` to be `MdkVideoPlayer`, but the registered instance is
  `MdkVideoPlayerPlatform` (and `MdkVideoPlayer` extends `mdk.Player`, not `VideoPlayerPlatform`).
  This is a bug in the test, unrelated to environment setup.
