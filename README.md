# SwiftAsyncWebsocket
 [![Version Status](https://img.shields.io/cocoapods/v/SwiftAsyncWebsocket.svg?style=flat)](http://cocoadocs.org/docsets/SwiftAsyncWebsocket)
 [![Platform](http://img.shields.io/cocoapods/p/SwiftAsyncWebsocket.svg?style=flat)](http://cocoapods.org/?q=SwiftAsyncWebsocket) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) ![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)
 
SwiftAsyncWebsocket is a websocket library full implement by swift.

## Features
- [x] websocket connect and send or read data 
- [x] Fragmentation data receive
- [ ] websocket based on TLS/SSL (wss)
- [ ] child protocol extension
- [ ] Fragmentation data send
## Installation
### 1. Mannual install

SwiftAsyncWebsocket can be easy install by following steps

```
git clone https://github.com/chouheiwa/SwiftAsyncWebsocket.git

cd SwiftAsyncWebsocket

pod install

open ./SwiftAsyncWebsocket.xcworkspace
```

And then build the project and drag the framework to your project

### 2. CocoaPods
Add following commands to your podfile

```
pod 'SwiftAsyncWebsocket'
```

And then run `pod install`

### 3. Carthage
SwiftAsyncWebsocket is [Carthage](https://github.com/Carthage/Carthage) compatible. To include it add the following line to your `Cartfile`

```bash
github "chouheiwa/SwiftAsyncWebsocket"
```

## Usage

1. Create request and connect
```
guard let url = URL(string: "ws://demos.kaazing.com/echo") else {
    return
}

let request = URLRequest(url: url)

do {
    let header = try RequestHeader(request: request)

    let websocket = SwiftAsyncWebsocket(requestHeader: header, delegate: self, delegateQueue: DispatchQueue.main)

    try websocket.connect()
} catch let error as WebsocketError {
    print("\(error)")
} catch {
    fatalError()
}
```

In real project, you need to control websocket lifecycle by yourself. And you need to implement the websocket delegate method.

There has been a demo for simple use SwiftAsyncWebsocket

Demo page: https://github.com/SwiftAsyncSocket/SwiftAsyncWebsocketDemo