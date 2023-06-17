

import 'fvp_platform_interface.dart';
import 'src/global.dart' as mdk;
import 'src/player.dart' as mdk;

class Fvp {
  final player = mdk.Player();

  Fvp() {
    player.loop = -1;
    player.videoDecoders = ['VT', 'FFmpeg'];
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
