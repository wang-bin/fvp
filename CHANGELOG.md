## 0.2.0

* fix web build. web will use official implementation
* add 'platforms' option for `registerWith()` to enable plugin for given platforms, other platforms will use official implementation
* `Player.prepare()` is async
* no longer export `MdkVideoPlayer`

## 0.1.0

* fix fail to convert metadata to dart string
* rename `State` to `PlaybackState`

## 0.0.9

* add textureId notifier for Player
* improve documentation

## 0.0.8

* support httpHeaders
* export backend apis for creating your own players

## 0.0.7

* texture size can be set by user via `MdkVideoPlayer.registerWith({'maxWidth': width, 'maxHeight': height});`
* fix crash for some streams containing subtitle

## 0.0.6

* fix local file path encoding
* use objc instead of swift. simpler code, smaller binary size, less dependencies.

## 0.0.5

* fix macos, ios build for flutter without sharedDarwinSource support
* fix StreamController close

## 0.0.4

* supports assets
* improve bufferingUpdate event
* support backend logging
* customize decoders via `MdkVideoPlayer.registerWith({'video.decoders': [...]})`

## 0.0.3

* fix macos build from pub

## 0.0.2

* fix macos build

## 0.0.1

* video playback for windows, linux, macos, ios, android
* hardware decoding, optimal gpu rendering
