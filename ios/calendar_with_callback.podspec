#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint calendar_with_callback.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'calendar_with_callback'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin to add calendar events with callback support'
  s.description      = <<-DESC
A Flutter plugin that opens the calendar app to add events and returns event information via callback.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end

