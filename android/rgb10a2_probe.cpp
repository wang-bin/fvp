/*
 * Copyright (c) 2026 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// Cross-context RGBA_1010102 sampling probe.
//
// Some drivers (e.g. PowerVR BXE on Realtek TV SoCs, wang-bin/fvp#374) accept
// a 10-bit EGLConfig, allocate and render into RGBA_1010102 window buffers
// without any EGL/GL error — but cannot sample those buffers consistently
// from a *different* GL context (IMGSRV "IsTextureConsistent" failures), which
// corrupts every frame the Flutter engine consumes. Since no error surfaces
// through the API, the only reliable detection is to reproduce the handoff:
//
//   1. render a known pattern into an RGBA_1010102 ImageReader surface
//      (same gralloc usage bits as the real video path) from one EGL context
//   2. import the produced AHardwareBuffer as an EGLImage in a second,
//      unshared context (what the Flutter engine does)
//   3. sample it and read back; mismatch => the 10-bit path is broken
//
// The result decides whether to force GLRenderAPI.depth = 8 before
// updateNativeSurface(). Any probe-infrastructure failure returns "ok" so
// healthy devices are never punished. Probed once per process.
//
// Env overrides for testing: FVP_RGB10A2_PROBE=0 (skip, assume ok),
// FVP_RGB10A2_PROBE=force8 (skip, assume broken).

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <android/hardware_buffer.h>
#include <android/native_window.h>
#include <dlfcn.h>
#include <unistd.h>
#include <cstdlib>
#include <cstring>
#include <iostream>

using std::clog;
using std::endl;

namespace {

// libmediandk symbols resolved at runtime: AImageReader_newWithUsage and
// AImage_getHardwareBuffer are API 26+, while the plugin may load on older
// devices where direct linking would abort the load.
struct AImageReader;
struct AImage;
typedef int (*AImageReader_newWithUsage_t)(int32_t, int32_t, int32_t, uint64_t, int32_t, AImageReader**);
typedef int (*AImageReader_getWindow_t)(AImageReader*, ANativeWindow**);
typedef int (*AImageReader_acquireNextImage_t)(AImageReader*, AImage**);
typedef void (*AImageReader_delete_t)(AImageReader*);
typedef int (*AImage_getHardwareBuffer_t)(const AImage*, AHardwareBuffer**);
typedef void (*AImage_delete_t)(AImage*);

constexpr int32_t kFormatRgba1010102 = 0x2b; // AIMAGE_FORMAT_RGBA_1010102, API 26
constexpr uint64_t kUsage =
    AHARDWAREBUFFER_USAGE_GPU_SAMPLED_IMAGE | AHARDWAREBUFFER_USAGE_GPU_COLOR_OUTPUT;
constexpr int kSrcSize = 512; // large enough for vendor tiled/compressed layouts
constexpr int kDstSize = 64;

// Quadrant colors (RGB 0..255). Distinct enough that any mis-decode fails.
constexpr uint8_t kColors[4][3] = {
    {255, 0, 0}, {0, 255, 0}, {0, 0, 255}, {255, 255, 255}};

bool closeToAny(const uint8_t* px) {
  for (const auto& c : kColors) {
    if (abs(int(px[0]) - c[0]) <= 24 && abs(int(px[1]) - c[1]) <= 24 &&
        abs(int(px[2]) - c[2]) <= 24) {
      return true;
    }
  }
  return false;
}

struct ProbeCleanup {
  void* ndk = nullptr;
  EGLDisplay dpy = EGL_NO_DISPLAY;
  EGLSurface winSurf = EGL_NO_SURFACE;
  EGLSurface pbuf = EGL_NO_SURFACE;
  EGLContext ctxA = EGL_NO_CONTEXT;
  EGLContext ctxB = EGL_NO_CONTEXT;
  EGLImageKHR image = EGL_NO_IMAGE_KHR;
  AImageReader* reader = nullptr;
  AImage* img = nullptr;
  AImageReader_delete_t readerDelete = nullptr;
  AImage_delete_t imageDelete = nullptr;
  PFNEGLDESTROYIMAGEKHRPROC destroyImage = nullptr;
  // Whatever was current on this thread before the probe ran — restored on
  // exit so callers with a live EGL context are not clobbered.
  EGLDisplay oldDpy = EGL_NO_DISPLAY;
  EGLContext oldCtx = EGL_NO_CONTEXT;
  EGLSurface oldDraw = EGL_NO_SURFACE;
  EGLSurface oldRead = EGL_NO_SURFACE;

  void saveCurrent() {
    oldDpy = eglGetCurrentDisplay();
    oldCtx = eglGetCurrentContext();
    oldDraw = eglGetCurrentSurface(EGL_DRAW);
    oldRead = eglGetCurrentSurface(EGL_READ);
  }

  ~ProbeCleanup() {
    if (dpy != EGL_NO_DISPLAY) {
      if (oldCtx != EGL_NO_CONTEXT && oldDpy != EGL_NO_DISPLAY) {
        eglMakeCurrent(oldDpy, oldDraw, oldRead, oldCtx);
      } else {
        eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
      }
      if (image != EGL_NO_IMAGE_KHR && destroyImage) destroyImage(dpy, image);
      if (winSurf != EGL_NO_SURFACE) eglDestroySurface(dpy, winSurf);
      if (pbuf != EGL_NO_SURFACE) eglDestroySurface(dpy, pbuf);
      if (ctxA != EGL_NO_CONTEXT) eglDestroyContext(dpy, ctxA);
      if (ctxB != EGL_NO_CONTEXT) eglDestroyContext(dpy, ctxB);
    }
    if (img && imageDelete) imageDelete(img);
    if (reader && readerDelete) readerDelete(reader);
    // Last: the deleters above live in this library.
    if (ndk) dlclose(ndk);
  }
};

// true = 10-bit path verified broken. Everything else (including probe
// infrastructure failures) = false.
bool probeShowsBroken() {
  void* ndk = dlopen("libmediandk.so", RTLD_NOW | RTLD_LOCAL);
  if (!ndk) return false;
  ProbeCleanup c;
  c.ndk = ndk;
  c.saveCurrent();
  auto newWithUsage = (AImageReader_newWithUsage_t)dlsym(ndk, "AImageReader_newWithUsage");
  auto getWindow = (AImageReader_getWindow_t)dlsym(ndk, "AImageReader_getWindow");
  auto acquireNext = (AImageReader_acquireNextImage_t)dlsym(ndk, "AImageReader_acquireNextImage");
  auto readerDelete = (AImageReader_delete_t)dlsym(ndk, "AImageReader_delete");
  auto getHwBuffer = (AImage_getHardwareBuffer_t)dlsym(ndk, "AImage_getHardwareBuffer");
  auto imageDelete = (AImage_delete_t)dlsym(ndk, "AImage_delete");
  if (!newWithUsage || !getWindow || !acquireNext || !readerDelete || !getHwBuffer || !imageDelete) {
    return false; // pre-26 device: can't probe (and 1010102 unlikely anyway)
  }

  auto getNativeClientBuffer =
      (PFNEGLGETNATIVECLIENTBUFFERANDROIDPROC)eglGetProcAddress("eglGetNativeClientBufferANDROID");
  auto createImage = (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
  auto destroyImage = (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
  auto imageTargetTexture =
      (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress("glEGLImageTargetTexture2DOES");
  if (!getNativeClientBuffer || !createImage || !destroyImage || !imageTargetTexture) {
    return false;
  }

  c.readerDelete = readerDelete;
  c.imageDelete = imageDelete;
  c.destroyImage = destroyImage;

  c.dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  EGLint maj, min;
  if (c.dpy == EGL_NO_DISPLAY || !eglInitialize(c.dpy, &maj, &min)) {
    c.dpy = EGL_NO_DISPLAY;
    return false;
  }

  // 10-bit window config — the one MDK would select. None => nothing to probe.
  const EGLint attrs10[] = {EGL_RED_SIZE, 10, EGL_GREEN_SIZE, 10, EGL_BLUE_SIZE, 10,
                            EGL_ALPHA_SIZE, 2, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
                            EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_NONE};
  EGLConfig cfg10;
  EGLint n = 0;
  if (!eglChooseConfig(c.dpy, attrs10, &cfg10, 1, &n) || n < 1) return false;

  if (newWithUsage(kSrcSize, kSrcSize, kFormatRgba1010102, kUsage, 2, &c.reader) != 0 || !c.reader) {
    return false;
  }
  ANativeWindow* window = nullptr; // owned by the reader
  if (getWindow(c.reader, &window) != 0 || !window) return false;

  const EGLint ctxAttrs[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  c.ctxA = eglCreateContext(c.dpy, cfg10, EGL_NO_CONTEXT, ctxAttrs);
  if (c.ctxA == EGL_NO_CONTEXT) return false;
  c.winSurf = eglCreateWindowSurface(c.dpy, cfg10, window, nullptr);
  if (c.winSurf == EGL_NO_SURFACE) return false;
  if (!eglMakeCurrent(c.dpy, c.winSurf, c.winSurf, c.ctxA)) return false;

  // Producer: four solid quadrants.
  glEnable(GL_SCISSOR_TEST);
  const int h = kSrcSize / 2;
  const int quads[4][2] = {{0, 0}, {h, 0}, {0, h}, {h, h}};
  for (int i = 0; i < 4; i++) {
    glScissor(quads[i][0], quads[i][1], h, h);
    glClearColor(kColors[i][0] / 255.f, kColors[i][1] / 255.f, kColors[i][2] / 255.f, 1.f);
    glClear(GL_COLOR_BUFFER_BIT);
  }
  glDisable(GL_SCISSOR_TEST);
  glFinish();
  if (!eglSwapBuffers(c.dpy, c.winSurf)) return false;
  eglMakeCurrent(c.dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);

  // The queued buffer lands in the reader asynchronously.
  for (int tries = 0; tries < 50 && !c.img; tries++) {
    if (acquireNext(c.reader, &c.img) != 0) c.img = nullptr;
    if (!c.img) usleep(2000);
  }
  if (!c.img) return false;
  AHardwareBuffer* ahb = nullptr; // owned by the AImage
  if (getHwBuffer(c.img, &ahb) != 0 || !ahb) return false;

  // Consumer: separate (unshared) context, like the Flutter engine's.
  const EGLint attrs8[] = {EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8,
                           EGL_ALPHA_SIZE, 8, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
                           EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_NONE};
  EGLConfig cfg8;
  if (!eglChooseConfig(c.dpy, attrs8, &cfg8, 1, &n) || n < 1) return false;
  c.ctxB = eglCreateContext(c.dpy, cfg8, EGL_NO_CONTEXT, ctxAttrs);
  if (c.ctxB == EGL_NO_CONTEXT) return false;
  const EGLint pbAttrs[] = {EGL_WIDTH, kDstSize, EGL_HEIGHT, kDstSize, EGL_NONE};
  c.pbuf = eglCreatePbufferSurface(c.dpy, cfg8, pbAttrs);
  if (c.pbuf == EGL_NO_SURFACE) return false;
  if (!eglMakeCurrent(c.dpy, c.pbuf, c.pbuf, c.ctxB)) return false;

  EGLClientBuffer clientBuf = getNativeClientBuffer(ahb);
  if (!clientBuf) return false;
  c.image = createImage(c.dpy, EGL_NO_CONTEXT, EGL_NATIVE_BUFFER_ANDROID, clientBuf, nullptr);
  if (c.image == EGL_NO_IMAGE_KHR) return false;

  GLuint tex = 0;
  glGenTextures(1, &tex);
  glBindTexture(GL_TEXTURE_EXTERNAL_OES, tex);
  imageTargetTexture(GL_TEXTURE_EXTERNAL_OES, c.image);
  glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

  static const char* kVs =
      "attribute vec2 a;varying vec2 v;"
      "void main(){v=a*0.5+0.5;gl_Position=vec4(a,0.0,1.0);}";
  static const char* kFs =
      "#extension GL_OES_EGL_image_external : require\n"
      "precision mediump float;uniform samplerExternalOES t;varying vec2 v;"
      "void main(){gl_FragColor=texture2D(t,v);}";
  GLuint vs = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vs, 1, &kVs, nullptr);
  glCompileShader(vs);
  GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fs, 1, &kFs, nullptr);
  glCompileShader(fs);
  GLuint prog = glCreateProgram();
  glAttachShader(prog, vs);
  glAttachShader(prog, fs);
  glBindAttribLocation(prog, 0, "a");
  glLinkProgram(prog);
  GLint linked = 0;
  glGetProgramiv(prog, GL_LINK_STATUS, &linked);
  if (!linked) return false;
  glUseProgram(prog);
  glUniform1i(glGetUniformLocation(prog, "t"), 0);
  static const GLfloat verts[] = {-1, -1, 1, -1, -1, 1, 1, 1};
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, verts);
  glEnableVertexAttribArray(0);
  glViewport(0, 0, kDstSize, kDstSize);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  glFinish();

  // Quadrant centers of the destination. Y orientation may flip between the
  // surfaces, so accept any assignment of the four expected colors — garbage
  // from a mis-decoded buffer matches none of them.
  const int pts[4][2] = {{kDstSize / 4, kDstSize / 4},
                         {3 * kDstSize / 4, kDstSize / 4},
                         {kDstSize / 4, 3 * kDstSize / 4},
                         {3 * kDstSize / 4, 3 * kDstSize / 4}};
  int bad = 0;
  for (const auto& p : pts) {
    uint8_t px[4] = {0, 0, 0, 0};
    glReadPixels(p[0], p[1], 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
    if (!closeToAny(px)) bad++;
  }
  if (glGetError() != GL_NO_ERROR) return false;
  clog << "rgb10a2 cross-context probe: " << bad << "/4 samples corrupt" << endl;
  return bad > 0;
}

} // namespace

// True when RGBA_1010102 window buffers survive cross-context sampling on
// this driver (or when the probe cannot run). Probed once; magic-static
// initialization makes concurrent first calls safe.
bool fvpRgb10a2CrossContextOk() {
  static const bool ok = [] {
    if (const char* env = getenv("FVP_RGB10A2_PROBE")) {
      if (!strcmp(env, "0")) return true;
      if (!strcmp(env, "force8")) return false;
    }
    const bool broken = probeShowsBroken();
    clog << "rgb10a2 cross-context sampling ok: " << !broken << endl;
    return !broken;
  }();
  return ok;
}
