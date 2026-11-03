// Copyright 2022-2026 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

final Object _initialTracksZoneKey = Object();

/// Active tracks of the player created inside [run], applied after its media
/// is set and before MDK prepares it.
///
/// MDK resets the active tracks when the media is set, then enables the first
/// track of each type: a media with embedded subtitles starts rendering its
/// first subtitle track. Changing the tracks once the media is loaded costs
/// more: MDK seeks again to apply them (one more request to the source), and
/// disabling rendered subtitles stops MDK's subtitle render thread on the
/// calling thread, usually the UI thread. MDK can miss that stop (seen with
/// 0.39.0, still present in 0.40.1), and `setActiveTracks()` then never
/// returns. Tracks chosen before preparation avoid both.
///
/// A null list keeps MDK's default for that type. An empty list disables the
/// type.
///
/// ```dart
/// // Plays without embedded subtitles from the start.
/// await const FvpInitialTracks(subtitle: []).run(controller.initialize);
/// ```
///
/// It composes with `FvpCreateCancellation.run`:
/// `cancellation.run(() => tracks.run(controller.initialize))`.
class FvpInitialTracks {
  const FvpInitialTracks({this.audio, this.video, this.subtitle});

  final List<int>? audio;
  final List<int>? video;
  final List<int>? subtitle;

  Future<T> run<T>(Future<T> Function() action) =>
      runZoned(action, zoneValues: {_initialTracksZoneKey: this});
}

FvpInitialTracks? get currentFvpInitialTracks =>
    Zone.current[_initialTracksZoneKey] as FvpInitialTracks?;
