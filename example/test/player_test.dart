// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:test/test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:fvp/src/video_player_mdk.dart';
import 'package:fvp/fvp.dart' as fvp;

void main() {
  test('registration', () {
    fvp.registerWith();
    expect(VideoPlayerPlatform.instance, isA<MdkVideoPlayerPlatform>());
  });

  test('debug utilities', () {
    fvp.registerWith();
    
    // Test decoder info utility
    final decoderInfo = fvp.FVPUtils.getDecoderInfo();
    expect(decoderInfo, isA<Map<String, dynamic>>());
    expect(decoderInfo.containsKey('platform'), isTrue);
    expect(decoderInfo.containsKey('configuredDecoders'), isTrue);
    
    // Test system hardware support check
    fvp.FVPUtils.checkSystemHardwareSupport().then((systemInfo) {
      expect(systemInfo, isA<Map<String, dynamic>>());
      expect(systemInfo.containsKey('platform'), isTrue);
    });
  });
}
