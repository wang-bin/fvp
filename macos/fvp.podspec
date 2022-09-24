#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint fvp.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'fvp'
  s.version          = '0.0.1'
  s.summary          = 'libmdk based video player Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'https:/qtav.org'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Wang Bin' => 'wbsecg1@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.dependency 'mdk'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
