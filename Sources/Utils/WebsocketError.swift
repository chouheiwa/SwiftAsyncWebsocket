//
//  WebsocketError.swift
//  SwiftAsyncWebsocket
//
//  Created by chouheiwa on 2019/2/1.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation
import SwiftAsyncSocket
public enum WebsocketError: Error {
    case urlScheme, timeout
    case responseHeaderParser
    case responseStatusError(status: Int)
    case responseSecError
    case responseProtolError(pro: String)
    case serverClose
    case otherCloseError(error: SwiftAsyncSocketError)
}

extension WebsocketError: CustomStringConvertible {
    public var description: String {
        let errorDomain = "Error Domain: SwiftAsyncWebsocketError"

        switch self {
        case .urlScheme:
            return "\(errorDomain) Reason: Request scheme must be either 'ws' or 'wss'"
        case .timeout:
            return "\(errorDomain) Reason: Request timeout or the server does not return the specify message"
        case .responseHeaderParser:
            return "\(errorDomain) Reason: Parser Response Error"
        case .responseStatusError(status: let status):
            return "\(errorDomain) Reason: Received bad response code from server. Code: \(status)"
        case .responseSecError:
            return "\(errorDomain) Reason: Server not confirm Sec-WebSocket-Accept, or response was wrong"
        case .responseProtolError(pro: let pro):
            return "\(errorDomain) Reason: Server specified Sec-WebSocket-Protocol \"\(pro)\" that wasn't requested."
        case .serverClose:
            return "\(errorDomain) Reason: Connection closed by peer"
        case .otherCloseError(error: let error):
            return "\(errorDomain) Reason: \(error)"

        }
    }


}
