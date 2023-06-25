#pragma once
#include <stdbool.h>
#include <stdint.h>

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
FVP_EXPORT void MdkCallbacksUnregisterPort(int64_t handle);
FVP_EXPORT void MdkCallbacksRegisterType(int64_t handle, int type, bool reply);
FVP_EXPORT void MdkCallbacksUnregisterType(int64_t handle, int type);
FVP_EXPORT void MdkCallbacksReplyType(int64_t handle, int type, const void* data);

enum CallbackType {
    Event, // not a callback, no need to wait for reply
    State,
    MediaStatus,
    Prepared,
    Sync,
    Count,
};

// Callback data from dart if callback has return type or out parameters
union CallbackReply {
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
