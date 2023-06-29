/*
 * Copyright (c) 2023 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#if canImport(Flutter)
import Flutter
#else
import FlutterMacOS
#endif
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
    private var registry: FlutterTextureRegistry
    var textureId: Int64 = 0

    init(player: Player, width: Int, height: Int, textureRegistry: FlutterTextureRegistry) {
        registry = textureRegistry
        super.init()
        self.player = player
        self.textureId = registry.register(self)

        self.player.setRenderCallback { [weak self] in
            guard let self = self else { return }
            _ = self.player.renderVideo()
            self.registry.textureFrameAvailable(self.textureId)
        }

        device = MTLCreateSystemDefaultDevice()
        cmdQueue = device.makeCommandQueue()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &texCache)
        createTexture(width:width, height:height)
    }

    deinit {
        player.setRenderCallback(nil)
        player.setVideoSurfaceSize(Int32(-1), Int32(-1))
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
        player.setRenderAPI(&ra)
        player.setVideoSurfaceSize(Int32(width), Int32(height)) // enable renderer
    }

}

public class FvpPlugin: NSObject, FlutterPlugin {
    private var registry: FlutterTextureRegistry;

    private var renderers: [Int64: FvpRenderer] = [:];

    init(textureRegistry: FlutterTextureRegistry) {
        registry = textureRegistry;
        super.init()
    }

  public static func register(with registrar: FlutterPluginRegistrar) {
#if canImport(Flutter)
    let binaryMessenger = registrar.messenger()
    let textureRegistry = registrar.textures()
#else
    let binaryMessenger = registrar.messenger
    let textureRegistry = registrar.textures
#endif
    let channel = FlutterMethodChannel(name: "fvp", binaryMessenger: binaryMessenger)
    let instance = FvpPlugin(textureRegistry: textureRegistry)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "CreateRT":
        let args = call.arguments as! [String: Any]
        let handle = args["player"] as! Int64
        let width = Int(args["width"] as! Int64)
        let height = Int(args["height"] as! Int64)
        let player = Player(UnsafePointer<mdkPlayerAPI>(OpaquePointer(bitPattern: Int(handle))))
        let render = FvpRenderer(player: player, width: width, height: height, textureRegistry: registry)
        renderers[render.textureId] = render
        result(render.textureId)
    case "ReleaseRT":
        let args = call.arguments as! [String: Any]
        let tex = args["texture"] as! Int64
        registry.unregisterTexture(tex)
        renderers.removeValue(forKey: tex)
        result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
