# FVP

A plugin for [Flutter Video Player](https://pub.dev/packages/video_player) to support all desktop and mobile platforms, with hardware accelerated decoding and optimal rendering. Based on [libmdk](https://github.com/wang-bin/mdk-sdk).

Prebuilt example can be download from artifacts of [github actions](https://github.com/wang-bin/fvp/actions).

## Features
- All platforms: Windows, Linux, macOS, iOS, Android
- Optimal render api: d3d11 for windows, metal for macOS/iOS, OpenGL for Linux and Android
- Hardware decoders are enabled by default
- Minimal code change for existing [Video Player](https://pub.dev/packages/video_player) apps
- Support most formats via FFmpeg demuxer and software decoders if not supported by gpu.

## How to Use

`flutter pub add fvp` then add 2 lines in your video_player examples

```dart
import 'package:fvp/fvp.dart';

MdkVideoPlayer.registerWith();
```

To select other decoders, pass options like this
```dart
MdkVideoPlayer.registerWith({'video.decoders': ['D3D11', 'NVDEC', 'FFmpeg']}); // windows

```
## Build this Git Repo

If you are developing this project

```bash
git submodule update --init
cd example
flutter run
```

Will download [libmdk](https://github.com/wang-bin/mdk-sdk) sdk if not found. You can also download the **latest** sdk for [android](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-android.7z), [windows](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-windows-desktop-vs2022.7z/download) and [linux](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-linux.tar.xz) manually and extract in android, windows and linux folder. macOS and iOS will download the [latest sdk](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-apple.zip/download) by cocoapods. To upgrade to the latest macOS/iOS sdk

```bash
cd examples/macos
pod deintegrate
pod cache clean mdk
pod install --verbose
```

## Known Issues
- Memory leak on linux if a player is disposed

# Design
- Playback control api in dart via ffi
- Manage video renderers in platform specific manners. Receive player ptr via `MethodChannel` to construct player instance and set a renderer target.
- Callbacks and events in C++ are notified by ReceivePort

# Screenshots
![fpv_android](https://github.com/wang-bin/fvp/assets/785206/40f458e5-d7ca-4513-b709-b056deaaf421)
![fvp_win](https://github.com/wang-bin/fvp/assets/785206/920bdd51-6947-4a00-87b4-9c1a21a68d51)
![fvp_linux](https://github.com/wang-bin/fvp/assets/785206/ce2ad50b-2ead-43bb-bf25-6e2575c5ebe1)
![fvp_macos](https://github.com/wang-bin/fvp/assets/785206/71de39a4-c5f0-4c8f-9920-d7dfc6cd0d9a)