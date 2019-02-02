//
//  RequestHeader.swift
//  SwiftAsyncWebsocket
//
//  Created by Di on 2019/2/1.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

/// User set Request
public class RequestHeader {
    enum Scheme {
        case ws, wss

        var port: UInt16 {
            switch self {
            case .wss:
                return 443
            default:
                return 80
            }
        }

        init(_ scheme: String) throws {
            if scheme == "ws" {
                self = .ws
            } else if scheme == "wss" {
                self = .wss
            } else {
                throw WebsocketError.urlScheme
            }
        }
    }
    /// RFC 6455 websocket version is 13
    static let websocketVersion = 13
    /// Current Request
    public let request: URLRequest
    /// If that server need to auth your origin
    public var origin: String?
    
    public let host: String

    public var protocols: [String]?

    public var cookies: [HTTPCookie]?

    let port: UInt16

    let secKey: String

    /// Create a request Header with URLRequest
    /// If Request.timeout == 0 that means no time out
    ///
    /// - Parameter request: request
    /// - Throws: Scheme Error
    public init(request: URLRequest) throws {
        let scheme = try Scheme(request.url?.scheme ?? "")

        var totalPort = scheme.port

        self.request = request

        host = request.url?.host ?? ""

        if let port = request.url?.port {
            totalPort = UInt16(port)
        }

        port = totalPort

        secKey = randomData(16).base64EncodedString()
    }

    func toData() -> Data {
        let path = request.url?.path ?? ""

        var host = self.host

        if let port = request.url?.port {
            host = "\(host):\(port)"
        }

        var headerString = "GET \(path.count == 0 ? "/" : path) HTTP/1.1\r\n"
            + "Host: \(host)\r\n"
            + "Upgrade: websocket\r\n"
            + "Connection: Upgrade\r\n"
            + "Sec-WebSocket-Key: \(secKey)\r\n"
            + "Sec-WebSocket-Version: \(RequestHeader.websocketVersion)\r\n"

        if let origin = origin {
            headerString += "Origin: \(origin)\r\n"
        }

        if let cookies = cookies {
            let cookieMessage = HTTPCookie.requestHeaderFields(with: cookies)

            for (key, value) in cookieMessage.enumerated() {
                headerString += "\(key): \(value)\r\n"
            }
        }

        if let protocols = protocols {
            headerString += "Sec-WebSocket-Protocol: \(protocols.joined(separator: ", "))\r\n"
        }

        if let allHeaders = request.allHTTPHeaderFields {
            for (key, value) in allHeaders.enumerated() {
                headerString += "\(key): \(value)\r\n"
            }
        }

        headerString += "\r\n"

        guard let data = headerString.data(using: .utf8) else {
            fatalError("Error when transfer string to utf8 data")
        }

        return data
    }
}
