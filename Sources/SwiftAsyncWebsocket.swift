//
//  SwiftAsyncWebsocket.swift
//  SwiftAsyncWebsocket
//
//  Created by chouheiwa on 2019/1/31.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation
import SwiftAsyncSocket

public class SwiftAsyncWebsocket {
    public enum State {
        case connecting, open, closing, closed
    }

    /// In websocket there has two kinds receive data
    /// 1. All data send in one time
    /// 2. Send data with chunk
    /// So this two kind means when we receive (2) data,
    ///
    /// - finalReturn: return entire data
    ///     finalReturn is that SwiftAsyncWebsocket hold the process data
    ///     call the delegate when we receive the fin data
    ///     it will return all the process data into an entire data
    ///     It is the defaut setting
    /// - eachReturn: return partical data
    ///     eachReturn means each time SwiftAsyncWebsocket received data,
    ///     delegate will be called, no data will be cached
    public enum DataControlKind {
        case finalReturn
        case eachReturn
    }

    let socket: SwiftAsyncSocket
    public weak var delegate: SwiftAsyncWebsocketDelegate?

    public let requestHeader: RequestHeader

    public internal(set) var responseHeader: ResponseHeader?

    public var state: State = .connecting

    public var kind: DataControlKind = .eachReturn

    public var delegateQueue: DispatchQueue? {
        set {
            socket.delegateQueue = newValue
        }

        get {
            return socket.delegateQueue
        }
    }

    var timeout: TimeInterval {
        return requestHeader.request.timeoutInterval > 0 ?
            requestHeader.request.timeoutInterval : -1
    }

    fileprivate var connectedTime: TimeInterval!

    public init(requestHeader: RequestHeader,
                delegate: SwiftAsyncWebsocketDelegate?,
                delegateQueue: DispatchQueue?,
                socketQueue: DispatchQueue? = nil) {
        socket = SwiftAsyncSocket(delegate: nil, delegateQueue: delegateQueue, socketQueue: socketQueue)

        self.requestHeader = requestHeader
        self.delegate = delegate

        socket.delegate = self
    }

    public func connect() throws {
        self.connectedTime = Date().timeIntervalSince1970

        try socket.connect(toHost: requestHeader.host, onPort: requestHeader.port, timeOut: timeout)
    }

    public func send(data: Data) {
        guard state == .open else {
            return
        }

        let frameData = FrameData(opcode: .BINARY, data: data)

        socket.write(data: frameData.caculateToSendData(), timeOut: -1, tag: 1)
    }

    func judgeTimeOut() throws -> TimeInterval {
        let connnectDate = Date().timeIntervalSince1970

        let connectingTime = connnectDate - connectedTime

        var leftTime: TimeInterval = -1

        if timeout > 0 {
            leftTime = timeout - connectingTime

            guard leftTime >= 0 else {
                throw WebsocketError.timeout
            }
        }

        return leftTime
    }

    func handleError(_ block: () throws ->()) {
        do {
            try block()
        } catch let error as WebsocketError {

            print("Error:\(error)")

            socket.userData = error
            socket.disconnect()
        } catch {
            fatalError("\(error)")
        }
    }

    func handleReceive(frameData: FrameData) {

    }
}

extension SwiftAsyncWebsocket: SwiftAsyncSocketDelegate {
    enum DataType {
        case prepare, ready

        var rawValue: Int {
            switch self {
            case .prepare:
                return 0
            case .ready:
                return 1
            }
        }

        init(_ rawValue: Int) {
            if rawValue == 0 {
                self = .prepare
            } else {
                self = .ready
            }
        }
    }

    public func socket(_ socket: SwiftAsyncSocket, didConnect toHost: String, port: UInt16) {
        handleError {
            socket.write(data: requestHeader.toData(), timeOut: -1, tag: DataType.prepare.rawValue)
            socket.readData(toData: SwiftAsyncSocket.CRLFData + SwiftAsyncSocket.CRLFData,
                            timeOut: try judgeTimeOut(), tag: DataType.prepare.rawValue)
        }
    }

    public func socket(_ soclet: SwiftAsyncSocket, shouldTimeoutReadWith tag: Int, elapsed: TimeInterval, bytesDone: UInt) -> TimeInterval? {
        soclet.userData = WebsocketError.timeout
        return nil
    }

    public func socket(_ socket: SwiftAsyncSocket, didRead data: Data, with tag: Int) {
        let type = DataType(tag)
        handleError {
            switch type {
            case .prepare:

                let _ = try judgeTimeOut()

                responseHeader = try ResponseHeader(headerData: data, requestHeader: requestHeader)

                self.state = .open

                delegate?.websocketDidOpen(self)

                socket.readData(timeOut: -1, tag: DataType.ready.rawValue)

            default:
                let frameData = try FrameData(receiveData: data)



                socket.readData(timeOut: -1, tag: DataType.ready.rawValue)
            }
        }

    }

    public func socket(_ socket: SwiftAsyncSocket?, didDisconnectWith error: SwiftAsyncSocketError?) {
        guard let socket = socket else { return }

        self.state = .closed

        if let error = socket.userData as? WebsocketError {
            delegate?.websocket(self, didCloseWith: error)
            return
        }
    }
}
