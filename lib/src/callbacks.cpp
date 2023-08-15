// Copyright 2022 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "mdk/Player.h"
#include <condition_variable>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <iostream>
#include <thread>
#include "dart_api_types.h"
#include "callbacks.h"

using namespace std;

class Player final: public mdk::Player
{
public:

    Player(int64_t handle)
        : mdk::Player(reinterpret_cast<mdkPlayerAPI*>(handle))
    {
    }

    int callbackTypes = 0;
    bool reply[int(CallbackType::Count)] = {};
    bool dataReady[int(CallbackType::Count)] = {};
    CallbackReply data[int(CallbackType::Count)];
    mutex mtx[int(CallbackType::Count)];
    condition_variable cv[int(CallbackType::Count)];

    mdk::State oldState = mdk::State::Stopped;
    mdk::MediaStatus oldStatus = mdk::MediaStatus::NoMedia;
};

static unordered_map<int64_t, shared_ptr<Player>> players;

// global callbacks
static int gCallbackTypes = 0;

FVP_EXPORT void MdkCallbacksRegisterPort(int64_t handle, void* post_c_object, int64_t send_port)
{
    const auto postCObject = reinterpret_cast<bool(*)(Dart_Port, Dart_CObject*)>(post_c_object);
    if (!handle) { // global callbacks
        mdk::setLogHandler([=](mdk::LogLevel level, const char* logMsg){
            const auto type = int(CallbackType::Log);
            if (!(gCallbackTypes & (1 << type)))
                return;
            Dart_CObject t{
                .type = Dart_CObject_kInt64,
                .value = {
                    .as_int64 = type,
                }
            };
            Dart_CObject lv{
                .type = Dart_CObject_kInt64,
                .value = {
                    .as_int64 = (int64_t)level,
                }
            };
            Dart_CObject txt{
                .type = Dart_CObject_kString,
                .value = {
                    .as_string = logMsg,
                }
            };
            Dart_CObject* arr[] = { &t, &lv, &txt };
            Dart_CObject msg {
                .type = Dart_CObject_kArray,
                .value = {
                    .as_array = {
                        .length = std::size(arr),
                        .values = arr,
                    },
                },
            };
            if (!postCObject(send_port, &msg)) {
                cout << "postCObject error" << endl; // clog: dead log. why post error?
                return;
            }
        });
        return;
    }
    auto player = make_shared<Player>(handle);
    players[handle] = player;
    const auto tid = this_thread::get_id();

    auto wp = weak_ptr<Player>(player);
    player->onEvent([=](const mdk::MediaEvent& e){
        auto sp = wp.lock();
        if (!sp)
            return false;
        auto p = sp.get();
        const auto type = int(CallbackType::Event);
        if (!(p->callbackTypes & (1 << type)))
            return false;
        Dart_CObject t{
            .type = Dart_CObject_kInt64,
            .value = {
                .as_int64 = type,
            }
        };
        Dart_CObject err{
            .type = Dart_CObject_kInt64,
            .value = {
                .as_int64 = (int64_t)e.error,
            }
        };
        Dart_CObject cat{
            .type = Dart_CObject_kString,
            .value = {
                .as_string = e.category.data(),
            }
        };
        Dart_CObject detail{
            .type = Dart_CObject_kString,
            .value = {
                .as_string = e.detail.data(),
            }
        };
        Dart_CObject* arr[] = { &t, &err, &cat, &detail };
        Dart_CObject msg {
            .type = Dart_CObject_kArray,
            .value = {
                .as_array = {
                    .length = std::size(arr),
                    .values = arr,
                },
            },
        };
        if (!postCObject(send_port, &msg)) {
            clog << "postCObject error" << endl;
            return false;
        }
        return false;
    });

    player->onStateChanged([=](mdk::State s){
        auto sp = wp.lock();
        if (!sp)
            return;
        auto p = sp.get();
        const auto type = int(CallbackType::State);
        const auto oldValue = p->oldState;
        p->oldState = s;
        if (!(p->callbackTypes & (1 << type)))
            return;

        unique_lock lock(p->mtx[type]);
        p->dataReady[type] = false;

        Dart_CObject t{
            .type = Dart_CObject_kInt64,
            .value = {
                .as_int64 = type,
            }
        };
        Dart_CObject v0{
            .type = Dart_CObject_kInt64,
            .value = {
                .as_int64 = (int64_t)oldValue,
            }
        };
        Dart_CObject v1{
            .type = Dart_CObject_kInt64,
            .value = {
                .as_int64 = (int64_t)s,
            }
        };
        Dart_CObject* arr[] = { &t, &v0, &v1 };
        Dart_CObject msg {
            .type = Dart_CObject_kArray,
            .value = {
                .as_array = {
                    .length = std::size(arr),
                    .values = arr,
                },
            }
        };
        if (!postCObject(send_port, &msg)) {
            clog << "postCObject error" << endl;
            return;
        }
        if (!p->reply[type])
            return;
        if (tid == this_thread::get_id()) {// FIXME: can not convert dart non-static function to native function, and dart object has no address, so func(context, args) is impossible too
            clog << "main thread. won't wait callback" << endl;
            return;
        }
        p->cv[type].wait(lock, [=]{
            return p->dataReady[type] || !(p->callbackTypes & (1 << type));
        });
    });

    player->onMediaStatusChanged([=](mdk::MediaStatus s){
        auto sp = wp.lock();
        if (!sp)
            return false;
        auto p = sp.get();
        const auto type = int(CallbackType::MediaStatus);
        const auto oldValue = p->oldStatus;
        p->oldStatus = s;
        if (!(p->callbackTypes & (1 << type)))
            return true;

        unique_lock lock(p->mtx[type]);
        p->dataReady[type] = false;

        Dart_CObject t{
            .type = Dart_CObject_kInt64,
            .value = {
                .as_int64 = type,
            }
        };
        Dart_CObject v0{
            .type = Dart_CObject_kInt64,
            .value = {
                .as_int64 = (int64_t)oldValue,
            }
        };
        Dart_CObject v1{
            .type = Dart_CObject_kInt64,
            .value = {
                .as_int64 = (int64_t)s,
            }
        };
        Dart_CObject* arr[] = { &t, &v0, &v1 };
        Dart_CObject msg {
            .type = Dart_CObject_kArray,
            .value = {
                .as_array = {
                    .length = std::size(arr),
                    .values = arr,
                },
            }
        };
        if (!postCObject(send_port, &msg)) {
            clog << "postCObject error" << endl;
            return true;
        }
        if (!p->reply[type])
            return true;
        if (tid == this_thread::get_id()) {// FIXME: can not convert dart non-static function to native function, and dart object has no address, so func(context, args) is impossible too
            clog << "main thread. won't wait callback" << endl;
            return true;
        }
        p->cv[type].wait(lock, [=]{
            return p->dataReady[type] || !(p->callbackTypes & (1 << type));
        });
        return p->data[type].mediaStatus.ret;
    });

}

