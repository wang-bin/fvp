#include "fvp_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

using namespace std;

#define MS_ENSURE(f, ...) MS_CHECK(f, return __VA_ARGS__;)
#define MS_WARN(f) MS_CHECK(f)
#define MS_CHECK(f, ...)  do { \
        while (FAILED(GetLastError())) {} \
printf(#f "\n");fflush(nullptr); \
        HRESULT __ms_hr__ = (f); \
        if (FAILED(__ms_hr__)) { \
            std::clog << #f "  ERROR@" << __LINE__ << __FUNCTION__ << ": (" << std::hex << __ms_hr__ << std::dec << ") " << std::error_code(__ms_hr__, std::system_category()).message() << std::endl << std::flush; \
            __VA_ARGS__ \
        } \
    } while (false)


namespace fvp {

// static
void FvpPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "fvp",
          &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<FvpPlugin>(registrar->texture_registrar()
#ifdef VIEW_HAS_GetGraphicsAdapter
      , registrar->GetView()->GetGraphicsAdapter()
#endif
      );

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FvpPlugin::FvpPlugin(flutter::TextureRegistrar* tr, IDXGIAdapter* adapter)
    : texture_registrar_(tr)
    , adapter_(adapter)
{}

FvpPlugin::~FvpPlugin() {}

void FvpPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "CreateRT") {
      MS_WARN(D3D11CreateDevice(adapter_.Get(), adapter_ ? D3D_DRIVER_TYPE_UNKNOWN : D3D_DRIVER_TYPE_HARDWARE, nullptr, 0, nullptr, 0, D3D11_SDK_VERSION, &dev_, nullptr, &ctx_));
      if (!dev_) {
          result->Error("device", "create device failed");
          return;
      }
      ComPtr<ID3D10Multithread> mt;
      if (SUCCEEDED(dev_.As(&mt)))
          mt->SetMultithreadProtected(TRUE);
      D3D11_TEXTURE2D_DESC desc{};
      desc.Width = 1920;
      desc.Height = 1080;
      desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM; // rgba eglbind error
      desc.MipLevels = 1;
      desc.ArraySize = 1;
      desc.SampleDesc.Count = 1;
      desc.Usage = D3D11_USAGE_DEFAULT;
      desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
      desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;// | D3D11_RESOURCE_MISC_SHARED_NTHANDLE;
      MS_WARN(dev_->CreateTexture2D(&desc, nullptr, &tex_));
      if (!tex_) {
          result->Success();
          return;
      }

      ComPtr<IDXGIResource> res;
      MS_WARN(tex_.As(&res));
      MS_WARN(res->GetSharedHandle(&shared_handle_));
      surface_desc_ = make_unique< FlutterDesktopGpuSurfaceDescriptor>();

      surface_desc_->struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
      surface_desc_->handle = shared_handle_;// tex_.Get();
      //surface_desc_->handle = tex_.Get(); // eglbind error
      surface_desc_->width = surface_desc_->visible_width = desc.Width;
      surface_desc_->height = surface_desc_->visible_height = desc.Height;
      surface_desc_->release_context = nullptr;
      surface_desc_->release_callback = [](void* release_context) {};
      //surface_desc_->format = kFlutterDesktopPixelFormatBGRA8888;
      fltex_ = make_unique<flutter::TextureVariant>(flutter::GpuSurfaceTexture(
            kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle
            //kFlutterDesktopGpuSurfaceTypeD3d11Texture2D
              , [&](size_t width, size_t height) {
              //printf("ObtainDescriptorCallback %llux%llu. shared_handle_ %p\n", width, height, shared_handle_); fflush(nullptr);
              //player_.renderVideo(); // stutter
              return surface_desc_.get();
              }));
      texture_id_ = texture_registrar_->RegisterTexture(fltex_.get());
      result->Success(flutter::EncodableValue(texture_id_));

        auto args = std::get<flutter::EncodableMap>(*method_call.arguments());
        const auto handle = args[flutter::EncodableValue("player")].LongValue();
        player_ = make_unique<Player>(reinterpret_cast<mdkPlayerAPI*>(handle));
        D3D11RenderAPI ra{};
        ra.rtv = tex_.Get();
        player_->setRenderAPI(&ra);
        player_->setVideoSurfaceSize(desc.Width, desc.Height);
        player_->setRenderCallback([&](void*) {
            player_->renderVideo();
            texture_registrar_->MarkTextureFrameAvailable(texture_id_);
        });
  }
  else {
    result->NotImplemented();
  }
}

}  // namespace fvp
