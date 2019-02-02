//
//  WebsocketError.swift
//  SwiftAsyncWebsocket
//
//  Created by Di on 2019/2/1.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

public enum WebsocketError: Error {
    case urlScheme, timeout
}

extension WebsocketError: CustomStringConvertible {
    public var description: String {
        let errorDomain = "Error Domain: SwiftAsyncWebsocketError"

        switch self {
        case .urlScheme:
            return "\(errorDomain) Reason: Request scheme must be either 'ws' or 'wss'"
        case .timeout:
            return "\(errorDomain) Reason: Request timeout"
        }
    }


}
