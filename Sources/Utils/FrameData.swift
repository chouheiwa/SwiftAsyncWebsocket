//
//  FrameData.swift
//  SwiftAsyncWebsocket
//
//  Created by chouheiwa on 2019/2/3.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import Foundation

struct FrameData {
    static let frameHeeaderLength = 32
    struct Mask {
        static let FIN: UInt8 = 0x80
        static let Opcode: UInt8 = 0x0F
        static let Rsv: UInt8 = 0x70
        static let Mask: UInt8 = 0x80
        static let PayLoadLen: UInt8 = 0x7F
    }

    var data: Data
    let opcode: Opcode
    let isOver: Bool

    init(opcode: Opcode, data: Data) {
        self.data = data
        self.opcode = opcode
        self.isOver = true
    }

    /* From RFC:

     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-------+-+-------------+-------------------------------+
     |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
     |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
     |N|V|V|V|       |S|             |   (if payload len==126/127)   |
     | |1|2|3|       |K|             |                               |
     +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
     |     Extended payload length continued, if payload len == 127  |
     + - - - - - - - - - - - - - - - +-------------------------------+
     |                               |Masking-key, if MASK set to 1  |
     +-------------------------------+-------------------------------+
     | Masking-key (continued)       |          Payload Data         |
     +-------------------------------- - - - - - - - - - - - - - - - +
     :                     Payload Data continued ...                :
     + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
     |                     Payload Data continued ...                |
     +---------------------------------------------------------------+
     */
    init(receiveData: Data) throws {
        var pointer: UnsafePointer<UInt8> = receiveData.withUnsafeBytes({$0})

        guard pointer.pointee & Mask.Rsv == 0 else {
            throw WebsocketError.responseProtolError(pro: "Server used RSV bits")
        }
        // Fin and Opcode
        self.isOver = (pointer.pointee & Mask.FIN) == 0x1
        // Here use
        guard let opcode = Opcode(rawValue: pointer.pointee & Mask.Opcode) else {
            throw WebsocketError.responseProtolError(pro:
                "Server return undefine Opcode")
        }

        self.opcode = opcode
        // Mask
        pointer += 1

        guard (pointer.pointee & Mask.Mask) == 0 else {
            throw WebsocketError.responseProtolError(pro:
                "Serve can not return masked data")
        }

        let payloadLength = pointer.pointee & Mask.PayLoadLen

        if opcode.isControlFrame {
            guard payloadLength < 126 else {
                throw WebsocketError.responseProtolError(pro:
                    "Control frame can not big then 125 bytes")
            }
        }
        // Confirm totalPayloadLength
        pointer += 1

        var totalPayLoadLength = UInt64(payloadLength)

        if payloadLength == 126 {
            var valueLength = pointer.withMemoryRebound(to: UInt16.self, capacity: 1, {$0.pointee})

            valueLength = CFSwapInt16BigToHost(valueLength)

            pointer += 2

            totalPayLoadLength = UInt64(valueLength)
        } else if payloadLength == 127 {
            var valueLength = pointer.withMemoryRebound(to: UInt64.self, capacity: 1, {$0.pointee})

            valueLength = CFSwapInt64BigToHost(valueLength)

            pointer += 4

            totalPayLoadLength = valueLength
        }

        self.data = Data(bytes: pointer, count: Int(totalPayLoadLength))
    }

    func caculateToSendData() -> Data {
        let payloadLength = data.count

        let opcode = self.opcode.rawValue

        var totalSendData = Data(count: payloadLength +
            FrameData.frameHeeaderLength)

        let pointer: UnsafeMutablePointer<UInt8> = totalSendData.withUnsafeMutableBytes({$0})
        // Set Fin
        pointer.pointee = Mask.FIN | opcode

        let maskPointer = pointer + 1
        // set the mask
        maskPointer.pointee |= Mask.Mask
        // set pay load length
        var frameBufferSize: size_t = 2

        if payloadLength < 126 {
            maskPointer.pointee |= UInt8(payloadLength)
        } else {
            var declaredPayloadLength: UInt64 = 0
            var declaredPayloadLengthSize = 0

            if payloadLength <= UInt16.max {
                maskPointer.pointee |= 126

                declaredPayloadLength = UInt64(CFSwapInt16BigToHost(UInt16(payloadLength)))
                declaredPayloadLengthSize = MemoryLayout<UInt16>.size
            } else {
                maskPointer.pointee |= 127

                declaredPayloadLength = CFSwapInt64BigToHost(UInt64(payloadLength))
                declaredPayloadLengthSize = MemoryLayout<UInt64>.size
            }

            Darwin.memcpy(pointer + frameBufferSize,
                          &declaredPayloadLength,
                          declaredPayloadLengthSize)
            frameBufferSize += declaredPayloadLengthSize
        }

        let unmaskedPayloadBuffer: UnsafePointer<UInt8> = data.withUnsafeBytes({$0})

        let maskKey = pointer + frameBufferSize
        // set MaskKey
        let randomBytesSize = MemoryLayout<UInt32>.size
        //TODO: (nlutsenko) Check if there was an error.
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytesSize, maskKey)

        frameBufferSize += randomBytesSize

        let frameBufferPayloadPointer = pointer + frameBufferSize

        memcpy(frameBufferPayloadPointer, unmaskedPayloadBuffer, payloadLength)

        SIMDHelper.MaskBytesSIMD(bytes: frameBufferPayloadPointer, length: payloadLength, maskKey: maskKey)

        totalSendData.count = payloadLength + frameBufferSize

        return totalSendData
    }
}
