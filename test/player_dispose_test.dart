import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fvp/mdk.dart';

// Exercise the real disposal path; texture release and the stop request are
// isolated so only synchronous native destruction can block this test.
class _PlayerWithoutTexture extends Player {
  bool failTextureRelease = false;

  @override
  Future<int> updateTexture({
    int? width,
    int? height,
    bool? tunnel,
    bool? fit,
  }) async {
    if (failTextureRelease) {
      failTextureRelease = false;
      throw StateError('texture release failed');
    }
    return -1;
  }

  @override
  set state(PlaybackState value) {}
}

void main() {
  test('slow native destruction does not block the UI isolate', () async {
    // The production ANR is Android-specific. This macOS fixture substitutes
    // only the native entry points and runs the actual Dart Player.dispose.
    final originalDirectory = Directory.current;
    final directory = Directory.systemTemp.createTempSync('fvp-dispose-');
    addTearDown(() {
      Directory.current = originalDirectory;
      directory.deleteSync(recursive: true);
    });
    // Flutter's test runner uses a generated script URI; resolve from the
    // package working directory instead.
    final source = '${originalDirectory.path}/test/native/slow_player.c';
    final mdk = Directory('${directory.path}/mdk.framework')..createSync();
    final fvp = Directory('${directory.path}/fvp.framework')..createSync();
    final compile = await Process.run('clang', [
      '-dynamiclib',
      '-std=c11',
      source,
      '-o',
      '${mdk.path}/mdk',
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stderr}');
    File('${mdk.path}/mdk').copySync('${fvp.path}/fvp');
    Directory.current = directory;
    final native = DynamicLibrary.open('${mdk.path}/mdk');
    final deletedPlayers =
        native.lookupFunction<Int32 Function(), int Function()>(
      'deletedPlayers',
    );

    final player = _PlayerWithoutTexture()..failTextureRelease = true;
    await expectLater(player.disposeAsync(), throwsStateError);
    expect(deletedPlayers(), 0);
    // A failed texture release must allow disposal to be retried.
    final elapsed = Stopwatch()..start();
    final heartbeat = Completer<Duration>();
    Timer(const Duration(milliseconds: 10), () {
      heartbeat.complete(elapsed.elapsed);
    });
    player.dispose();
    final disposed = player.disposeAsync();
    final heartbeatDelay = await heartbeat.future;
    expect(deletedPlayers(), 0);
    // Repeated disposal shares completion and must delete exactly once.
    await disposed.timeout(const Duration(seconds: 3));
    expect(deletedPlayers(), 1);
    expect(heartbeatDelay.inMilliseconds, lessThan(150));
  }, skip: !Platform.isMacOS);
}
