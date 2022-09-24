# fvp

Flutter Video Player example based on [libmdk](https://github.com/wang-bin/mdk-sdk). Accelerated by D3D11/Metal without cpu copy.

I'm not able to write a feature complete plugin and example for now, it's just a very simple demo. Change the line `player.media = ` in `FvpPlugin.swift` and `player_.setMedia` in `fvp_plugin.cpp` to test your video.

## Build

- Windows: download [libmdk sdk](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-windows-desktop-vs2022.7z/download) and extract in `windows` dir
- macOS: the [latest sdk](https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-apple.zip/download) will be downloaded by cocoapods

```
git submodule update --init
cd example
flutter run
```

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/developing-packages/),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter development, view the
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## TODO:
- Android, iOS
