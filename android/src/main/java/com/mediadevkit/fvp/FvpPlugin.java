/*
 * Copyright (c) 2023 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package com.mediadevkit.fvp;

import android.graphics.SurfaceTexture;
import android.util.Log;
import android.view.Surface;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.view.TextureRegistry;
import io.flutter.view.TextureRegistry.SurfaceTextureEntry;

/** FvpPlugin */
public class FvpPlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  // https://api.flutter.dev/javadoc/io/flutter/view/TextureRegistry.html
  private TextureRegistry texRegistry;
  private Map<Long, SurfaceTextureEntry> textures;
  private Map<Long, Surface> surfaces;
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "fvp");
    channel.setMethodCallHandler(this);
    texRegistry = flutterPluginBinding.getTextureRegistry();
    textures = new HashMap<>();
    surfaces = new HashMap<>();
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("CreateRT")) {
      final Number h = call.argument("player");  // directly cast to long: java.lang.Integer cannot be cast to java.lang.Long
      final long handle = h.longValue();
      final int width = (int)call.argument("width");
      final int height = (int)call.argument("height");
      final boolean tunnel = (boolean)call.argument("tunnel");
      SurfaceTextureEntry te = texRegistry.createSurfaceTexture();
      SurfaceTexture tex = te.surfaceTexture();
      tex.setDefaultBufferSize(width, height); // TODO: size from player. rotate, fullscreen change?
      Surface surface = new Surface(tex); // TODO: when to release
      long texId = te.id();
      nativeSetSurface(handle, texId, surface, width, height, tunnel);
      textures.put(texId, te);
      surfaces.put(texId, surface);
      result.success(texId);
    } else if (call.method.equals("ReleaseRT")) {
      final int texId = call.argument("texture"); // 32bit int, 0, 1, 2 .... but SurfaceTexture.id() is long
      final long texId64 = texId; // MUST cast texId to long, otherwise remove() error
      nativeSetSurface(0, texId, null, -1, -1, false);
      SurfaceTextureEntry te = textures.get(texId64);
      if (te == null) {
        Log.w("FvpPlugin", "onMethodCall: ReleaseRT texId not found: " + texId);
      } else {
        te.release();
      }
      if (textures.remove(texId64) == null) {
      }
      if (surfaces.remove(texId64) == null) {
      }
      Log.w("FvpPlugin", "onMethodCall: ReleaseRT texId: " + texId + ", surfaces: " + surfaces.size() + " textures: " + textures.size());
      result.success(null);
    } else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    Log.i("FvpPlugin", "onDetachedFromEngine: ");
    for (long texId : textures.keySet()) { nativeSetSurface(0, texId, null, -1, -1, false);}
    surfaces = null;
    textures = null;
  }

  /*!
    \param playerHandle null to destroy
    \param texId
   */
  private native void nativeSetSurface(long playerHandle, long texId, Surface surface, int w, int h, boolean tunnel);

  static {
    try {
        System.loadLibrary("fvp_plugin");
    } catch (UnsatisfiedLinkError e) {
        Log.w("FvpPlugin", "static initializer: loadLibrary fvp_plugin error: " + e);
    }
  }
}
