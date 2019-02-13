# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

# Abstract targeting from https://github.com/CocoaPods/CocoaPods/issues/5898
abstract_target "common_pods" do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!
  project = Xcodeproj::Project.open "SwiftAsyncWebsocket.xcodeproj"
  project.targets.each { |t| target t.name }
  pod 'SwiftAsyncSocket'
  pod 'CryptoSwift'
end
