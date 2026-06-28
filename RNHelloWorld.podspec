Pod::Spec.new do |s|
  s.name         = "RNHelloWorld"
  s.version      = "0.1.0"
  s.summary      = "Hello World C++ module"
  s.homepage     = "https://github.com/placeholder"
  s.license      = "MIT"
  s.author       = "Anonymous"
  s.source       = { :git => "", :tag => "#{s.version}" }

  s.ios.deployment_target = "15.1"

  s.source_files = "cpp/HelloWorld*.{h,cpp}", "ios/HelloWorldModule*.{h,mm}"

  s.dependency "React-Core"

  s.pod_target_xcconfig = {
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
  }
end
