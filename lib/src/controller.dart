// ignore_for_file: invalid_use_of_visible_for_testing_member

// see https://github.com/ardera/flutter_packages/blob/main/packages/flutterpi_gstreamer_video_player/lib/src/controller.dart
import 'dart:typed_data';

import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'media_info.dart'
    if (dart.library.js_interop) 'media_info_dummy.dart'
    if (dart.library.html) 'media_info_dummy.dart';
import 'video_player_mdk.dart'
    if (dart.library.js_interop) 'video_player_dummy.dart'
    if (dart.library.html) 'video_player_dummy.dart';

MdkVideoPlayerPlatform get _platform {
  if (VideoPlayerPlatform.instance is! MdkVideoPlayerPlatform) {
    throw StateError(
      '`VideoPlayerPlatform.instance` have to be of `MdkVideoPlayerPlatform` to use advanced video player features.'
      'Make sure you\'ve called `fvp.registerWith()`',
    );
  }
  return VideoPlayerPlatform.instance as MdkVideoPlayerPlatform;
}

/// Advanced features for [VideoPlayerController].
///
/// All methods in this extension must be called after initialized, otherwise no effect.
extension FVPControllerExtensions on VideoPlayerController {
  /// Indicates whether current media is a live stream or not
  bool isLive() {
    return _platform.isLive(textureId);
  }

  /// Get current media info.
  MediaInfo? getMediaInfo() {
    return _platform.getMediaInfo(textureId);
  }

  /// set additional properties
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setpropertyconst-stdstring-key-const-stdstring-value
  void setProperty(String name, String value) {
    _platform.setProperty(textureId, name, value);
  }

  /// Change video decoder list on the fly.
  /// NOTE: the default decoder list used by [VideoPlayerController] constructor MUST set via [registerWith].
  /// Detail: https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setdecodersmediatype-type-const-stdvectorstdstring-names
  void setVideoDecoders(List<String> value) {
    _platform.setVideoDecoders(textureId, value);
  }

  /// Start to record if [to] is not null. Stop recording if [to] is null.
  /// [to] can be a local file, or are network stream, for example rtmp.
  /// If not stopped by user, recording will be stopped when playback is finished.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-recordconst-char-url--nullptr-const-char-format--nullptr
  void record({String? to, String? format}) {
    _platform.record(textureId, to: to, format: format);
  }

  /// Take a snapshot for current rendered frame.
  ///
  /// [width] snapshot width. if not set, result is `mediaInfo.video[current_track].codec.width`
  /// [height] snapshot height. if not set, result is `mediaInfo.video[current_track].codec.height`
  /// Return rgba data of image size [width]x[height], stride is `width*4`
  Future<Uint8List?> snapshot({int? width, int? height}) async {
    return _platform.snapshot(textureId, width: width, height: height);
  }

  /// Set position range in milliseconds. Can be used by A-B loop.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setrangeint64_t-a-int64_t-b--int64_max
  void setRange({required int from, int to = -1}) {
    _platform.setRange(textureId, from: from, to: to);
  }

  /// Set duration range(milliseconds) of buffered data.
  ///
  /// [min] default 1000. wait for buffered duration >= [min]
  ///   If [min] < 0, then [min], [max] and [drop] will be reset to the default value
  /// [max] default 4000. max buffered duration.
  ///   If [max] < 0, then [max] and drop will be reset to the default value
  ///   If [max] == 0, same as INT64_MAX
  /// [drop] = true: drop old non-key frame packets to reduce buffered duration until < [max].
  /// [drop] = false: wait for buffered duration < max before pushing packets
  ///
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setbufferrangeint64_t-minms-int64_t-maxms-bool-drop--false
  /// NOTE: default values are set in [VideoPlayerController] constructor if 'lowLatency' is enabled in [registerWith]
  void setBufferRange({int min = -1, int max = -1, bool drop = false}) {
    _platform.setBufferRange(textureId, min: min, max: max, drop: drop);
  }

  /// fast seek to a key frame
  Future<void> fastSeekTo(Duration position) async {
    return _platform.fastSeekTo(textureId, position);
  }

  /// Step forward or backward.
  /// Step forward if [frames] > 0, backward otherwise.
  Future<void> step({int frames = 1}) async {
    return _platform.step(textureId, frames);
  }

  /// set brightness. -1 <= [value] <= 1
  void setBrightness(double value) {
    _platform.setBrightness(textureId, value);
  }

  /// set contrast. -1 <= [value] <= 1
  void setContrast(double value) {
    _platform.setContrast(textureId, value);
  }

  /// set hue. -1 <= [value] <= 1
  void setHue(double value) {
    _platform.setHue(textureId, value);
  }

  /// set saturation. -1 <= [value] <= 1
  void setSaturation(double value) {
    _platform.setSaturation(textureId, value);
  }

  /// Set active audio tracks. Other tracks will be disabled.
  /// The tracks can be from data source from [VideoPlayerController] constructor, or an external audio data source via [setExternalAudio]
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setactivetracksmediatype-type-const-stdsetint-tracks
  void setAudioTracks(List<int> value) {
    _platform.setAudioTracks(textureId, value);
  }

  /// Get active audio tracks.
  List<int>? getActiveAudioTracks() {
    return _platform.getActiveAudioTracks(textureId);
  }

  /// Set active video tracks. Other tracks will be disabled.
  /// The tracks can be from data source from [VideoPlayerController] constructor, or an external video data source via [setExternalVideo]
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setactivetracksmediatype-type-const-stdsetint-tracks
  void setVideoTracks(List<int> value) {
    _platform.setVideoTracks(textureId, value);
  }

  /// Get active video tracks.
  List<int>? getActiveVideoTracks() {
    return _platform.getActiveVideoTracks(textureId);
  }

  /// Set active subtitle tracks. Other tracks will be disabled.
  /// The tracks can be from data source from [VideoPlayerController] constructor, or an external subtitle data source via [setExternalSubtitle]
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setactivetracksmediatype-type-const-stdsetint-tracks
  void setSubtitleTracks(List<int> value) {
    _platform.setSubtitleTracks(textureId, value);
  }

  /// Get active subtitle tracks.
  List<int>? getActiveSubtitleTracks() {
    return _platform.getActiveSubtitleTracks(textureId);
  }

  /// set an external audio data source
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setmediaconst-char-url-mediatype-type
  void setExternalAudio(String uri) {
    _platform.setExternalAudio(textureId, uri);
  }

  /// set an external video data source
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setmediaconst-char-url-mediatype-type
  void setExternalVideo(String uri) {
    _platform.setExternalVideo(textureId, uri);
  }

  /// set an external subtitle data source
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setmediaconst-char-url-mediatype-type
  void setExternalSubtitle(String uri) {
    _platform.setExternalSubtitle(textureId, uri);
  }
}
