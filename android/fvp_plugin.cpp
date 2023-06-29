/*
 * Copyright (c) 2023 WangBin <wbsecg1 at gmail.com>
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

using namespace std;

class TexturePlayer final : public mdk::Player
{
public:
    TexturePlayer(jlong handle)
        : mdk::Player(reinterpret_cast<mdkPlayerAPI*>(handle))
    {
    }

    ~TexturePlayer() override {
    }

    int width = 0;
    int height = 0;
private:
};

static unordered_map<int64_t, shared_ptr<TexturePlayer>> players;


extern "C" {

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {

    mdk::SetGlobalOption("profiler.gpu", 1);

    clog << "JNI_OnLoad" << endl;
    JNIEnv *env = nullptr;
    if (vm->GetEnv((void **) &env, JNI_VERSION_1_4) != JNI_OK || !env) {
        clog << "GetEnv for JNI_VERSION_1_4 failed" << endl;
        return -1;
    }

    mdk::SetGlobalOption("JavaVM", vm);
    return JNI_VERSION_1_4;
}

void JNI_OnUnload(JavaVM *vm, void *reserved) {
    clog << "JNI_OnUnload" << endl;
}
}

extern "C"
JNIEXPORT void JNICALL
Java_com_mediadevkit_fvp_FvpPlugin_nativeSetSurface(JNIEnv *env, jobject thiz, jlong player_handle,
                                                    jlong tex_id, jobject surface, jint w, jint h) {
    if (!player_handle) {
        if (auto it = players.find(tex_id); it != players.end()) {
            auto& player = it->second;
            player->updateNativeSurface(nullptr);
            players.erase(it);
        }
        return;
    }
    assert(surface && "null surface");
    auto player = make_shared<TexturePlayer>(player_handle);
    player->updateNativeSurface(surface, w, h);
    players[tex_id] = player;
}