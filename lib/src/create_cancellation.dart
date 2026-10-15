// Copyright 2022-2026 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';

final Object _createCancellationZoneKey = Object();

/// An FVP player creation was cancelled before initialization finished.
class FvpCreateCancelledException extends PlatformException {
  FvpCreateCancelledException()
      : super(
            code: 'creation cancelled',
            message: 'FVP player creation cancelled');
}

/// Cancels an FVP player creation that is still waiting for MDK preparation.
///
/// Run `VideoPlayerController.initialize()` inside [run] and call [cancel]
/// before disposing the controller. Without this opt-in scope, disposal still
/// waits for pending MDK preparation.
///
/// Cancelling completes [run] immediately with [FvpCreateCancelledException].
/// Initialization may report the same error later through video_player; await
/// `controller.dispose()` to wait for native teardown.
/// Native teardown waits for any texture allocation already in flight.
///
/// ```dart
/// final cancellation = FvpCreateCancellation();
/// Future<void> initialize() async {
///   try {
///     await cancellation.run(controller.initialize);
///   } on FvpCreateCancelledException {
///     // The controller was replaced or disposed.
///   }
/// }
///
/// Future<void> dispose() async {
///   cancellation.cancel();
///   await controller.dispose();
/// }
/// ```
class FvpCreateCancellation {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  Future<T> run<T>(Future<T> Function() action) => runZoned(
        () => Future.any<T>([
          Future.sync(action),
          whenCancelled.then<T>((_) => throw FvpCreateCancelledException()),
        ]),
        zoneValues: {_createCancellationZoneKey: this},
      );

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

FvpCreateCancellation? get currentFvpCreateCancellation =>
    Zone.current[_createCancellationZoneKey] as FvpCreateCancellation?;
