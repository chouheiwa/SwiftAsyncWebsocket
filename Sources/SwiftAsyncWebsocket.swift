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

    public enum StatusCode: UInt16 {
        // 0-999: reserved and not used
        case normal = 1000
        case goingAway =  1001
        case protocolError = 1002
        case unhandleType = 1003
        // 1004 reserved
        case noStatusReceived = 1005
        case abnormal = 1006
        case invalidUTF8 = 1007
        case policyViolated = 1008
        case messageTooBig = 1009
        case missingExtension = 1010
        case internalError = 1011
        case serviceRestart = 1012
        case tryagainLater = 1013
        // 1014: Reserved for future use by the WebSocket standard.
        case TLSHandshake = 1015
        // 1016-1999: Reserved for future use by the WebSocket standard.
        // 2000-2999: Reserved for use by WebSocket extensions.
        // 3000-3999: Available for use by libraries and frameworks. May not be used by applications. Available for registration at the IANA via first-come, first-serve.
        // 4000-4999: Available for use by applications.
        
    }

    let socket: SwiftAsyncSocket
    public weak var delegate: SwiftAsyncWebsocketDelegate?

    public let requestHeader: RequestHeader

    public internal(set) var responseHeader: ResponseHeader?

    public var state: State = .closed

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

    var closeData: CloseData?

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

        socket.socketQueueDo {
            self.state = .connecting
        }
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

    public func send(pingData: Data?) {
        guard state == .open else {
            return
        }

        let frameData = FrameData(opcode: .PING, data: pingData ?? Data())

        socket.write(data: frameData.caculateToSendData(), timeOut: -1, tag: 1)
    }

    public func close(code: StatusCode = .normal, reason: String? = nil) {
        guard state == .open || state == .connecting else {
            return
        }

        socket.socketQueueDo {
            self.state = .closing
        }

        guard state == .open else {

            socket.disconnect()
            return
        }

        let closeData = CloseData(closeCode: code, closeReason: reason)

        socket.write(data: closeData.convertToSendData(), timeOut: -1, tag: 1)
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
            switch error {
            case .responseProtolError(pro: let msg):
                close(code: .protocolError, reason: msg)
                socket.disconnectAfterWriting()
            default:
                socket.userData = error
                socket.disconnect()
            }
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
            handleClose(data: frameData)
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

    func handleClose(data: FrameData) {
        guard state == .open else {
            socket.disconnect()
            return
        }

        state = .closing

        do {
            let closeData = try CloseData(data: data.data)

            self.closeData = closeData

            close(code: .normal, reason: nil)
        } catch let error as CloseData.CloseError {
            close(code: .protocolError, reason: error.reason)
        } catch {
            fatalError("\(error)")
        }

        socket.disconnectAfterWriting()
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
        delegate?.websocketDidConnect(self)
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
        
        socket.socketQueueDo {
            self.state = .closed
        }

        if let closeData = closeData {
            delegate?.websocket(self, didCloseWith: closeData.closeCode, reason: closeData.closeReason)
            return
        }

        if let error = socket.userData as? WebsocketError {
            delegate?.websocket(self, failedConnect: error)
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

        delegate?.websocket(self, failedConnect: webError)
    }
}
