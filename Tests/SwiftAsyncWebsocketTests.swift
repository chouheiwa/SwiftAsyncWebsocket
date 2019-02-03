//
//  SwiftAsyncWebsocketTests.swift
//  SwiftAsyncWebsocketTests
//
//  Created by chouheiwa on 2019/2/2.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import XCTest
@testable import SwiftAsyncWebsocket
class SwiftAsyncWebsocketTests: XCTestCase {

    var socket: SwiftAsyncWebsocket!

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        guard let url = URL(string: "ws://demos.kaazing.com/echo") else {
            fatalError("Error when create URL")
        }

        let request = URLRequest(url: url)

        do {
            let header = try RequestHeader(request: request)
            socket = SwiftAsyncWebsocket(requestHeader: header, delegate: self, delegateQueue: DispatchQueue.main)
        } catch {
            fatalError("\(error)")
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        let exception = XCTestExpectation(description: "11111111")
        try! socket.connect()
        self.wait(for: [exception], timeout: 100)
    }

}

extension SwiftAsyncWebsocketTests : SwiftAsyncWebsocketDelegate {
    func websocketDidConnect(_ websocket: SwiftAsyncWebsocket) {

    }

    func websocketDidDisconnect(_ websocket: SwiftAsyncWebsocket, error: WebsocketError?) {

    }


}
