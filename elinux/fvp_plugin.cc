/*
 * Copyright (c) 2025 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#include "include/fvp/fvp_plugin.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar.h>
#include <flutter/standard_method_codec.h>
#if 1
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#else
#include <epoxy/gl.h>
#include <epoxy/egl.h>
#endif
#include <map>
#include <memory>
#include <iostream>
#include <unordered_map>
#include "mdk/RenderAPI.h"
#include "mdk/Player.h"
#undef Success // X.h

using namespace std;

#define EGL_ENSURE(x, ...) EGL_RUN_CHECK(x, return __VA_ARGS__)
#define EGL_WARN(x, ...) EGL_RUN_CHECK(x)
#define EGL_RUN_CHECK(x, ...) do { \
        while (eglGetError() != EGL_SUCCESS) {} \
        (x); \
        const EGLint err = eglGetError(); \
        if (err != EGL_SUCCESS) { \
            std::cout << #x " EGL ERROR (" << std::hex << err << std::dec << ") @" << __LINE__ << __FUNCTION__ << std::endl; \
            __VA_ARGS__; \
        } \
    } while(false)

#define GL_ENSURE(x, ...) GL_RUN_CHECK(x, return __VA_ARGS__)
#define GL_WARN(x, ...) GL_RUN_CHECK(x)
// GL_CONTEXT_LOST repeats. stop render loop? see qtbase c33faac32b
// https://www.khronos.org/webgl/wiki/HandlingContextLost
#define GL_RUN_CHECK(expr, ...) do { \
        while (true) { \
            const GLenum err = glGetError(); \
            if (err == GL_NO_ERROR) \
                break; \
            if (err == GL_CONTEXT_LOST_KHR) { \
                std::cout << "GL_CONTEXT_LOST" << std::endl; \
                break; \
            } \
        } \
        expr; \
        const GLenum err = glGetError(); \
        if (err != GL_NO_ERROR) { \
            std::cout << #expr "  GL ERROR (" << std::hex << err << std::dec << ") @" << __FUNCTION__  << __LINE__ << std::endl; \
            __VA_ARGS__; \
        } \
    } while(false)

namespace {
class TexturePlayer final : public mdk::Player
{
public:
  TexturePlayer(int64_t handle, int width, int height, flutter::TextureRegistrar* texRegistrar)
    : mdk::Player(reinterpret_cast<mdkPlayerAPI*>(handle))
  {
    fltImg_->egl_image = EGL_NO_IMAGE_KHR; // TODO:
    fltImg_->width = width;
    fltImg_->height = height;
    fltImg_->release_callback = [](void* release_context) {
    };
    fltImg_->release_context = nullptr; // TODO:
    fltTex_ = make_unique<flutter::TextureVariant>(flutter::EGLImageTexture(
      [this](size_t width, size_t height, void* egl_display, void* egl_context) {
        fltImg_->egl_image = ensureVideo(width, height, static_cast<EGLDisplay>(egl_display), static_cast<EGLContext>(egl_context));
        return fltImg_.get();
      }
    ));
    textureId = texRegistrar->RegisterTexture(fltTex_.get());

    scale(1, -1); // y is flipped
    setVideoSurfaceSize(width, height);
    setRenderCallback([this, texRegistrar](void*) {
      //renderVideo(); // need a gl context
      texRegistrar->MarkTextureFrameAvailable(textureId);
    });
  }

  ~TexturePlayer() override {
    setRenderCallback(nullptr);
    if (img_ != EGL_NO_IMAGE_KHR) {
        EGL_WARN(eglDestroyImageKHR(disp_, img_));
        img_ = EGL_NO_IMAGE_KHR;
    }
    if (tex_)
      GL_WARN(glDeleteTextures(1, &tex_));
    if (fbo_)
      GL_WARN(glDeleteFramebuffers(1, &fbo_));
    setVideoSurfaceSize(-1, -1);
  }

  EGLImageKHR ensureVideo(size_t width, size_t height, EGLDisplay disp, EGLContext c) {
    if (fbo_ == 0) {
        ctx_ = c; // fbo can not be shared
        disp_ = disp;
        draw_ = eglGetCurrentSurface(EGL_DRAW);
        read_ = eglGetCurrentSurface(EGL_READ);
        GL_WARN(glGenFramebuffers(1, &fbo_));
    }
    if (tex_ == 0) {
        GLint prevFbo = 0;
        GL_WARN(glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFbo));
        GL_WARN(glBindFramebuffer(GL_FRAMEBUFFER, fbo_));
        GL_WARN(glGenTextures(1, &tex_));
        GL_WARN(glBindTexture(GL_TEXTURE_2D, tex_));
        GL_WARN(glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr));
        GL_WARN(glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + 0, GL_TEXTURE_2D, tex_, 0));
        const GLenum err = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        GL_WARN(glBindFramebuffer(GL_FRAMEBUFFER, prevFbo));
        if (err != GL_FRAMEBUFFER_COMPLETE) {
            //glDeleteFramebuffers(1, &fbo);
            clog << fbo_ << " glFramebufferTexture2D " + std::to_string(tex_) + " error: " << err << endl;
            return img_;
        }
        mdk::GLRenderAPI ra{};
        ra.fbo = fbo_;
        setRenderAPI(&ra);
    }
    if (img_ == EGL_NO_IMAGE_KHR) {
        if (!eglCreateImageKHR) {
          eglCreateImageKHR = (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
          eglDestroyImageKHR = (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
        }
        EGL_WARN(img_ = eglCreateImageKHR(disp, c, EGL_GL_TEXTURE_2D_KHR, (EGLClientBuffer)(intptr_t)tex_, nullptr));
        if (img_ == EGL_NO_IMAGE_KHR) {
            clog << "eglCreateImageKHR error" << endl;
        }
    }

    renderVideo();
    return img_;
  }

  int64_t textureId;
private:
  unique_ptr<FlutterDesktopEGLImage> fltImg_ = make_unique<FlutterDesktopEGLImage>();
  unique_ptr<flutter::TextureVariant> fltTex_;

  PFNEGLCREATEIMAGEKHRPROC eglCreateImageKHR = nullptr;
  PFNEGLDESTROYIMAGEKHRPROC eglDestroyImageKHR = nullptr;
  EGLDisplay disp_ = EGL_NO_DISPLAY;
  EGLContext ctx_ = EGL_NO_CONTEXT;
  EGLSurface read_ = EGL_NO_SURFACE;
  EGLSurface draw_ = EGL_NO_SURFACE;
  EGLImageKHR img_ = EGL_NO_IMAGE_KHR;
  GLuint tex_ = 0; // TODO: array
  GLuint fbo_ = 0;
};


class FvpPlugin final : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrar *registrar);

  FvpPlugin(flutter::TextureRegistrar* tr)
    : texture_registrar_(tr)
    {}

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);


  flutter::TextureRegistrar* texture_registrar_ = nullptr;
  std::unordered_map<int64_t, std::shared_ptr<mdk::Player>> players_;
};

// static
void FvpPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrar *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "fvp",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FvpPlugin>(registrar->texture_registrar());

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
  mdk::SetGlobalOption("MDK_KEY", "980B9623276F746C5FBB5EC5120D4A99A0B58B635592EAEE41F6817FDF3B28B96AC4A49866257726C19B246863B5ADAF5D17464E86D72A90634E8AE8418F810967F469DCD8908B93A044A13AEDF2B566E0B5810523E2B59E2D83E616B1B807B66253E1607A79BC86AEDE1AEF46F79AA60F36BE44DDEE47B84E165AF2788F8109");
}

void FvpPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "CreateRT") {
      auto args = std::get<flutter::EncodableMap>(*method_call.arguments());
      const auto width = (int)args[flutter::EncodableValue("width")].LongValue();
      const auto height = (int)args[flutter::EncodableValue("height")].LongValue();
      const auto handle = args[flutter::EncodableValue("player")].LongValue();
      auto player = make_shared<TexturePlayer>(handle, width, height, texture_registrar_);
      result->Success(flutter::EncodableValue(player->textureId));
      players_[player->textureId] = player;
  } else if (method_call.method_name() == "ReleaseRT") {
    auto args = std::get<flutter::EncodableMap>(*method_call.arguments());
    const auto texId = args[flutter::EncodableValue("texture")].LongValue();
    texture_registrar_->UnregisterTexture(texId);
    if (auto it = players_.find(texId); it != players_.cend()) {
        players_.erase(it);
    }
    result->Success();
  } else if (method_call.method_name() == "MixWithOthers") {
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace

void FvpPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  FvpPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrar>(registrar));
}
