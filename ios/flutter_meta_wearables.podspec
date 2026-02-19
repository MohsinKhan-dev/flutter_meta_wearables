Pod::Spec.new do |s|
  s.name             = 'flutter_meta_wearables'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin for Meta Wearables DAT SDK.'
  s.description      = <<-DESC
Flutter plugin wrapping the Meta Wearables Device Access Toolkit (DAT) SDK
for Ray-Ban Meta smart glasses. Provides device registration, BLE discovery,
live video streaming, and photo capture.
                       DESC
  s.homepage         = 'https://github.com/user/flutter_meta_wearables'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Meta Platforms' => 'dev@meta.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '17.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version = '5.9'
end