FVP_EXPORT void MdkCallbacksUnregisterPort(int64_t handle)
{
    if (!handle) {
        mdk::setLogHandler(nullptr);
        return;
    }

    const auto it = players.find(handle);
    if (it == players.cend()) {
        return;
    }

    auto sp = it->second;
    for (int i = 0; i < (int)CallbackType::Count; ++i) {
        unique_lock lock(sp->mtx[i]);
        sp->cv[i].notify_one();
    }

    sp->onEvent(nullptr);
    sp->onStateChanged(nullptr);
    sp->onMediaStatusChanged(nullptr);
    players.erase(it);
}

FVP_EXPORT void MdkCallbacksRegisterType(int64_t handle, int type, bool reply)
{
    if (!handle) {
        gCallbackTypes |= (1 << type);
        return;
    }

    const auto it = players.find(handle);
    if (it == players.cend()) {
        return;
    }

    auto sp = it->second;
    sp->callbackTypes |= (1 << type);
    sp->reply[type] = reply;
}

FVP_EXPORT void MdkCallbacksUnregisterType(int64_t handle, int type)
{
    if (!handle) {
        gCallbackTypes &= ~(1 << type);
        return;
    }

    const auto it = players.find(handle);
    if (it == players.cend()) {
        return;
    }

    auto sp = it->second;
    sp->callbackTypes &= ~(1 << type);
}

FVP_EXPORT void MdkCallbacksReplyType(int64_t handle, int type, const void* data)
{
    const auto it = players.find(handle);
    if (it == players.cend()) {
        return;
    }

    auto sp = it->second;
    unique_lock lock(sp->mtx[type]);
    if (data) { // has return value or out parameters
        memcpy(&sp->data[type], data, sizeof(CallbackReply));
    }
    sp->dataReady[type] = true;
    sp->cv[type].notify_one();
}

FVP_EXPORT bool MdkPrepare(int64_t handle, int64_t pos, int64_t seekFlags, void* post_c_object, int64_t send_port)
{
    const auto it = players.find(handle);
    if (it == players.cend()) {
        return false;
    }
    const auto postCObject = reinterpret_cast<bool(*)(Dart_Port, Dart_CObject*)>(post_c_object);
    auto sp = it->second;
    sp->prepare(pos, [=](int64_t position, bool* boost){
        Dart_CObject t{
            .type = Dart_CObject_kInt64,
            .value = {
                .as_int64 = CallbackType::Prepared,
            }
        };
        Dart_CObject v{
            .type = Dart_CObject_kInt64,
            .value = {
                .as_int64 = position,
            }
        };
        Dart_CObject* arr[] = { &t, &v };
        Dart_CObject msg {
            .type = Dart_CObject_kArray,
            .value = {
                .as_array = {
                    .length = std::size(arr),
                    .values = arr,
                },
            },
        };
        if (!postCObject(send_port, &msg)) {
            cout << "postCObject error" << endl; // when?
            return false;
        }
        return true;
    }, mdk::SeekFlag(seekFlags));
    return true;
}