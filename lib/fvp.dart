

import 'fvp_platform_interface.dart';
import 'dart:io';
import 'src/global.dart' as mdk;
import 'src/player.dart' as mdk;

class Fvp {
  final player = mdk.Player();

  Fvp() {
    player.loop = -1;
    switch (Platform.operatingSystem) {
    case 'windows':
        player.videoDecoders = ['MFT:d3d=11', 'CUDA', 'FFmpeg'];
    case 'macos':
        player.videoDecoders = ['VT', 'FFmpeg'];
    case 'ios':
        player.videoDecoders = ['VT', 'FFmpeg'];
    case 'linux':
        player.videoDecoders = ['VAAPI', 'CUDA', 'VDPAU', 'FFmpeg'];
    case 'android':
        player.videoDecoders = ['AMediaCodec', 'FFmpeg'];
    }

    player.media = "https://live.nodemedia.cn:8443/live/b480_265.flv";
    player.state = mdk.State.playing;
    //player.setAspectRatio(mdk.ignoreAspectRatio);
    //player.rotate(90);
  }

  Future<String?> getPlatformVersion() {
    return FvpPlatform.instance.getPlatformVersion();
  }

  Future<int> createTexture() {
    return FvpPlatform.instance.createTexture(player.nativeHandle);
  }

  int getMdkVersion() {
    return mdk.version();
  }
}
