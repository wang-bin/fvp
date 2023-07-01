// Copyright 2022 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:logging/logging.dart';

import 'src/global.dart' as mdk;
import 'src/player.dart' as mdk;
import 'src/fvp_platform_interface.dart';

class MdkVideoPlayer extends VideoPlayerPlatform {

  static final _players = <int, mdk.Player>{};
  static final _streamCtl = <int, StreamController<VideoEvent>>{};
  static dynamic _options;
  final _log = Logger('fvp');
  static final _mdkLog = Logger('mdk');

  /// Registers this class as the default instance of [VideoPlayerPlatform].
  static void registerWith({dynamic options}) {
    _options = options;
    _options ??= <String, dynamic>{};
    const vd = {
      'windows': ['MFT:d3d=11', 'CUDA', 'FFmpeg'],
      'macos': ['VT', 'FFmpeg'],
      'ios': ['VT', 'FFmpeg'],
      'linux': ['VAAPI', 'CUDA', 'VDPAU', 'FFmpeg'],
      'android': ['AMediaCodec', 'FFmpeg'],
    };
    if (_options is Map<String, dynamic>) {
      _options.putIfAbsent('video.decoders', () => vd[Platform.operatingSystem]);
    }
    VideoPlayerPlatform.instance = MdkVideoPlayer();

    mdk.setLogHandler((level, msg) {
      if (msg.endsWith('\n')) {
        msg = msg.substring(0, msg.length - 1);
      }
      switch (level) {
      case mdk.LogLevel.error: _mdkLog.severe(msg);
      case mdk.LogLevel.warning: _mdkLog.warning(msg);
      case mdk.LogLevel.info: _mdkLog.info(msg);
      case mdk.LogLevel.debug: _mdkLog.fine(msg);
      case mdk.LogLevel.all: _mdkLog.finest(msg);
      default: return;
      }
    });
  }

  @override
  Future<void> init() async{
  }

