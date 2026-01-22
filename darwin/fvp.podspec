#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint fvp.podspec` to validate before publishing.
# Run `flutter clean` and rebuild to sync podspec changes
#

# =============================================================================
# MDK SDK Default URL Configuration
# Change this to point to your Artifactory or custom server
# =============================================================================
MDK_SDK_DEFAULT_URL = 'https://your-artifactory.example.com/artifactory/mdk-sdk/nightly'

# FVP_DEPS_URL env var overrides the default URL
MDK_SDK_URL = ENV['FVP_DEPS_URL'] || MDK_SDK_DEFAULT_URL

Pod::Spec.new do |s|
  s.name             = 'fvp'
  s.version          = '0.35.2'
  s.summary          = 'libmdk based Flutter video player plugin'
  s.description      = <<-DESC
Flutter video player plugin.
                       DESC
  s.homepage         = 'https://mediadevkit.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Wang Bin' => 'wbsecg1@gmail.com' }

  s.compiler_flags   = '-Wno-documentation', '-std=c++20'
  s.frameworks       = 'AVFoundation'
  s.osx.frameworks    = 'FlutterMacOS'
  #s.osx.pod_target_xcconfig  =  { 'OTHER_LDFLAGS'  =>  '-framework FlutterMacOS'  }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.13'

  # Use vendored mdk.xcframework downloaded from custom URL
  s.vendored_frameworks = 'mdk-sdk/lib/mdk.xcframework'

#  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.resource_bundles = {'fvp_privacy' => ['PrivacyInfo.xcprivacy']}
#  s.swift_version = '5.0'
  s.prepare_command = <<-CMD
    set -e
    FVP_VERSION=`grep 'version: ' ../pubspec.yaml | head -1 | awk '{print $2}'`
    echo '#pragma once\\n#define FVP_VERSION "'$FVP_VERSION'"' > ../lib/src/version.h

    # Download mdk-sdk from configured URL
    MDK_URL="${FVP_DEPS_URL:-#{MDK_SDK_DEFAULT_URL}}/mdk-sdk-apple.tar.xz"
    echo "Downloading mdk-sdk from $MDK_URL"
    if [ ! -d "mdk-sdk" ]; then
      curl -L -o mdk-sdk-apple.tar.xz "$MDK_URL"
      tar -xf mdk-sdk-apple.tar.xz
      rm mdk-sdk-apple.tar.xz
    fi
  CMD
end
