//
//  SIMDHelper.swift
//  SwiftAsyncWebsocket
//
//  Created by chouheiwa on 2019/2/2.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

struct SIMDHelper {
    static func MaskBytesSIMD(bytes: UnsafeMutablePointer<UInt8>, length: Int, maskKey: UnsafeMutablePointer<UInt8>) {
        for indexI in 0..<length {
            let indexJ = indexI % 4

            (bytes + indexI).pointee ^= (maskKey + indexJ).pointee
        }
    }
}
