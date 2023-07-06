# FVP

A plugin for official [Flutter Video Player](https://pub.dev/packages/video_player) to support all desktop and mobile platforms, with hardware accelerated decoding and optimal rendering. Based on [libmdk](https://github.com/wang-bin/mdk-sdk).

Prebuilt example can be download from artifacts of [github actions](https://github.com/wang-bin/fvp/actions).

## Features
- All platforms: Windows, Linux, macOS, iOS, Android
- Optimal render api: d3d11 for windows, metal for macOS/iOS, OpenGL for Linux and Android
- Hardware decoders are enabled by default
- Minimal code change for existing [Video Player](https://pub.dev/packages/video_player) apps
- Support most formats via FFmpeg demuxer and software decoders if not supported by gpu. You can use your own ffmpeg 4.0~6.x(or master branch) by removing bundled ffmpeg dynamic library.
- High performance. Lower cpu, gpu and memory load than libmpv based players.
- Small footprint. Only about 10MB size increase(platform dependent).

## How to Use

`flutter pub add fvp` then add 2 lines in your video_player examples

```dart
import 'package:fvp/fvp.dart';

MdkVideoPlayer.registerWith();
```

To select [other decoders](https://github.com/wang-bin/mdk-sdk/wiki/Decoders), pass options like this
```dart
MdkVideoPlayer.registerWith({'video.decoders': ['D3D11', 'NVDEC', 'FFmpeg']}); // windows
```

# Design
- Playback control api in dart via ffi
- Manage video renderers in platform specific manners. Receive player ptr via `MethodChannel` to construct player instance and set a renderer target.
- Callbacks and events in C++ are notified by ReceivePort

# Screenshots
![fpv_android](https://github.com/wang-bin/fvp/assets/785206/40f458e5-d7ca-4513-b709-b056deaaf421)
![fvp_ios](https://user-images.githubusercontent.com/785206/250348936-e5e1fb14-9c81-4652-8f53-37e8d64195a3.jpg)
![fvp_win](https://github.com/wang-bin/fvp/assets/785206/920bdd51-6947-4a00-87b4-9c1a21a68d51)
![fvp_linux](https://github.com/wang-bin/fvp/assets/785206/ce2ad50b-2ead-43bb-bf25-6e2575c5ebe1)
![fvp_macos](https://github.com/wang-bin/fvp/assets/785206/71de39a4-c5f0-4c8f-9920-d7dfc6cd0d9a)