//
//  SwiftAsyncWebsocketDelegate.swift
//  SwiftAsyncWebsocket
//
//  Created by chouheiwa on 2019/1/31.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

public protocol SwiftAsyncWebsocketDelegate: class {
    /// The websocket has already finished connection and can receive or send data
    ///
    /// - Parameter websocket: websocket
    func websocketDidOpen(_ websocket: SwiftAsyncWebsocket)
    /// If websocket.state == .finalReturn then fin will always be true
    /// else when we return the final data it will be true otherwise will be false
    ///
    /// - Parameters:
    ///   - websocket: websocket
    ///   - messgae: the return message
    ///              In finalReturn message will be the same type with param type (Data|String)
    ///              In eachReturn message will always be the Data if we receive a continous data
    ///              you need to process data by your own
    ///   - type: type (BINARY | TEXT)
    ///   - fin: is the final data
    func websocket(_ websocket: SwiftAsyncWebsocket, didReceive messgae: Any, type: Opcode, isFinalData fin: Bool)
    ///
    ///
    /// - Parameters:
    ///   - websocket:
    ///   - error:
    func websocket(_ websocket: SwiftAsyncWebsocket, didCloseWith error: WebsocketError?)
    /// This function will be called when websocket receive ping data
    /// Under normal condition, the ping data will be empty
    /// But in RF6455 the control frame can send less then 125 bytes data
    ///
    /// - Parameters:
    ///   - websocket: websocket
    ///   - data: ping data (most case is empty)
    /// - Returns: If return data is nil then websocket will ignore ping data
    ///        if you want to reply to pong, you can return a data
    func websocket(_ websocket: SwiftAsyncWebsocket, didReceivePing data: Data) -> Data?

    /// This method will be called when we receive Pong data from server
    ///
    /// - Parameters:
    ///   - websocket: websocket
    ///   - data: pong data
    func websocket(_ websocket: SwiftAsyncWebsocket, didReceovePong data: Data)
}
