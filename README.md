# fvp

[Flutter Video Player](https://pub.dev/packages/video_player) **Plugin** based on [libmdk](https://github.com/wang-bin/mdk-sdk). Accelerated by D3D11/Metal without cpu copy. Will support all mobile and desktop platforms.


## Build

- Windows: download [libmdk sdk](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-windows-desktop-vs2022.7z/download) and extract in `windows` dir
- macOS/iOS: the [latest sdk](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-apple.zip/download) will be downloaded by cocoapods

```
git submodule update --init
cd example
flutter run
```

## How to Use
Add 2 lines in your video_player examples
- `import 'package:fvp/video_player_mdk.dart';`
- `MdkVideoPlayer.registerWith();`
## TODO:
- [x] macOS, iOS
- [x] Windows
- [x] video_player plugin
- [ ] Linux
- [ ] Android



# Design
- Playback control api in dart via ffi
- Manage video renderers in platform specific manners. Receive player ptr via `MethodChannel` to construct player instance and set a renderer target.
- Callbacks and events in C++ are notified by ReceivePort
