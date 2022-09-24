
import 'fvp_platform_interface.dart';

class Fvp {
  Future<String?> getPlatformVersion() {
    return FvpPlatform.instance.getPlatformVersion();
  }

  Future<int> createTexture() {
    return FvpPlatform.instance.createTexture();
  }
}
