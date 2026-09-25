// Copyright 2022-2026 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

final Object _createCancellationZoneKey = Object();

/// Cancels an FVP player creation that is still waiting for MDK preparation.
///
/// Run [VideoPlayerController.initialize] inside [run] and call [cancel]
/// before disposing the controller. The scope follows asynchronous Dart work
/// without changing the video_player platform interface. Cancelling also
/// completes the future returned by [run] with an error.
class FvpCreateCancellation {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  Future<T> run<T>(Future<T> Function() action) => runZoned(
        () => Future.any<T>([
          Future.sync(action),
          whenCancelled.then<T>(
              (_) => throw StateError('FVP player creation cancelled')),
        ]),
        zoneValues: {_createCancellationZoneKey: this},
      );

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

FvpCreateCancellation? get currentFvpCreateCancellation =>
    Zone.current[_createCancellationZoneKey] as FvpCreateCancellation?;
