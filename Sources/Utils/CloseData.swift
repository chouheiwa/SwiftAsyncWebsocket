//
//  CloseData.swift
//  SwiftAsyncWebsocket
//
//  Created by chouheiwa on 2019/2/12.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

struct CloseData {
    struct CloseError: Error {
        let reason: String
    }

    let closeCode: UInt16

    var closeReason: String?

    init(data: Data) throws {

        if data.count == 0 {
            closeCode = SwiftAsyncWebsocket.StatusCode.noStatusReceived.rawValue
            return
        }

        guard data.count >= 2 else {
             throw CloseError(reason: "Payload for close must be larger than 2 bytes")
        }

        let codeNum = data.withUnsafeBytes({CFSwapInt16($0.pointee)})

        guard CloseData.canHandle(codeNum) else {
            throw CloseError(reason: "Cannot have close code of \(codeNum)")
        }

        self.closeCode = codeNum

        guard data.count > 2 else {
            return
        }

        guard let closeReason = String(data: data[2..<data.count], encoding: .utf8) else {
            throw CloseError(reason: "Close reason MUST be valid UTF-8")
        }

        self.closeReason = closeReason
    }

    init(closeCode: SwiftAsyncWebsocket.StatusCode,
         closeReason: String?) {
        self.closeCode = closeCode.rawValue
        self.closeReason = closeReason
    }

    func convertToSendData() -> Data {
        let closeReasonUTF8 = (closeReason ?? "").data(using: .utf8) ?? Data()

        let size = MemoryLayout<UInt16>.size

        var sendData = Data(count: min(125, closeReasonUTF8.count + size))

        sendData.withUnsafeMutableBytes {
            $0.pointee = CFSwapInt16(closeCode)
        }

        if closeReasonUTF8.count > 0 {
            let totalIndex = sendData.count - 1

            sendData.replaceSubrange(size..<totalIndex,
                                     with: closeReasonUTF8.withUnsafeBytes({UnsafeRawPointer($0)}),
                                     count: min(123, sendData.count))
        }

        let frameData = FrameData(opcode: .CLOSING, data: sendData)

        return frameData.caculateToSendData()
    }

    static func canHandle(_ closeCode: UInt16) -> Bool {
        if closeCode < 1000 {
            return false
        }

        if closeCode >= 1000 && closeCode <= 1011 {
            if (closeCode == 1004 ||
                closeCode == 1005 ||
                closeCode == 1006) {
                return false
            }
            return true
        }

        if (closeCode >= 3000 && closeCode <= 3999) {
            return true
        }

        if (closeCode >= 4000 && closeCode <= 4999) {
            return true
        }

        return false
    }
}
