
import 'dart:ffi';
import 'dart:ui';

import 'package:ffi/ffi.dart';

import 'generated_bindings.dart';
import 'lib.dart';

// TODO: generate by ffi
const double timestampEOS = 1.7976931348623157e+308;

const double timeScaleForInt = 1000.0;

const double ignoreAspectRatio = 0.0;

const double keepAspectRatio = 1.1920928955078125e-7;

const double keepAspectRatioCrop = -1.1920928955078125e-7;

typedef CallbackToken = MDK_CallbackToken;

enum MediaType {
  unknown(MDK_MediaType.MDK_MediaType_Unknown),
  video(MDK_MediaType.MDK_MediaType_Video),
  audio(MDK_MediaType.MDK_MediaType_Audio),
  subtitle(MDK_MediaType.MDK_MediaType_Subtitle);

  final int rawValue;
  const MediaType(this.rawValue);
}

class MediaStatus {
  static const noMedia =    MDK_MediaStatus.MDK_MediaStatus_NoMedia;
  static const unloaded =   MDK_MediaStatus.MDK_MediaStatus_Unloaded;
  static const loading =    MDK_MediaStatus.MDK_MediaStatus_Loading;
  static const loaded =     MDK_MediaStatus.MDK_MediaStatus_Loaded;
  static const prepared =   MDK_MediaStatus.MDK_MediaStatus_Prepared;
  static const stalled =    MDK_MediaStatus.MDK_MediaStatus_Stalled;
  static const buffering =  MDK_MediaStatus.MDK_MediaStatus_Buffering;
  static const buffered =   MDK_MediaStatus.MDK_MediaStatus_Buffered;
  static const end =        MDK_MediaStatus.MDK_MediaStatus_End;
  static const seeking =    MDK_MediaStatus.MDK_MediaStatus_Seeking;
  static const invalid =    MDK_MediaStatus.MDK_MediaStatus_Invalid;

  final int rawValue;
  const MediaStatus(this.rawValue);

  bool test(int s) {
    return (rawValue & s) != 0;
  }

  @override
  String toString() {
    var s = 'MediaStatus(';
    if (rawValue == 0) s += 'noMedia';
    if (test(unloaded)) s += '+unloaded';
    if (test(loading)) s += '+loading';
    if (test(loaded)) s += '+loaded';
    if (test(prepared)) s += '+prepared';
    if (test(stalled)) s += '+stalled';
    if (test(buffering)) s += '+buffering';
    if (test(buffered)) s += '+buffered';
    if (test(end)) s += '+end';
    if (test(invalid)) s += '+invalid';
    return '$s)';
  }
}

enum State {
  notRunning(MDK_State.MDK_State_NotRunning),
  stopped(MDK_State.MDK_State_Stopped),
  running(MDK_State.MDK_State_Running),
  playing(MDK_State.MDK_State_Playing),
  paused(MDK_State.MDK_State_Paused),
  ;

  final int rawValue;
  const State(this.rawValue);

  factory State.from(int i) {
    const states = [
            State.stopped,
            State.playing,
            State.paused,
          ];
    return states[i];
  }
}

class SeekFlag {
  static const from0      = MDKSeekFlag.MDK_SeekFlag_From0;
  static const fromStart  = MDKSeekFlag.MDK_SeekFlag_FromStart;
  static const fromNow    = MDKSeekFlag.MDK_SeekFlag_FromNow;
  static const frame      = MDKSeekFlag.MDK_SeekFlag_Frame;
  static const keyFrame   = MDKSeekFlag.MDK_SeekFlag_KeyFrame;
  static const fast       = MDKSeekFlag.MDK_SeekFlag_Fast;
  static const inCache    = MDKSeekFlag.MDK_SeekFlag_InCache;
  static const defaultFlags  = MDKSeekFlag.MDK_SeekFlag_Default;

  final int rawValue;
  const SeekFlag(this.rawValue);

  bool test(int s) {
    return (rawValue & s) != 0;
  }

  @override
  String toString() {
    var s = 'SeekFlag(';
    if (test(from0)) s += '+from0';
    if (test(fromStart)) s += '+fromStart';
    if (test(fromNow)) s += '+fromNow';
    if (test(frame)) s += '+frame';
    if (test(keyFrame)) s += '+keyFrame';
    if (test(inCache)) s += '+inCache';
    return '$s)';
  }
}

enum VideoEffect {
  brightness(MDK_VideoEffect.MDK_VideoEffect_Brightness),
  contrast(MDK_VideoEffect.MDK_VideoEffect_Contrast),
  hue(MDK_VideoEffect.MDK_VideoEffect_Hue),
  saturation(MDK_VideoEffect.MDK_VideoEffect_Saturation),
  ;

  final int rawValue;
  const VideoEffect(this.rawValue);
}

enum ColorSpace {
  unknown(MDK_ColorSpace.MDK_ColorSpace_Unknown),
  bt709(MDK_ColorSpace.MDK_ColorSpace_BT709),
  bt2100PQ(MDK_ColorSpace.MDK_ColorSpace_BT2100_PQ),
  ;

  final int rawValue;
  const ColorSpace(this.rawValue);
}

enum LogLevel {
  off(MDK_LogLevel.MDK_LogLevel_Off),
  error(MDK_LogLevel.MDK_LogLevel_Error),
  warning(MDK_LogLevel.MDK_LogLevel_Warning),
  info(MDK_LogLevel.MDK_LogLevel_Info),
  debug(MDK_LogLevel.MDK_LogLevel_Debug),
  all(MDK_LogLevel.MDK_LogLevel_All),
  ;

  final int rawValue;
  const LogLevel(this.rawValue);
}

class MediaEvent {
  final int error;
  final String category;
  final String detail;

  const MediaEvent(this.error, this.category, this.detail);
}

int version() => Libmdk.instance.MDK_version();

void setLogHandler(void Function(LogLevel, String) cb) {
// TODO: global log isolate, in Libmdk.instance?
}

void setGlobalOption<T>(String name, T value) {
  final k = name.toNativeUtf8();
  if (value is String) { // T == String
    final v = value.toNativeUtf8();
    Libmdk.instance.MDK_setGlobalOptionString(k.cast(), v.cast());
    malloc.free(v);
  } else if (value is int) {
    Libmdk.instance.MDK_setGlobalOptionInt32(k.cast(), value);
  } else if (value is bool) {
    Libmdk.instance.MDK_setGlobalOptionInt32(k.cast(), value ? 1 : 0);
  }
  malloc.free(k);
}
/*
T? getGlobalOption<T>(String name) {
  final k = name.toNativeUtf8();
  if (T == String) {
    String? ret;
    final p = calloc<Pointer<Char>>();
    final found = Libmdk.instance.MDK_getGlobalOptionString(k.cast(), p.cast());
    malloc.free(k);
    if (found) {
      ret = p.value.cast<Utf8>().toDartString();
    }
    calloc.free(p);
    return ret;
  }
}
*/