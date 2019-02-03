//
//  Response.swift
//  SwiftAsyncWebsocket
//
//  Created by chouheiwa on 2019/2/2.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation
import CryptoSwift

public class ResponseHeader {
    static let appendSecKey = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    public var status: Int {
        return 101
    }

    public let header: [String: String]

    init(headerData: Data, requestHeader: RequestHeader) throws {
        guard let responseString = String(data: headerData, encoding: .utf8) else {
            throw WebsocketError.responseHeaderParser
        }
        let arr = responseString.components(separatedBy: "\r\n")

        guard arr.count > 0 else {
            throw WebsocketError.responseHeaderParser
        }

        try ResponseHeader.checkStatus(arr)

        header = ResponseHeader.parseToHeader(arr)

        try checkWebsocketHandshake(requestHeader: requestHeader)

        try checkWebsocketProtocol(requestHeader: requestHeader)
    }

    class func checkStatus(_ arr: [String]) throws {
        let firstArr = arr[0].split(separator: " ")

        guard firstArr.count > 1 else {
            throw WebsocketError.responseHeaderParser
        }

        guard let status = Int(firstArr[1]) else {
            throw WebsocketError.responseHeaderParser
        }

        guard status == 101 else {
            throw WebsocketError.responseStatusError(status: status)
        }
    }

    class func parseToHeader(_ arr: [String]) -> [String: String] {
        var header = [String: String]()

        for index in 1..<arr.count {
            let item = arr[index]

            let itemArr = item.components(separatedBy: ": ")

            if itemArr.count < 2 {
                continue
            }
            let key = itemArr[0]

            var value = header[key] ?? ""

            if value.count > 0 {
                value = "\(value); "
            }

            value = "\(value)\(itemArr[1])"

            header[key] = value
        }

        return header
    }

    func checkWebsocketHandshake(requestHeader: RequestHeader) throws {
        guard let shakeKey = header["Sec-WebSocket-Accept"] else {
            throw WebsocketError.responseSecError
        }

        let client = requestHeader.secKey + ResponseHeader.appendSecKey

        let clientKey = (client.data(using: .utf8) ?? Data()).sha1()
            .base64EncodedString()

        guard shakeKey == clientKey else {
            throw WebsocketError.responseSecError
        }
    }

    func checkWebsocketProtocol(requestHeader: RequestHeader) throws {
        guard let protocols = header["Sec-WebSocket-Protocol"] else { return }

        guard let protocolArray = requestHeader.protocols,
            (protocolArray.contains(protocols)) else {
                throw WebsocketError.responseProtolError(pro: protocols)
        }

        requestHeader.usedProtocol = protocols
    }
}
