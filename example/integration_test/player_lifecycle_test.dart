import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('disposing players does not emit after streams close',
      (tester) async {
    if (!Platform.isAndroid) {
      return;
    }

    fvp.registerWith();
    const uri =
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
    final streamErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is StateError &&
          details.exception
              .toString()
              .contains('Cannot add event after closing')) {
        streamErrors.add(details);
        return;
      }
      previousOnError?.call(details);
    };

    try {
      for (var i = 0; i < 3; i++) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(uri));
        unawaited(controller.initialize().catchError((_) {}));
        await controller.dispose();
        await tester.pump(const Duration(milliseconds: 100));
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(uri));
      try {
        await controller.initialize().timeout(const Duration(seconds: 30));
        await controller.play();
        await tester.pump(const Duration(milliseconds: 500));
      } finally {
        await controller.dispose();
      }
      await tester.pump(const Duration(milliseconds: 100));
    } finally {
      FlutterError.onError = previousOnError;
    }

    expect(streamErrors, isEmpty);
  });
}
