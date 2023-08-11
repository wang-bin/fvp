// Copyright 2022 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'generated_bindings.dart';

import 'lib.dart';

class CodecParameters {
  var codec = '';
  var tag = 0;
  Uint8List? extra; /* without padding data */
}

class StreamInfo {
  int index = 0;
  int startTime = 0; // ms
  int duration = 0;  // ms
  int frames = 0;
  var metadata = <String, String>{};
}

class AudioCodecParameters extends CodecParameters {
  int bitRate = 0;
  int profile = 0;
  int level = 0;
  double frameRate = 0;
  bool isFloat = false;
  bool isUnsigned = false;
  bool isPlanar = false;
  int rawSampleSize = 0;
  int channels = 0;
  int sampleRate = 0;
  int blockAlign = 0;
  int frameSize = 0;

  AudioCodecParameters();

  AudioCodecParameters._from(mdkAudioCodecParameters cp) {
    codec = cp.codec.cast<Utf8>().toDartString();
    tag = cp.codec_tag;
    extra = cp.extra_data.asTypedList(cp.extra_data_size); // view
    bitRate = cp.bit_rate;
    profile = cp.profile;
    level = cp.level;
    frameRate = cp.frame_rate;
    isFloat = cp.is_float;
    isUnsigned = cp.is_unsigned;
    isPlanar = cp.is_planar;
    rawSampleSize = cp.raw_sample_size;
    channels = cp.channels;
    sampleRate = cp.sample_rate;
    blockAlign = cp.block_align;
    frameSize = cp.frame_size;
  }

  @override
  String toString() {
    return 'AudioCodecParameters(codec: $codec, tag: $tag, profile: $profile, level: $level, bitRate: $bitRate, isFloat: $isFloat, isUnsigned: $isUnsigned, isPlanar: $isPlanar, channels: $channels @${sampleRate}Hz, blockAlign: $blockAlign, frameSize: $frameSize)';
  }
}

class AudioStreamInfo extends StreamInfo {
  var codec = AudioCodecParameters();

  AudioStreamInfo();
  AudioStreamInfo._from(Pointer<mdkAudioStreamInfo> pcsi) {
    final csi = pcsi.ref;
    index = csi.index;
    startTime = csi.start_time;
    duration = csi.duration;
    frames = csi.frames;
    var pcc = calloc<mdkAudioCodecParameters>();
    Libmdk.instance.MDK_AudioStreamCodecParameters(pcsi, pcc);
    codec = AudioCodecParameters._from(pcc.ref);
    calloc.free(pcc);
    var entry = calloc<mdkStringMapEntry>();
    while (Libmdk.instance.MDK_AudioStreamMetadata(pcsi, entry)) {
      try {
        metadata[entry.ref.key.cast<Utf8>().toDartString()] = entry.ref.value.cast<Utf8>().toDartString();
      // ignore: empty_catches
      } catch (e) {
      }
    }
    calloc.free(entry);
  }

  @override
  String toString() {
    return 'AudioStreamInfo(#$index, range: $startTime + ${duration}ms, frames: $frames\nmetadata: $metadata\n$codec)';
  }
}

class VideoCodecParameters extends CodecParameters {
  var bitRate = 0;
  var profile = 0;
  var level = 0;
  double frameRate = 0;
  var format = 0;
  String? formatName;
  var width = 0;
  var height = 0;
  var bFrames = 0;

  VideoCodecParameters();

  VideoCodecParameters._from(mdkVideoCodecParameters cp) {
    codec = cp.codec.cast<Utf8>().toDartString();
    tag = cp.codec_tag;
    extra = cp.extra_data.asTypedList(cp.extra_data_size); // view
    bitRate = cp.bit_rate;
    profile = cp.profile;
    level = cp.level;
    frameRate = cp.frame_rate;
    format = cp.format;
    if (cp.format_name != nullptr) {
      formatName = cp.format_name.cast<Utf8>().toDartString();
    }
    width = cp.width;
    height = cp.height;
    bFrames = cp.b_frames;
  }

