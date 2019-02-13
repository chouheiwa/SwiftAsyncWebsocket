Pod::Spec.new do |s|
  s.swift_version = "4.2"
  s.name         = "SwiftAsyncWebsocket"
  s.version      = "0.0.1"
  s.summary      = "A swift websocket library"
  s.description  = <<-DESC
A websocket library. Writen by Swift 4.2
                   DESC

  s.homepage     = "https://github.com/chouheiwa/SwiftAsnycWebsocket"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "chouheiwa" => "849131492@qq.com" }
  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"
  s.source       = { :git => "https://github.com/chouheiwa/SwiftAsyncWebsocket.git", :tag => "#{s.version}" }
  s.source_files  = "Sources", "Sources/**/*"
  s.exclude_files = "Sources/**/*.plist"
  s.dependency 'SwiftAsyncSocket'
  s.dependency 'CryptoSwift'
end
