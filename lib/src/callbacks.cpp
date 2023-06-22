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
    bool dataReady[int(CallbackType::Count)] = {};
    CallbackReply data[int(CallbackType::Count)];
    mutex mtx[int(CallbackType::Count)];
    condition_variable cv[int(CallbackType::Count)];

    mdk::State oldState = mdk::State::Stopped;
    mdk::MediaStatus oldStatus = mdk::MediaStatus::NoMedia;
};

static unordered_map<int64_t, shared_ptr<Player>> players;


FVP_EXPORT void MdkCallbacksRegisterPort(int64_t handle, void* post_c_object, int64_t send_port)
{
    auto player = make_shared<Player>(handle);
    players[handle] = player;
    const auto tid = this_thread::get_id();
    const auto postCObject = reinterpret_cast<bool(*)(Dart_Port, Dart_CObject*)>(post_c_object);

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
                .as_int64 = CallbackType::Event,
            }
        };
        Dart_CObject* arr[] = { &t };
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
                .as_int64 = CallbackType::State,
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
        if (tid == this_thread::get_id()) {// FIXME: can not convert dart non-static function to native function, and dart object has no address, so func(context, args) is impossible too
            clog << "main thread. won't wait callback" << endl;
            return;
        }
        // wait. TODO: no wait if no return type
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
                .as_int64 = CallbackType::MediaStatus,
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

FVP_EXPORT void MdkCallbacksRegisterType(int64_t handle, int type)
{
    const auto it = players.find(handle);
    if (it == players.cend()) {
        return;
    }

    auto sp = it->second;
    sp->callbackTypes |= (1 << type);
}

FVP_EXPORT void MdkCallbacksUnregisterType(int64_t handle, int type)
{
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