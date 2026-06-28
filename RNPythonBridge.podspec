Pod::Spec.new do |s|
  s.name         = "RNPythonBridge"
  s.version      = "0.1.0"
  s.summary      = "Python Bridge for React Native"
  s.homepage     = "https://github.com/placeholder"
  s.license      = "MIT"
  s.author       = "Anonymous"
  s.source       = { :git => "", :tag => "#{s.version}" }

  s.ios.deployment_target = "15.1"

  s.source_files = "cpp/PythonBridge*.{h,cpp}", "ios/PythonBridgeModule*.{h,mm}"

  s.vendored_libraries = "ios/lib/libpython3.13.a"
  s.preserve_paths = "ios/lib/libpython3.13.a", "ios/lib/python3.13"

  s.dependency "React-Core"

  s.pod_target_xcconfig = {
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
    "OTHER_LDFLAGS" => "-Wl,-force_load,$(PODS_TARGET_SRCROOT)/ios/lib/libpython3.13.a -framework Foundation",
    "HEADER_SEARCH_PATHS" => '"$(PODS_TARGET_SRCROOT)/ios/include"',
    "SYSTEM_HEADER_SEARCH_PATHS" => '"$(PODS_TARGET_SRCROOT)/ios/include"',
  }
end
