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

    public var kind: DataControlKind = .finalReturn

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

    var currentFrameTimes: Int = 0

    var currentCode: Opcode?

    var cacheData: Data?

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

    public func send(text: String) {
        guard state == .open else {
            return
        }

        guard let data = text.data(using: .utf8) else {
            fatalError("convert UTF8 data failed")
        }

        let frameData = FrameData(opcode: .TEXT, data: data)

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

    func handleReceive(frameData: FrameData) throws {
        switch frameData.opcode {
        case .PING:
            guard let data = delegate?.websocket(self,
                                                 didReceivePing: frameData.data) else {
                return
            }
            

            let pongFrameData = FrameData(opcode: .PONG, data: data)

            socket.write(data: pongFrameData.caculateToSendData(), timeOut: -1, tag: 1)
        case .PONG:
            delegate?.websocket(self, didReceovePong: frameData.data)
        case .CLOSING:
            guard state == .open else {
                socket.disconnect()
                return
            }

            state = .closing
            let frameData = FrameData(opcode: .CLOSING, data: Data())
            socket.write(data: frameData.caculateToSendData(), timeOut: -1, tag: 1)
            socket.disconnectAfterWriting()
        case .CONTINUOUS:
            try handleContinuous(data: frameData)
        case .BINARY:
            try handleData(frameData: frameData)
        case .TEXT:
            try handleData(frameData: frameData)
        }
    }

    func handleData(frameData: FrameData) throws {
        if frameData.isOver {
            var data: Any = frameData.data

            if frameData.opcode == .TEXT {
                guard let string = String(data: frameData.data, encoding: .utf8) else {
                    throw WebsocketError.responseProtolError(pro:
                        "Server response can not parsed to UTF8 ")
                }

                data = string
            }

            delegate?.websocket(self, didReceive: data, type: frameData.opcode, isFinalData: true)
        } else {
            guard currentFrameTimes == 0 &&
                currentCode == nil &&
                cacheData == nil else {
                    throw WebsocketError.responseProtolError(pro:
                        "Server can not reset code when in continuous mode")
            }

            handleContinuousStart(code: frameData.opcode, data: frameData.data)
        }
    }

    func handleContinuousStart(code: Opcode, data: Data) {
        currentCode = code
        currentFrameTimes += 1

        switch kind {
        case .eachReturn:
            delegate?.websocket(self, didReceive: data, type: code, isFinalData: false)
        default:
            cacheData = data
        }
    }

    func handleContinuous(data: FrameData) throws {
        guard let currentCode = currentCode, var cacheData = cacheData,
            (currentFrameTimes != 0) else {
                throw WebsocketError.responseProtolError(pro:
                    "Server can not send a CONTINUOUS data before a type data")
        }

        currentFrameTimes += 1
        switch kind {
        case .eachReturn:
            delegate?.websocket(self, didReceive: data.data, type: currentCode, isFinalData: data.isOver)
        case .finalReturn:
            cacheData.append(data.data)

            if data.isOver {
                var any: Any

                switch currentCode {
                case .BINARY:
                    any = cacheData
                case .TEXT:
                    guard let utf8String = String(data: cacheData, encoding: .utf8) else {
                        throw WebsocketError.responseProtolError(pro:
                            "Server response can not parsed to UTF8 ")
                    }
                    any = utf8String
                default:
                    fatalError("Logic error")
                }

                delegate?.websocket(self, didReceive: any, type: currentCode, isFinalData: true)

                currentFrameTimes = 0

                self.cacheData = nil

                self.currentCode = nil
            } else {
                self.cacheData = cacheData

                currentFrameTimes += 1
            }
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

                try handleReceive(frameData: frameData)

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

        var webError: WebsocketError?

        if let error = error {
            switch error {
            case .connectionClosedError:
                webError = WebsocketError.serverClose
            default:
                webError = WebsocketError.otherCloseError(error: error)
            }
        }

        delegate?.websocket(self, didCloseWith: webError)
    }
}