  @override
  Future<void> dispose(int textureId) async {
    final p = _players[textureId];
    if (p == null) {
      return;
    }
    // await: ensure player deleted when no use in fvp plugin
    await FvpPlatform.instance.releaseTexture(p.nativeHandle, textureId);
    _players.remove(textureId);
    p.dispose();
    _streamCtl.remove(textureId);
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    String? uri;
    //Map<String, String> httpHeaders = <String, String>{};
    switch (dataSource.sourceType) {
      case DataSourceType.asset:
        uri = _assetUri(dataSource.asset!, dataSource.package);
        break;
      case DataSourceType.network:
        uri = dataSource.uri;
        //httpHeaders = dataSource.httpHeaders;
        break;
      case DataSourceType.file:
        uri = Uri.decodeComponent(dataSource.uri!);
        break;
      case DataSourceType.contentUri:
        uri = dataSource.uri;
        break;
    }
    final player = mdk.Player();
    _log.fine('$hashCode player${player.nativeHandle} create($uri)');
    if (_options is Map<String, dynamic>) {
      player.videoDecoders = _options['video.decoders'];
    }

    final c = Completer<Size?>();
    final sc = _initEvents(player, c);
    player.media = uri!;
    player.prepare(); // required!
    final size = await c.future;
    if (size == null) {
      player.dispose();
      return null;
    }
    final tex = await FvpPlatform.instance.createTexture(player.nativeHandle, size.width.toInt(), size.height.toInt());
    _players[tex] = player;
    _streamCtl[tex] = sc;
    return tex;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {
    final player = _players[textureId];
    if (player != null) {
      player.loop = looping ? -1 : 0;
    }
  }

  @override
  Future<void> play(int textureId) async {
    final player = _players[textureId];
    if (player != null) {
      player.state = mdk.State.playing;
    }
  }

  @override
  Future<void> pause(int textureId) async {
    final player = _players[textureId];
    if (player != null) {
      player.state = mdk.State.paused;
    }
  }

  @override
  Future<void> setVolume(int textureId, double volume) async {
    final player = _players[textureId];
    if (player != null) {
      player.volume = volume;
    }
  }

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {
    final player = _players[textureId];
    if (player != null) {
      player.playbackRate = speed;
    }
  }

  @override
  Future<void> seekTo(int textureId, Duration position) async {
    final player = _players[textureId];
    if (player != null) {
      player.seek(position: position.inMilliseconds, flags: const mdk.SeekFlag(mdk.SeekFlag.fromStart|mdk.SeekFlag.keyFrame|mdk.SeekFlag.inCache));
    }
  }

  @override
  Future<Duration> getPosition(int textureId) async {
    final player = _players[textureId];
    if (player == null) {
      return Duration.zero;
    }
    final sc = _streamCtl[textureId];
    final pos = player.position;
    final bufLen = player.buffered();
    sc?.add(VideoEvent(eventType: VideoEventType.bufferingUpdate
      , buffered: [DurationRange(Duration(microseconds: pos), Duration(milliseconds: pos + bufLen))]));
    return Duration(milliseconds: pos);

  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    var sc = _streamCtl[textureId];
    if (sc != null) {
      return sc.stream;
    }
    throw Exception('No Stream<VideoEvent> for textureId: $textureId.');
  }

  @override
  Widget buildView(int textureId) {
    return Texture(textureId: textureId);
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {
  }

  StreamController<VideoEvent> _initEvents(mdk.Player player, Completer<Size?> completer) {
    final sc = StreamController<VideoEvent>();
    player.onMediaStatusChanged((oldValue, newValue) {
      _log.fine('$hashCode player${player.nativeHandle} onMediaStatusChanged: $oldValue => $newValue');
      if (!oldValue.test(mdk.MediaStatus.loaded) && newValue.test(mdk.MediaStatus.loaded)) {
        final info = player.mediaInfo;
        var size = const Size(0, 0);
        if (info.video != null) {
          final vc = info.video![0].codec;
          size = Size(vc.width.toDouble(), vc.height.toDouble());
        }
        if (!completer.isCompleted) {
          completer.complete(size);
        }
        sc.add(VideoEvent(eventType: VideoEventType.initialized
          , duration: Duration(milliseconds: info.duration == 0 ? double.maxFinite.toInt() : info.duration) // FIXME: live stream info.duraiton == 0 and result a seekTo(0) in play()
          , size: size));
      } else if (!oldValue.test(mdk.MediaStatus.buffering) && newValue.test(mdk.MediaStatus.buffering)) {
        sc.add(VideoEvent(eventType: VideoEventType.bufferingStart));
      } else if (!oldValue.test(mdk.MediaStatus.buffered) && newValue.test(mdk.MediaStatus.buffered)) {
        sc.add(VideoEvent(eventType: VideoEventType.bufferingEnd));
      }
      if (oldValue.test(mdk.MediaStatus.loading) && newValue.test(mdk.MediaStatus.invalid|mdk.MediaStatus.stalled)) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
      return true;
    });

    player.onEvent((ev) {
      _log.fine('$hashCode player${player.nativeHandle} onEvent: ${ev.category} ${ev.error}');
      if (ev.category == "reader.buffering") {
        final pos = player.position;
        final bufLen = player.buffered();
        sc.add(VideoEvent(eventType: VideoEventType.bufferingUpdate
          , buffered: [DurationRange(Duration(microseconds: pos), Duration(milliseconds: pos + bufLen))]));
      }
    });

    player.onStateChanged((oldValue, newValue) {
      _log.fine('$hashCode player${player.nativeHandle} onStateChanged: $oldValue => $newValue');
      sc.add(VideoEvent(eventType: VideoEventType.isPlayingStateUpdate
        , isPlaying: newValue == mdk.State.playing));
    });
    return sc;
  }

  static String _assetUri(String asset, String? package) {
    final key = asset;
    switch (Platform.operatingSystem) {
    case 'windows':
        return path.join(path.dirname(Platform.resolvedExecutable), 'data', 'flutter_assets', key);
    case 'linux':
        return path.join(path.dirname(Platform.resolvedExecutable), 'data', 'flutter_assets', key);
    case 'macos':
        return path.join(path.dirname(Platform.resolvedExecutable), '..', 'Frameworks', 'App.framework', 'Resources', 'flutter_assets', key);
    case 'ios':
        return path.join(path.dirname(Platform.resolvedExecutable), 'Frameworks', 'App.framework', 'flutter_assets', key);
    case 'android':
        return 'assets://flutter_assets/$key';
    }
    return asset;
  }
}
