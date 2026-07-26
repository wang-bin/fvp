/*
 * Copyright (c) 2023-2026 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#include <jni.h>
#include <android/native_window_jni.h>
#include <android/log.h>
//#include <vulkan/vulkan.h> // before any mdk header
#include <mdk/Player.h>
#include <mdk/MediaInfo.h>
#include <cassert>
#include <unordered_map>
#include <iostream>
#include <sys/system_properties.h>

using namespace std;

class TexturePlayer final : public mdk::Player
{
public:
    TexturePlayer(jlong handle)
        : mdk::Player(reinterpret_cast<mdkPlayerAPI*>(handle))
    {
    }

    int width = 0;
    int height = 0;
    jobject surface = nullptr;
    void* vo_opaque = nullptr; // can change by TextureRegistry.SurfaceProducer.Callback
    bool directSurface = false; // decoder renders into the surface, no GL renderer
private:
};

static unordered_map<int64_t, shared_ptr<TexturePlayer>> players;


extern "C" {

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {
    clog << "JNI_OnLoad" << endl;
    mdk::javaVM(vm);
    mdk::SetGlobalOption("profiler.gpu", 1);

    JNIEnv *env = nullptr;
    if (vm->GetEnv((void **) &env, JNI_VERSION_1_4) != JNI_OK || !env) {
        clog << "GetEnv for JNI_VERSION_1_4 failed" << endl;
        return -1;
    }

    return JNI_VERSION_1_4;
}

void JNI_OnUnload(JavaVM *vm, void *reserved) {
    clog << "JNI_OnUnload" << endl;
}
}

extern "C"
JNIEXPORT void JNICALL
Java_com_mediadevkit_fvp_FvpPlugin_nativeSetSurface(JNIEnv *env, jobject thiz, jlong player_handle,
                                                    jlong tex_id, jobject surface, jint w, jint h, jboolean tunnel) {
    if (!player_handle || !surface) {
        if (auto it = players.find(tex_id); it != players.end()) {
            auto& player = it->second;
            auto s = player->surface;
            if (player->directSurface) {
                // The codec renders into the surface that is about to be
                // destroyed. Detach it BEFORE the surface dies: a MediaCodec
                // left bound to a dead surface wedges (dequeue -10000, "can
                // not return buffer to native window") and the stream is
                // marked decode-error, so the next surface never shows a
                // frame. An empty decoder list releases the codec without
                // opening a replacement — re-opening one here would run a
                // full codec create+configure+start and re-prime the pipeline
                // synchronously, on the UI thread inside surfaceDestroyed
                // (~600ms with a deep buffer). The re-attach below re-opens
                // with the new surface.
                player->setDecoders(mdk::MediaType::Video, {});
            }
            player->updateNativeSurface(nullptr);
            players.erase(it);
            if (s) {
                env->DeleteGlobalRef(s);
            }
        } else {
            clog << "player not found(already removed?) for textureId " + std::to_string(tex_id) + " surface " + std::to_string((intptr_t)surface) << endl;
        }
        return;
    }
    assert(surface && "null surface");
    auto player = make_shared<TexturePlayer>(player_handle);
    clog << __func__ << endl;
    if (tunnel) {
        // Decode straight into the surface: MediaCodec writes into the
        // SurfaceView's (or SurfaceTexture's) buffer queue itself, with no GL
        // renderer, no EGLConfig and no GPU copy in between. image=0 disables
        // the AImageReader (frame readback) path; dv=1 is required for Dolby
        // Vision profile 5 on SDKs where it is not the default.
        //
        // The surface only exists after prepare(), by which point the decoder
        // has already opened without one, so setDecoders forces a re-open with
        // it attached — setting the property alone never took effect, which is
        // why this option did nothing before.
        player->surface = env->NewGlobalRef(surface);
        player->directSurface = true;
        player->setDecoders(mdk::MediaType::Video,
            {"AMediaCodec:dv=1:image=0:surface=" + std::to_string((intptr_t)player->surface)});
    } else {
        player->surface = env->NewGlobalRef(surface);
        player->updateNativeSurface(player->surface, w, h);
        player->vo_opaque = player->surface;
    }
    player->width = w;
    player->height = h;
    players[tex_id] = player;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_mediadevkit_fvp_FvpPlugin_nativeSetSurfaceSize(JNIEnv *env, jobject thiz, jlong tex_id,
                                                        jint w, jint h) {
    auto it = players.find(tex_id);
    if (it == players.end()) {
        return;
    }
    auto& player = it->second;
    player->width = w;
    player->height = h;
    // The decoder owns the buffer geometry in direct mode — the compositor
    // scales its layer to the view, so a resize needs nothing here. The GL
    // renderer draws at the surface size and does need it.
    if (!player->directSurface && player->surface) {
        player->updateNativeSurface(player->surface, w, h);
    }
}

extern "C"
JNIEXPORT bool JNICALL
MdkIsEmulator()
{
    // run getprop to see all properties
    char v[PROP_VALUE_MAX+1];
    __system_property_get("ro.kernel.qemu", v);
    if (atoi(v) == 1)
        return true;
    __system_property_get("ro.boot.qemu", v);
    if (atoi(v) == 1)
        return true;
    __system_property_get("ro.product.board", v);
    if (strstr(v, "goldfish"))
        return true;
    __system_property_get("ro.hardware.egl", v);
    if (strstr(v, "emulation"))
        return true;
    __system_property_get("ro.hardware", v);
    if (strstr(v, "ranchu"))
        return true;
    __system_property_get("ro.build.characteristics", v);
    if (strstr(v, "emulator"))
        return true;
    return false;
}

extern "C"
JNIEXPORT void* JNICALL
MdkGetPlayerVid(int64_t tex_id)
{
    if (tex_id < 0)
        return nullptr;
    if (const auto it = players.find(tex_id); it != players.end()) {
        const auto& player = it->second;
        return player->vo_opaque;
    }
    return nullptr;
}