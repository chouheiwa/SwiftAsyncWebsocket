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
    func websocketDidConnect(_ websocket: SwiftAsyncWebsocket)

    func websocketDidDisconnect(_ websocket: SwiftAsyncWebsocket, error: WebsocketError?)
}
