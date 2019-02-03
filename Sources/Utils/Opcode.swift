//
//  Opcode.swift
//  SwiftAsyncWebsocket
//
//  Created by chouheiwa on 2019/2/1.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

enum Opcode: UInt8 {
    /// Text Opcode
    case TEXT = 0x1
    /// Binary Opcode
    case BINARY = 0x2
    // Control Frame Code
    case PING = 0x9, PONG = 0xA
    case CLOSING = 0x8
    case CONTINUOUS = 0x0

    var isControlFrame: Bool {
        switch self {
        case .TEXT,.BINARY:
            return false
        default:
            return true
        }
    }
}
