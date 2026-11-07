// Copyright 2022-2026 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

final Object _audioOnlyZoneKey = Object();

/// Runs controller initialization with Flutter texture creation disabled.
///
/// This is used by [FvpAudioPlayerController]. It is zone-scoped so concurrent
/// initialization of an audio-only controller and a video controller cannot
/// affect each other.
class FvpAudioOnlyScope {
  Future<T> run<T>(Future<T> Function() action) =>
      runZoned(action, zoneValues: {_audioOnlyZoneKey: true});
}

bool get currentFvpAudioOnly => Zone.current[_audioOnlyZoneKey] == true;
