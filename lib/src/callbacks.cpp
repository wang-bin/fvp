#include "mdk/Player.h"
#include <condition_variable>
#include <memory>
#include <mutex>
#include <unordered_map>
#include "dart_api_types.h"

 #ifdef __cplusplus
 #define FVP_EXTERN_C extern "C"
 #else
 #define FVP_EXTERN_C extern
 #endif

#ifdef _WIN32
#define FVP_EXPORT FVP_EXTERN_C __declspec(dllexport)
#else
#define FVP_EXPORT FVP_EXTERN_C __attribute__((visibility("default")))
#endif

FVP_EXPORT void MdkCallbacksRegisterPort(int64_t handle, void* post_c_object, int64_t send_port);


using namespace std;


enum CallbackType {
    Event, // not a callback, no need to wait for reply
    State,
    MediaStatus,
    Prepared,
    Sync,
    Count,
};

// Callback data from dart if callback has return type or out parameters
union CallbackData {
    struct {
        bool ret;
    } mediaStatus;
    struct {
        double ret;
    } sync;
    struct {
        bool ret;
        bool boost;
    } prepared;
};

class Player : public mdk::Player
{
public:

    Player(int64_t handle)
        : mdk::Player(reinterpret_cast<mdkPlayerAPI*>(handle))
    {
    }

    int callbackTypes = 0;
    bool dataReady[int(CallbackType::Count)] = {};
    CallbackData data[int(CallbackType::Count)];
    mutex mtx[int(CallbackType::Count)];
    condition_variable cv[int(CallbackType::Count)];
private:
};

static unordered_map<int64_t, shared_ptr<Player>> players;


void MdkCallbacksRegisterPort(int64_t handle, void* post_c_object, int64_t send_port)
{
    auto sp = make_shared<Player>(handle);
    players[handle] = sp;
    sp->onEvent([=, p = sp.get()](const mdk::MediaEvent& e){
        const auto type = int(CallbackType::Event);
        if (!(p->callbackTypes & (1 << type)))
            return false;
        // TODO: post_c_object
        return false;
    });

    sp->onStateChanged([=, p = sp.get()](mdk::State s){
        const auto type = int(CallbackType::State);
        if (!(p->callbackTypes & (1 << type)))
            return;

        unique_lock<mutex> lock(p->mtx[type]);
        p->dataReady[type] = false;

        // TODO: post_c_object

        // wait. TODO: no wait if no return type
        p->cv[type].wait(lock, [&]{
            return p->dataReady[type];
        });
    });

    sp->onMediaStatusChanged([=, p = sp.get()](mdk::MediaStatus s){
        const auto type = int(CallbackType::MediaStatus);
        if (!(p->callbackTypes & (1 << type)))
            return true;

        unique_lock<mutex> lock(p->mtx[type]);
        p->dataReady[type] = false;

        // TODO: post_c_object

        // wait. TODO: no wait if no return type
        p->cv[type].wait(lock, [&]{
            return p->dataReady[type];
        });
        return p->data[type].mediaStatus.ret;
    });
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

FVP_EXPORT void MdkCallbacksNotifyType(int64_t handle, int type, const void* data, size_t size)
{
    const auto it = players.find(handle);
    if (it == players.cend()) {
        return;
    }

    auto sp = it->second;
    unique_lock<mutex> lock(sp->mtx[type]);
    if (data && size) { // has return value or out parameters
        memcpy(&sp->data[type], data, size);
    }
    sp->dataReady[type] = true;
    sp->cv[type].notify_one();
}