// Copyright 2022 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart'; //
import 'package:path/path.dart' as path;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:logging/logging.dart';

import '../mdk.dart' as mdk;

class MdkVideoPlayer extends VideoPlayerPlatform {

  static final _players = <int, mdk.Player>{};
  static final _streamCtl = <int, StreamController<VideoEvent>>{};
  static dynamic _options;
  static int? _maxWidth;
  static int? _maxHeight;
  static bool? _fitMaxSize;
  static List<String>? _platforms;
  final _log = Logger('fvp');
  static final _mdkLog = Logger('mdk');

/*
  Registers this class as the default instance of [VideoPlayerPlatform].

  [options] can be
  "video.decoders": a list of decoder names. supported decoders: https://github.com/wang-bin/mdk-sdk/wiki/Decoders
  "maxWidth", "maxHeight": texture max size. if not set, video frame size is used. a small value can reduce memory cost, but may result in lower image quality.
 */
  static void registerVideoPlayerPlatformsWith({dynamic options}) {
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
      _platforms = _options["platforms"];
      if (_platforms is List<String>) {
        if (!_platforms!.contains(Platform.operatingSystem)) {
          return;
        }
      }
      _options.putIfAbsent('video.decoders', () => vd[Platform.operatingSystem]!);
      _maxWidth = _options["maxWidth"];
      _maxHeight = _options["maxHeight"];
      _fitMaxSize = _options["fitMaxSize"];
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

  @Deprecated('Use global function registerWith() instead')
  static void registerWith({dynamic options}) {
    registerVideoPlayerPlatformsWith(options: options);
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

    _players.remove(textureId);
    p.dispose();
    _streamCtl.remove(textureId);
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    String? uri;
    switch (dataSource.sourceType) {
      case DataSourceType.asset:
        uri = _assetUri(dataSource.asset!, dataSource.package);
        break;
      case DataSourceType.network:
        uri = dataSource.uri;
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
    if (dataSource.httpHeaders.isNotEmpty) {
      String headers = '';
      dataSource.httpHeaders.forEach((key, value) {
        headers += '$key: $value\r\n';
      });
      player.setProperty('avio.headers', headers);
    }
    final sc = _initEvents(player);
    player.media = uri!;
    player.prepare(); // required!
// FIXME: pending events will be processed after texture returned, but no events before prepared
    final tex = await player.updateTexture(width: _maxWidth, height: _maxHeight, fit: _fitMaxSize);
    if (tex < 0) {
      sc.close();
      player.dispose();
      return null;
    }
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
      player.state = mdk.PlaybackState.playing;
    }
  }

  @override
  Future<void> pause(int textureId) async {
    final player = _players[textureId];
    if (player != null) {
      player.state = mdk.PlaybackState.paused;
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

  StreamController<VideoEvent> _initEvents(mdk.Player player) {
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
        sc.add(VideoEvent(eventType: VideoEventType.initialized
          , duration: Duration(milliseconds: info.duration == 0 ? double.maxFinite.toInt() : info.duration) // FIXME: live stream info.duraiton == 0 and result a seekTo(0) in play()
          , size: size));
      } else if (!oldValue.test(mdk.MediaStatus.buffering) && newValue.test(mdk.MediaStatus.buffering)) {
        sc.add(VideoEvent(eventType: VideoEventType.bufferingStart));
      } else if (!oldValue.test(mdk.MediaStatus.buffered) && newValue.test(mdk.MediaStatus.buffered)) {
        sc.add(VideoEvent(eventType: VideoEventType.bufferingEnd));
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
      _log.fine('$hashCode player${player.nativeHandle} onPlaybackStateChanged: $oldValue => $newValue');
      sc.add(VideoEvent(eventType: VideoEventType.isPlayingStateUpdate
        , isPlaying: newValue == mdk.PlaybackState.playing));
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
