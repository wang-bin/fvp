import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'src/global.dart' as mdk;
import 'src/player.dart' as mdk;
import 'fvp_platform_interface.dart';

class MdkVideoPlayer extends VideoPlayerPlatform {

  final _players = <int, mdk.Player>{};

  /// Registers this class as the default instance of [VideoPlayerPlatform].
  static void registerWith() {
    VideoPlayerPlatform.instance = MdkVideoPlayer();
  }

  @override
  Future<void> init() {
  }

  @override
  Future<void> dispose(int textureId) {
    final p = _players[textureId];
    if (p == null)
      return;
    FvpPlatform.instance.releaseTexture(p.nativeHandle, textureId);
    _players.remove(textureId);
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    String? asset;
    String? packageName;
    String? uri;
    String? formatHint;
    Map<String, String> httpHeaders = <String, String>{};
    switch (dataSource.sourceType) {
      case DataSourceType.asset:
        asset = dataSource.asset;
        packageName = dataSource.package;
        break;
      case DataSourceType.network:
        uri = dataSource.uri;
        formatHint = _videoFormatStringMap[dataSource.formatHint];
        httpHeaders = dataSource.httpHeaders;
        break;
      case DataSourceType.file:
        uri = dataSource.uri;
        break;
      case DataSourceType.contentUri:
        uri = dataSource.uri;
        break;
    }

    final player = mdk.Player();
    player.media = uri!;
    final tex = await FvpPlatform.instance.createTexture(player.nativeHandle);
    _players[tex] = player;
    return tex;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) {
    final player = _players[textureId];
    if (player != null) {
      player.loop = looping ? -1 : 0;
    }
  }

  @override
  Future<void> play(int textureId) {
    final player = _players[textureId];
    if (player != null) {
      player.state = mdk.State.playing;
    }
  }

  @override
  Future<void> pause(int textureId) {
    final player = _players[textureId];
    if (player != null) {
      player.state = mdk.State.paused;
    }
  }

  @override
  Future<void> setVolume(int textureId, double volume) {
    final player = _players[textureId];
    if (player != null) {
      player.volume = volume;
    }
  }

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) {
    final player = _players[textureId];
    if (player != null) {
      player.playbackRate = speed;
    }
  }

  @override
  Future<void> seekTo(int textureId, Duration position) {
    final player = _players[textureId];
    if (player != null) {
      player.seek(position: position.inMilliseconds, flags: const mdk.SeekFlag(mdk.SeekFlag.fromStart|mdk.SeekFlag.inCache));
    }
  }

  @override
  Future<Duration> getPosition(int textureId) async {
    final player = _players[textureId]!;
    return Duration(milliseconds: player.position);
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    // TODO:
    return VideoEvent(eventType: VideoEventType.unknown);
  }

  @override
  Widget buildView(int textureId) {
    return Texture(textureId: textureId);
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) {
  }

}
