// Copyright 2023 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FvpPlugin.h"
#import "Metal/Metal.h"
#import "CoreVideo/CoreVideo.h"
#include "mdk/RenderAPI.h"
#include "mdk/Player.h"
#include <unordered_map>
#include <iostream>

using namespace mdk;
using namespace std;

@interface MetalTexture : NSObject<FlutterTexture>
@end

@implementation MetalTexture {
    @public
    id<MTLDevice> device;
    id<MTLCommandQueue> cmdQueue;
    id<MTLTexture> texture;
    CVPixelBufferRef pixbuf;
    CVMetalTextureCacheRef texCache;
}

- (instancetype)initWithWidth:(int)width height:(int)height
{
    self = [super init];
    device = MTLCreateSystemDefaultDevice();
    cmdQueue = [device newCommandQueue];
    CVMetalTextureCacheCreate(nullptr, nullptr, device, nullptr, &texCache);
    auto attr = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attr, kCVPixelBufferMetalCompatibilityKey, kCFBooleanTrue);
    CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attr, &pixbuf);
    CFRelease(attr);
    CVMetalTextureRef cvtex;
    CVMetalTextureCacheCreateTextureFromImage(nil, texCache, pixbuf, nil, MTLPixelFormatBGRA8Unorm, width, height, 0, &cvtex);
    texture = CVMetalTextureGetTexture(cvtex);
    CFRelease(cvtex);
    return self;
}

- (void)dealloc {
    CVPixelBufferRelease(pixbuf);
    CFRelease(texCache);
}

- (CVPixelBufferRef _Nullable)copyPixelBuffer {
    return CVPixelBufferRetain(pixbuf);
}
@end


class TexturePlayer final: public Player
{
public:
    TexturePlayer(int64_t handle, int width, int height, NSObject<FlutterTextureRegistry>* texReg)
        : Player(reinterpret_cast<mdkPlayerAPI*>(handle))
    {
        mtex_ = [[MetalTexture alloc] initWithWidth:width height:height];
        texId_ = [texReg registerTexture:mtex_];
        MetalRenderAPI ra{};
        ra.device = (__bridge void*)mtex_->device;
        ra.cmdQueue = (__bridge void*)mtex_->cmdQueue;
        ra.texture = (__bridge void*)mtex_->texture;
        setRenderAPI(&ra);
        setVideoSurfaceSize(width, height);

        setRenderCallback([this, texReg](void* opaque){
            renderVideo();
            [texReg textureFrameAvailable:texId_];
        });
    }

    ~TexturePlayer() override {
        setRenderCallback(nullptr);
        setVideoSurfaceSize(-1, -1);
    }

    int64_t textureId() const { return texId_;}
private:
    int64_t texId_ = 0;
    MetalTexture* mtex_ = nil;
};


@interface FvpPlugin () {
    unordered_map<int64_t, shared_ptr<TexturePlayer>> players;
}
@property(readonly, strong, nonatomic) NSObject<FlutterTextureRegistry>* texRegistry;
@end

@implementation FvpPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
#if TARGET_OS_OSX
    auto messenger = registrar.messenger;
#else
    auto messenger = [registrar messenger];
#endif
    FlutterMethodChannel* channel = [FlutterMethodChannel methodChannelWithName:@"fvp" binaryMessenger:messenger];
    FvpPlugin* instance = [[FvpPlugin alloc] initWithRegistrar:registrar];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    self = [super init];
#if TARGET_OS_OSX
    _texRegistry = registrar.textures;
#else
    _texRegistry = [registrar textures];
#endif
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([call.method isEqualToString:@"CreateRT"]) {
        const auto handle = ((NSNumber*)call.arguments[@"player"]).longLongValue;
        const auto width = (int)((NSNumber*)call.arguments[@"width"]).longLongValue;
        const auto height = (int)((NSNumber*)call.arguments[@"height"]).longLongValue;
        auto player = make_shared<TexturePlayer>(handle, width, height, _texRegistry);
        players[player->textureId()] = player;
        result(@(player->textureId()));
    } else if ([call.method isEqualToString:@"ReleaseRT"]) {
        const auto texId = ((NSNumber*)call.arguments[@"texture"]).longLongValue;
        [_texRegistry unregisterTexture:texId];
        players.erase(texId);
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
