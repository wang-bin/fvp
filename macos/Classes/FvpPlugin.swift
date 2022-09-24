import Cocoa
import FlutterMacOS
import Metal
import CoreVideo
import mdk

fileprivate class FvpRenderer: NSObject, FlutterTexture {
    private var device : MTLDevice!
    private var cmdQueue : MTLCommandQueue!
    private var texture : MTLTexture!
    private var pixbuf : CVPixelBuffer!
    private var texCache : CVMetalTextureCache!
    private var player : Player!

    init(player: Player) {
        super.init()
        self.player = player

        device = MTLCreateSystemDefaultDevice()
        cmdQueue = device.makeCommandQueue()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &texCache)
        createTexture(width:1920, height:1080)
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        return Unmanaged.passRetained(pixbuf)
    }

    private func createTexture(width: Int, height: Int) {
        /*
         // texture from CVPixelBuffer.iosurface
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1920, height: 1080, mipmapped: false)
        desc.storageMode = .private
        desc.resourceOptions = .storageModePrivate
        desc.usage = [.shaderRead, .renderTarget]
        texture = device.makeTexture(descriptor: desc)
        */

        let attrs = [
                    kCVPixelBufferMetalCompatibilityKey: true
                ] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &pixbuf)

        var cvtex : CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, texCache, pixbuf!, nil, .bgra8Unorm, width, height, 0, &cvtex)

        texture = CVMetalTextureGetTexture(cvtex!)

        var ra = mdkMetalRenderAPI()
        ra.type = MDK_RenderAPI_Metal
        ra.device = bridge(obj: device)
        ra.cmdQueue = bridge(obj: cmdQueue)
        ra.texture = bridge(obj: texture)
        player.setRendAPI(&ra)
        player.setVideoSurfaceSize(Int32(width), Int32(height)) // enable renderer
    }

}

public class FvpPlugin: NSObject, FlutterPlugin {
    private let player = Player()
    var textureId: Int64?;
    private var registry: FlutterTextureRegistry;

    init(textureRegistry: FlutterTextureRegistry) {
        registry = textureRegistry;
        super.init()

        player.loop = -1
        player.videoDecoders = ["VT:copy=0", "FFmpeg"]
        player.currentMediaChanged({
            print("++++++++++currentMediaChanged: \(self.player.media)+++++++")
        })
        player.onMediaStatusChanged {
            print(".....Status changed to \($0)....")
            return true
        }

        player.setRenderCallback { [weak self] in
            guard let self = self else { return }
            guard let texId = self.textureId else {return}
            _ = self.player.renderVideo()
            self.registry.textureFrameAvailable(texId)
        }

        player.media = "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/level_4.m3u8"
        player.state = .Playing
    }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "fvp", binaryMessenger: registrar.messenger)
      let instance = FvpPlugin(textureRegistry: registrar.textures)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "CreateRT":
        let render = FvpRenderer(player: player)
        textureId = registry.register(render)
        result(textureId)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
