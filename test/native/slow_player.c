#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

static atomic_int deleted;

void* mdkPlayerAPI_new(void) { return malloc(1); }

// Model a vendor MediaCodec::stop that takes longer than a UI frame.
void mdkPlayerAPI_delete(void** player) {
    usleep(300000);
    free(*player);
    *player = NULL;
    atomic_fetch_add(&deleted, 1);
}

int deletedPlayers(void) { return atomic_load(&deleted); }

void MdkCallbacksRegisterPort(int64_t handle, void* post, int64_t port) {}
void MdkCallbacksUnregisterPort(int64_t handle) {}
void MdkCallbacksRegisterType(int64_t handle, int type, _Bool reply) {}
void MdkCallbacksUnregisterType(int64_t handle, int type) {}