  @override
  String toString() {
    return 'VideoCodecParameters(codec: $codec, tag: $tag, profile: $profile, level: $level, bitRate: $bitRate, ${width}x$height, ${frameRate}fps, format: $formatName, bFrames:$bFrames)';
  }
}

class VideoStreamInfo extends StreamInfo {
  var rotation = 0;
  var codec = VideoCodecParameters();

  VideoStreamInfo();
  VideoStreamInfo._from(Pointer<mdkVideoStreamInfo> pcsi) {
    final csi = pcsi.ref;
    index = csi.index;
    startTime = csi.start_time;
    duration = csi.duration;
    frames = csi.frames;
    rotation = csi.rotation;
    var pcc = calloc<mdkVideoCodecParameters>();
    Libmdk.instance.MDK_VideoStreamCodecParameters(pcsi, pcc);
    codec = VideoCodecParameters._from(pcc.ref);
    calloc.free(pcc);
    var entry = calloc<mdkStringMapEntry>();
    while (Libmdk.instance.MDK_VideoStreamMetadata(pcsi, entry)) {
      try {
        metadata[entry.ref.key.cast<Utf8>().toDartString()] = entry.ref.value.cast<Utf8>().toDartString();
      // ignore: empty_catches
      } catch (e) {
      }
    }
    calloc.free(entry);
  }

  @override
  String toString() {
    return 'VideoStreamInfo(#$index, range: $startTime + ${duration}ms, frames: $frames, rotation: $rotation\nmetadata: $metadata\n$codec)';
  }
}

class SubtitleCodecParameters extends CodecParameters {
  var width = 0;
  var height = 0;

  SubtitleCodecParameters();

  SubtitleCodecParameters._from(mdkSubtitleCodecParameters cp) {
    codec = cp.codec.cast<Utf8>().toDartString();
    tag = cp.codec_tag;
    extra = cp.extra_data.asTypedList(cp.extra_data_size); // view
    width = cp.width;
    height = cp.height;
  }

  @override
  String toString() {
    return 'SubtitleCodecParameters(codec: $codec, tag: $tag, ${width}x$height)';
  }
}

class SubtitleStreamInfo extends StreamInfo {
  var codec = SubtitleCodecParameters();

  SubtitleStreamInfo();
  SubtitleStreamInfo._from(Pointer<mdkSubtitleStreamInfo> pcsi) {
    final csi = pcsi.ref;
    index = csi.index;
    startTime = csi.start_time;
    duration = csi.duration;
    var pcc = calloc<mdkSubtitleCodecParameters>();
    Libmdk.instance.MDK_SubtitleStreamCodecParameters(pcsi, pcc);
    codec = SubtitleCodecParameters._from(pcc.ref);
    calloc.free(pcc);
    var entry = calloc<mdkStringMapEntry>();
    while (Libmdk.instance.MDK_SubtitleStreamMetadata(pcsi, entry)) {
      try {
        metadata[entry.ref.key.cast<Utf8>().toDartString()] = entry.ref.value.cast<Utf8>().toDartString();
      // ignore: empty_catches
      } catch (e) {
      }
    }
    calloc.free(entry);
  }

  @override
  String toString() {
    return 'SubtitleStreamInfo(#$index, range: $startTime + ${duration}ms, frames: $frames\nmetadata: $metadata\n$codec)';
  }
}

class ChapterInfo {
  var startTime = 0;
  var endTime = 0;
  String? title; // null if no title

  ChapterInfo();
  ChapterInfo._from(mdkChapterInfo ci) {
    startTime = ci.start_time;
    endTime = ci.end_time;
    if (ci.title != nullptr) {
      title = ci.title.cast<Utf8>().toDartString();
    }
  }

  @override
  String toString() {
    var s = 'ChapterInfo(range: $startTime ~ ${endTime}ms';
    if (title != null) s += ', title: $title';
    return '$s)';
  }
}

