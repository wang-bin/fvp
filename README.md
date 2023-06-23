# fvp

[Flutter Video Player](https://pub.dev/packages/video_player) **Plugin** based on [libmdk](https://github.com/wang-bin/mdk-sdk) for all desktop and mobile platforms.


## Features
- Optimal render api: d3d11 for windows, metal for macOS/iOS, OpenGL for linux
- Hardware decoders are enabled by default

## Build

```
git submodule update --init
cd example
flutter run
```

Will download [libmdk](https://github.com/wang-bin/mdk-sdk) sdk if not found. You can also download the **latest** sdk for [windows](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-windows-desktop-vs2022.7z/download) and [linux](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-linux.tar.xz) manually and extract in windows and linux folder. macOS and iOS will download the [latest sdk](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-apple.zip/download) by cocoapods. To upgrade to the latest macOS/iOS sdk
```
cd examples/macos
pod deintegrate
pod cache clean mdk
pod install --verbose
```

## How to Use
Add 2 lines in your video_player examples
- `import 'package:fvp/video_player_mdk.dart';`
- `MdkVideoPlayer.registerWith();`
## TODO:
- [x] macOS, iOS
- [x] Windows
- [x] video_player plugin
- [x] Linux
- [ ] Android
- [ ] Android vulkan rendering
- [ ] Assets



# Design
- Playback control api in dart via ffi
- Manage video renderers in platform specific manners. Receive player ptr via `MethodChannel` to construct player instance and set a renderer target.
- Callbacks and events in C++ are notified by ReceivePort
