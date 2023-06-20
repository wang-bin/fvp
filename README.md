# fvp

Flutter Video Player example based on [libmdk](https://github.com/wang-bin/mdk-sdk). Accelerated by D3D11/Metal without cpu copy.

It's still under development. You can change your video via `player.media = ` in [lib/fvp.dart](lib/fvp.dart)

## Build

- Windows: download [libmdk sdk](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-windows-desktop-vs2022.7z/download) and extract in `windows` dir
- macOS/iOS: the [latest sdk](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-apple.zip/download) will be downloaded by cocoapods

```
git submodule update --init
cd example
flutter run
```

## TODO:
- video_player plugin
- Linux
- Android



# Design
- Playback control api in dart via ffi
- Manage video renderers in platform specific manners. Receive player ptr via `MethodChannel` to construct player instance and set a renderer target.
- Callbacks and events in C++ are notified by ReceivePort
