#ifndef FLUTTER_PLUGIN_FVP_PLUGIN_H_
#define FLUTTER_PLUGIN_FVP_PLUGIN_H_

#include <stdint.h>
#include <stdbool.h>

#if defined(__cplusplus)
extern "C" {
#endif

bool MdkIsEmulator();
void* MdkGetPlayerVid(int64_t tex_id);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_FVP_PLUGIN_H_
