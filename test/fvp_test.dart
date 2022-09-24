import 'package:flutter_test/flutter_test.dart';
import 'package:fvp/fvp.dart';
import 'package:fvp/fvp_platform_interface.dart';
import 'package:fvp/fvp_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFvpPlatform
    with MockPlatformInterfaceMixin
    implements FvpPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FvpPlatform initialPlatform = FvpPlatform.instance;

  test('$MethodChannelFvp is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFvp>());
  });

  test('getPlatformVersion', () async {
    Fvp fvpPlugin = Fvp();
    MockFvpPlatform fakePlatform = MockFvpPlatform();
    FvpPlatform.instance = fakePlatform;

    expect(await fvpPlugin.getPlatformVersion(), '42');
  });
}
