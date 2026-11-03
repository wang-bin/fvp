import 'package:flutter_test/flutter_test.dart';
import 'package:fvp/fvp.dart' show FvpCreateCancellation, FvpInitialTracks;
import 'package:fvp/src/initial_tracks.dart' show currentFvpInitialTracks;

void main() {
  test('exposes the tracks to the creation awaited inside run()', () async {
    const tracks = FvpInitialTracks(audio: [1], subtitle: []);
    expect(currentFvpInitialTracks, isNull);

    final seen = await tracks.run(() async {
      // VideoPlayerController.initialize() reaches createWithOptions() after
      // awaits: the zone value must survive them.
      await Future<void>.delayed(Duration.zero);
      return currentFvpInitialTracks;
    });

    expect(seen, same(tracks));
    expect(currentFvpInitialTracks, isNull);
  });

  test('composes with FvpCreateCancellation', () async {
    const tracks = FvpInitialTracks(video: []);
    final cancellation = FvpCreateCancellation();

    final seen = await cancellation.run(
      () => tracks.run(() async => currentFvpInitialTracks),
    );

    expect(seen, same(tracks));
  });
}
