#ifndef FLUTTER_PLUGIN_FVP_PLUGIN_H_
#define FLUTTER_PLUGIN_FVP_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>
#include <wrl/client.h>
#include <d3d11.h>
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

#include "mdk/MediaInfo.h"
#include "mdk/RenderAPI.h"
#include "mdk/Player.h"
using namespace MDK_NS;

#include <memory>
using namespace Microsoft::WRL;

namespace fvp {

class FvpPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FvpPlugin(flutter::TextureRegistrar* tr, IDXGIAdapter* adapter = nullptr);

  virtual ~FvpPlugin();

  // Disallow copy and assign.
  FvpPlugin(const FvpPlugin&) = delete;
  FvpPlugin& operator=(const FvpPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<FlutterDesktopGpuSurfaceDescriptor> surface_desc_;
  std::unique_ptr<flutter::TextureVariant> fltex_;
  int64_t texture_id_ = 0;

  flutter::TextureRegistrar* texture_registrar_ = nullptr;

  ComPtr<ID3D11Device> dev_;
  ComPtr<ID3D11DeviceContext> ctx_;
  ComPtr<ID3D11Texture2D> tex_;
  ComPtr<IDXGIAdapter> adapter_;
  HANDLE shared_handle_;

  Player player_;
};

}  // namespace fvp

#endif  // FLUTTER_PLUGIN_FVP_PLUGIN_H_
