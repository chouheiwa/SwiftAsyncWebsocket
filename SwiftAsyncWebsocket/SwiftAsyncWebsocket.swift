//
//  SwiftAsyncWebsocket.swift
//  SwiftAsyncWebsocket
//
//  Created by Di on 2019/1/31.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation
import SwiftAsyncSocket

public class SwiftAsyncWebsocket {
    let socket: SwiftAsyncSocket
    public weak var delegate: SwiftAsyncWebsocketDelegate?

    public let requestHeader: RequestHeader

    public internal(set) var responseHeader: Response?

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

        socket.delegate = self
    }

    public func connect() throws {
        self.connectedTime = Date().timeIntervalSince1970

        try socket.connect(toHost: requestHeader.host, onPort: requestHeader.port, timeOut: timeout)
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

    func handleTimeout(_ block: () throws ->()) {
        do {
            try block()
        } catch let error as WebsocketError {
            socket.userData = error
            socket.disconnect()
        } catch {
            fatalError("\(error)")
        }
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
        handleTimeout {
            socket.write(data: requestHeader.toData(), timeOut: try judgeTimeOut(), tag: DataType.prepare.rawValue)
            socket.readData(toData: SwiftAsyncSocket.CRLFData + SwiftAsyncSocket.CRLFData,
                            timeOut: try judgeTimeOut(), tag: DataType.prepare.rawValue)
        }
    }

    public func socket(_ socket: SwiftAsyncSocket, didWriteDataWith tag: Int) {}

    public func socket(_ socket: SwiftAsyncSocket, didRead data: Data, with tag: Int) {
        let type = DataType(tag)

        switch type {
        case .prepare:
            handleTimeout {
                let _ = try judgeTimeOut()

                responseHeader = try Response(headerData: data, requestHeader: requestHeader)

                delegate?.websocketDidConnect(self)

                socket.readData(timeOut: -1, tag: DataType.ready.rawValue)
            }
        default:
            socket.readData(timeOut: -1, tag: DataType.ready.rawValue)
        }

    }

    public func socket(_ socket: SwiftAsyncSocket?, didDisconnectWith error: SwiftAsyncSocketError?) {
        guard let socket = socket else { return }

        print("error: \(error)")

        if let error = socket.userData as? WebsocketError {
            delegate?.websocketDidDisconnect(self, error: error)
            return
        }
    }
}
