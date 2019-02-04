//
//  SwiftAsyncWebsocketDelegate.swift
//  SwiftAsyncWebsocket
//
//  Created by chouheiwa on 2019/1/31.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

public protocol SwiftAsyncWebsocketDelegate: class {
    /// When function
    ///
    /// - Parameter websocket: websocket
    func websocketDidOpen(_ websocket: SwiftAsyncWebsocket)

    func websocket(_ websocket: SwiftAsyncWebsocket,didCloseWith error: WebsocketError?)

    /// This function will be called when websocket receive ping data
    /// Under normal condition, the ping data will be empty
    /// But in RF6455 the control frame can send less then 125 bytes data
    ///
    /// - Parameters:
    ///   - websocket: websocket
    ///   - data: ping data (most case is empty)
    func websocket(_ websocket: SwiftAsyncWebsocket,didReceivePing data: Data)
}
