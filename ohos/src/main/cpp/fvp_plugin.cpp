/*
 * Copyright (c) 2025 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#include "include/fvp/fvp_plugin.h"
#include <napi/native_api.h>
#include <native_window/external_window.h>
#include <hilog/log.h>
#include <mdk/Player.h>
#include <iostream>
#include <unordered_map>

using namespace std;

#define FVP_TAG "fvp"
#define FVP_LOG(...) OH_LOG_Print(LOG_APP, LOG_INFO,  0xFF00, FVP_TAG, __VA_ARGS__)
#define FVP_ERR(...) OH_LOG_Print(LOG_APP, LOG_ERROR, 0xFF00, FVP_TAG, __VA_ARGS__)

class TexturePlayer final : public mdk::Player {
public:
    explicit TexturePlayer(int64_t handle)
        : mdk::Player(reinterpret_cast<mdkPlayerAPI*>(handle))
    {}

    int width = 0;
    int height = 0;
    OHNativeWindow* window = nullptr;
};

static unordered_map<int64_t, shared_ptr<TexturePlayer>> players;

// nativeSetSurface(playerHandle: number, texId: number, surfaceId: number, w: number, h: number): void
static napi_value NativeSetSurface(napi_env env, napi_callback_info info)
{
    size_t argc = 5;
    napi_value args[5];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t playerHandle = 0;
    napi_get_value_int64(env, args[0], &playerHandle);

    int64_t texId = 0;
    napi_get_value_int64(env, args[1], &texId);

    int64_t surfaceId = 0;
    napi_get_value_int64(env, args[2], &surfaceId);

    int32_t w = 0, h = 0;
    napi_get_value_int32(env, args[3], &w);
    napi_get_value_int32(env, args[4], &h);

    if (!playerHandle || !surfaceId) {
        if (auto it = players.find(texId); it != players.end()) {
            auto& player = it->second;
            player->updateNativeSurface(nullptr);
            if (player->window) {
                OH_NativeWindow_DestroyNativeWindow(player->window);
                player->window = nullptr;
            }
            players.erase(it);
        } else {
            FVP_LOG("player not found (already removed?) for texId %{public}lld", (long long)texId);
        }
        return nullptr;
    }

    auto player = make_shared<TexturePlayer>(playerHandle);
    player->width = w;
    player->height = h;

    OHNativeWindow* window = nullptr;
    int32_t ret = OH_NativeWindow_CreateNativeWindowFromSurfaceId(static_cast<uint64_t>(surfaceId), &window);
    if (ret != 0 || !window) {
        FVP_ERR("OH_NativeWindow_CreateNativeWindowFromSurfaceId failed: %{public}d", ret);
        return nullptr;
    }

    player->window = window;
    player->updateNativeSurface(window, w, h);
    players[texId] = player;

    return nullptr;
}

static napi_value Init(napi_env env, napi_value exports)
{
    mdk::SetGlobalOption("MDK_KEY", "980B9623276F746C5FBB5EC5120D4A99A0B58B635592EAEE41F6817FDF3B28B96AC4A49866257726C19B246863B5ADAF5D17464E86D72A90634E8AE8418F810967F469DCD8908B93A044A13AEDF2B566E0B5810523E2B59E2D83E616B1B807B66253E1607A79BC86AEDE1AEF46F79AA60F36BE44DDEE47B84E165AF2788F8109");

    mdk::setLogHandler([](mdk::LogLevel level, const char* msg) {
        static const ::LogLevel ohLevel[] = {
            LOG_INFO,  // MDK LogLevel::Off     (0)
            LOG_ERROR, // MDK LogLevel::Error   (1)
            LOG_WARN,  // MDK LogLevel::Warning (2)
            LOG_INFO,  // MDK LogLevel::Info    (3)
            LOG_DEBUG, // MDK LogLevel::Debug   (4)
            LOG_DEBUG, // MDK LogLevel::All     (5)
        };
        const int idx = (int)level < 6 ? (int)level : 0;
        OH_LOG_Print(LOG_APP, ohLevel[idx], 0xFF00, FVP_TAG, "%{public}s", msg);
    });

    napi_property_descriptor desc[] = {
        { "nativeSetSurface", nullptr, NativeSetSurface, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);

    return exports;
}

static napi_module fvpModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "fvp_plugin",
    .nm_priv = nullptr,
    .reserved = {nullptr},
};

extern "C" __attribute__((constructor)) void RegisterFvpPluginModule(void)
{
    napi_module_register(&fvpModule);
}

extern "C" bool MdkIsEmulator()
{
    return false;
}

extern "C" void* MdkGetPlayerVid(int64_t tex_id)
{
    if (tex_id < 0)
        return nullptr;
    if (const auto it = players.find(tex_id); it != players.end()) {
        return it->second->window;
    }
    return nullptr;
}
