// Copyright 2022-2026 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// ignore_for_file: use_super_parameters
import 'dart:io';

import 'package:video_player/video_player.dart';

import 'audio_only_scope.dart';

/// A [VideoPlayerController] that plays audio without a Flutter texture.
///
/// Do not render instances of this controller with [VideoPlayer]; it is for
/// audio-only resources such as sound effects and countdown audio.
class FvpAudioPlayerController extends VideoPlayerController {
  FvpAudioPlayerController.file(
    File file, {
    Future<ClosedCaptionFile>? closedCaptionFile,
    VideoPlayerOptions? videoPlayerOptions,
    Map<String, String> httpHeaders = const <String, String>{},
  }) : super.file(
         file,
         closedCaptionFile: closedCaptionFile,
         videoPlayerOptions: videoPlayerOptions,
         httpHeaders: httpHeaders,
       );

  FvpAudioPlayerController.asset(
    String dataSource, {
    String? package,
    Future<ClosedCaptionFile>? closedCaptionFile,
    VideoPlayerOptions? videoPlayerOptions,
  }) : super.asset(
         dataSource,
         package: package,
         closedCaptionFile: closedCaptionFile,
         videoPlayerOptions: videoPlayerOptions,
       );

  FvpAudioPlayerController.networkUrl(
    Uri url, {
    Future<ClosedCaptionFile>? closedCaptionFile,
    VideoPlayerOptions? videoPlayerOptions,
    Map<String, String> httpHeaders = const <String, String>{},
  }) : super.networkUrl(
         url,
         closedCaptionFile: closedCaptionFile,
         videoPlayerOptions: videoPlayerOptions,
         httpHeaders: httpHeaders,
       );

  @override
  Future<void> initialize() {
    return FvpAudioOnlyScope().run(super.initialize);
  }
}
