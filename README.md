# FVP

A plugin for official [Flutter Video Player](https://pub.dev/packages/video_player) to support all desktop and mobile platforms, with hardware accelerated decoding and optimal rendering. Based on [libmdk](https://github.com/wang-bin/mdk-sdk). You can also create your own players other than official `video_player` with [backend player api](#backend-player-api)

Prebuilt example can be download from artifacts of [github actions](https://github.com/wang-bin/fvp/actions).

[More examples are here](https://github.com/wang-bin/mdk-examples/tree/master/flutter)

## Features
- All platforms: Windows, Linux, macOS, iOS, Android
- You can choose official implementation or this plugin's
- Optimal render api: d3d11 for windows, metal for macOS/iOS, OpenGL for Linux and Android
- Hardware decoders are enabled by default
- Minimal code change for existing [Video Player](https://pub.dev/packages/video_player) apps
- Support most formats via FFmpeg demuxer and software decoders if not supported by gpu. You can use your own ffmpeg 4.0~6.x(or master branch) by removing bundled ffmpeg dynamic library.
- High performance. Lower cpu, gpu and memory load than libmpv based players.
- Small footprint. Only about 10MB size increase(platform dependent).

## Requirements
- Android: ndk 23 or later(ndk has a stupid abi break in 23)

## How to Use

- Add [fvp](https://pub.dev/packages/fvp) in your pubspec.yaml dependencies: `flutter pub add fvp`
- Add 2 lines in your video_player examples,

```dart
import 'package:fvp/fvp.dart';

registerWith(); // in main(), or anywhere before creating a player
```

Then this plugin implementation will be used for all platforms. Sometimes you may want official implementation for android and ios, then you can call

```dart
registerWith(options: {'platforms': ['windows', 'macos', 'linux']}); // only these platforms will use this plugin implementation
```

To select [other decoders](https://github.com/wang-bin/mdk-sdk/wiki/Decoders), pass options like this
```dart
registerWith(options: {'video.decoders': ['D3D11', 'NVDEC', 'FFmpeg']}); // windows
```

### Backend Player API

```dart
import 'package:fvp/mdk.dart';
```

The plugin implements [VideoPlayerPlatform](https://pub.dev/packages/video_player_platform_interface) via [a thin wrapper](https://github.com/wang-bin/fvp/blob/master/lib/video_player_mdk.dart) on [player.dart](https://github.com/wang-bin/fvp/blob/master/lib/src/player.dart).

Now we also expose this backend player api so you can create your own players easily, and gain more features than official [video_player](https://pub.dev/packages/video_player), for example, play from a given position, loop in a range, decoder selection, media information detail etc. You can also reuse the Player instance without unconditionally create and dispose, changing the `Player.media` is enough.
[This is an example](https://github.com/wang-bin/mdk-examples/blob/master/flutter/simple/lib/multi_textures.dart)


# Design
- Playback control api in dart via ffi
- Manage video renderers in platform specific manners. Receive player ptr via `MethodChannel` to construct player instance and set a renderer target.
- Callbacks and events in C++ are notified by ReceivePort
- Function with a one time callback is async and returns a future

# Screenshots
![fpv_android](https://user-images.githubusercontent.com/785206/248862591-40f458e5-d7ca-4513-b709-b056deaaf421.jpeg)
![fvp_ios](https://user-images.githubusercontent.com/785206/250348936-e5e1fb14-9c81-4652-8f53-37e8d64195a3.jpg)
![fvp_win](https://user-images.githubusercontent.com/785206/248859525-920bdd51-6947-4a00-87b4-9c1a21a68d51.jpeg)
![fvp_linux](https://user-images.githubusercontent.com/785206/248859533-ce2ad50b-2ead-43bb-bf25-6e2575c5ebe1.jpeg)
![fvp_macos](https://user-images.githubusercontent.com/785206/248859538-71de39a4-c5f0-4c8f-9920-d7dfc6cd0d9a.jpg)