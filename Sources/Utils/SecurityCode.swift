//
//  SecurityCode.swift
//  SwiftAsyncWebsocket
//
//  Created by chouheiwa on 2019/2/1.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

func randomData(_ length: Int) -> Data {
    let data = Data(count: length);

    let result = Security.SecRandomCopyBytes(kSecRandomDefault,
                                             length,
                                             data.withUnsafeBytes({UnsafeMutableRawPointer(mutating: $0)}))

    guard result == 0 else {
        fatalError("Failed to generate random bytes with OSStatus: \(result)")
    }
    return data
}
