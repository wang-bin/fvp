#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint fvp.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'fvp'
  s.version          = '0.23.0'
  s.summary          = 'libmdk based Flutter video player plugin'
  s.description      = <<-DESC
Flutter video player plugin.
                       DESC
  s.homepage         = 'https://mediadevkit.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Wang Bin' => 'wbsecg1@gmail.com' }

  s.compiler_flags   = '-Wno-documentation', '-std=c++20'
  s.osx.frameworks    = 'FlutterMacOS'
  #s.osx.pod_target_xcconfig  =  { 'OTHER_LDFLAGS'  =>  '-framework FlutterMacOS'  }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.13'
  s.dependency 'mdk', '~> 0.29.1'

#  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
