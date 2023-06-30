#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint fvp.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'fvp'
  s.version          = '0.0.1'
  s.summary          = 'libmdk based video player Flutter plugin project.'
  s.description      = <<-DESC
Flutter video player plugin.
                       DESC
  s.homepage         = 'https://qtav.org'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Wang Bin' => 'wbsecg1@gmail.com' }

  s.compiler_flags   = '-Wno-documentation -std=c++20'
  s.osx.pod_target_xcconfig  =  { 'OTHER_LDFLAGS'  =>  '-framework FlutterMacOS'  }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.11'
  s.dependency 'mdk'

#  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