class ProgramInfo {
  var id = 0;
  var stream = <int>[];
  var metadata = <String,String>{};

  ProgramInfo();
  ProgramInfo._from(Pointer<mdkProgramInfo> ppi) {
    final pi = ppi.ref;
    id = pi.id;
    for (int i = 0; i < pi.nb_stream; ++i) {
      stream.add(pi.stream[i]);
    }
    var entry = calloc<mdkStringMapEntry>();
    while (Libmdk.instance.MDK_ProgramMetadata(ppi, entry)) {
      try {
        metadata[entry.ref.key.cast<Utf8>().toDartString()] = entry.ref.value.cast<Utf8>().toDartString();
      // ignore: empty_catches
      } catch (e) {
      }
    }
    calloc.free(entry);
  }

  @override
  String toString() {
    return 'ProgramInfo(id: $id, streams: $stream, metadata: $metadata)';
  }
}

class MediaInfo {
  var startTime = 0; // ms
  var duration = 0;
  var bitRate = 0;
  String? format;
  var streams = 0;
  var metadata = <String,String>{};
  List<AudioStreamInfo>? audio;
  List<VideoStreamInfo>? video;
  List<SubtitleStreamInfo>? subtitle;
  List<ChapterInfo>? chapters;
  List<ProgramInfo>? programs;


  @override
  String toString() {
    var s = 'MediaInfo(range: $startTime + ${duration}ms, bitRate: $bitRate, format: $format, streams: $streams\nmetadata: $metadata';
    if (audio != null) s += '\n$audio';
    if (video != null) s += '\n$video';
    if (subtitle != null) s += '\n$subtitle';
    if (chapters != null) s += '\n$chapters';
    if (programs != null) s += '\n$programs';
    return '$s)';
  }

  MediaInfo();

  MediaInfo.from(Pointer<mdkMediaInfo> pci) {
    final ci = pci.ref;
    startTime = ci.start_time;
    duration = ci.duration;
    bitRate = ci.bit_rate;
    if (ci.format != nullptr) {
      format = ci.format.cast<Utf8>().toDartString();
    }
    streams = ci.streams;

    var entry = calloc<mdkStringMapEntry>();
    while (Libmdk.instance.MDK_MediaMetadata(pci, entry)) {
      try {
        metadata[entry.ref.key.cast<Utf8>().toDartString()] = entry.ref.value.cast<Utf8>().toDartString();
      // ignore: empty_catches
      } catch (e) {
      }
    }
    calloc.free(entry);

    if (ci.nb_audio > 0) {
      audio = <AudioStreamInfo>[];
      for (int i = 0; i < ci.nb_audio; ++i) {
        final cci = ci.audio.elementAt(i);
        audio!.add(AudioStreamInfo._from(cci));
      }
    }
    if (ci.nb_video > 0) {
      video = <VideoStreamInfo>[];
      for (int i = 0; i < ci.nb_video; ++i) {
        final cci = ci.video.elementAt(i);
        video!.add(VideoStreamInfo._from(cci));
      }
    }
    if (ci.nb_subtitle > 0) {
      subtitle = <SubtitleStreamInfo>[];
      for (int i = 0; i < ci.nb_subtitle; ++i) {
        final cci = ci.subtitle.elementAt(i);
        subtitle!.add(SubtitleStreamInfo._from(cci));
      }
    }
    if (ci.nb_chapters > 0) {
      chapters = <ChapterInfo>[];
      for (int i = 0; i < ci.nb_chapters; ++i) {
        chapters!.add(ChapterInfo._from(ci.chapters[i]));
      }
    }
    if (ci.nb_programs > 0) {
      programs = <ProgramInfo>[];
      for (int i = 0; i < ci.nb_programs; ++i) {
        programs!.add(ProgramInfo._from(ci.programs.elementAt(i)));
      }
    }
  }
}
