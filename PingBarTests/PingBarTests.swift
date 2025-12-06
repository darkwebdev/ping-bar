//
//  PingBarTests.swift
//  PingBarTests
//
//  Created by Manyanov, Timur on 11.09.25.
//

import Foundation
import XCTest
@testable import PingBar

final class FakePingProvider: PingProviding {
    var observer: Observer?
    var targetCount: Int?
    private let behavior: Behavior
    enum Behavior {
        case immediateSuccess
        case timeout
        case slowResponse(TimeInterval)
        case networkOff
        case dnsError
        case intermittent([Behavior])
    }
    private var intermittentIndex = 0
    init(behavior: Behavior) {
        self.behavior = behavior
    }
    func startPinging() throws {
        var effectiveBehavior = behavior
        if case .intermittent(let seq) = behavior {
            if seq.isEmpty {
                effectiveBehavior = .timeout
            } else {
                effectiveBehavior = seq[intermittentIndex % seq.count]
                intermittentIndex += 1
            }
        }
        switch effectiveBehavior {
        case .intermittent:
            // should already be resolved to an effective behavior; treat as timeout fallback
            break
        case .immediateSuccess:
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) { [weak self] in
                guard let self = self else { return }
                let response = PingResponse(identifier: 0, ipAddress: "127.0.0.1", sequenceNumber: 0, trueSequenceNumber: 0, duration: 0.01, error: nil, byteCount: 64, ipHeader: nil)
                self.observer?(response)
            }
        case .timeout:
            // never call observer to simulate timeout
            break
        case .slowResponse(let delay):
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                let response = PingResponse(identifier: 0, ipAddress: "127.0.0.1", sequenceNumber: 0, trueSequenceNumber: 0, duration: delay, error: nil, byteCount: 64, ipHeader: nil)
                self.observer?(response)
            }
        case .networkOff:
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        case .dnsError:
            throw PingError.addressLookupError
        }
    }
    func haltPinging(resetSequence: Bool) {
        // no-op
    }
}

final class TestDelegate: PingManagerDelegate {
    var lastResult: Int?
    var lastError: String?
    var resultExpectation: XCTestExpectation?
    var errorExpectation: XCTestExpectation?

    func pingManager(_ manager: PingManager, didReceivePingResult result: Int) {
        lastResult = result
        resultExpectation?.fulfill()
    }
    func pingManager(_ manager: PingManager, didFailWithError error: String) {
        lastError = error
        errorExpectation?.fulfill()
    }
}

final class PingBarTests: XCTestCase {

    func testNetworkOffShouldReportErrorQuickly() async throws {
        let manager = PingManager()
        let delegate = TestDelegate()
        let exp = expectation(description: "error reported")
        delegate.errorExpectation = exp
        manager.delegate = delegate
        manager.pingerFactory = { host in
            return FakePingProvider(behavior: .networkOff)
        }
        manager.startPinging()
        await fulfillment(of: [exp], timeout: 1.0)
        manager.stopPinging()
        XCTAssertNotNil(delegate.lastError)
    }

    func testSlowResponseDoesNotBlockAndEventuallyReports() async throws {
        let manager = PingManager()
        let delegate = TestDelegate()
        let exp = expectation(description: "response reported")
        delegate.resultExpectation = exp
        manager.delegate = delegate
        manager.pingerFactory = { host in
            return FakePingProvider(behavior: .slowResponse(0.5))
        }
        let start = Date()
        manager.startPinging()
        let elapsed = Date().timeIntervalSince(start)
        // startPinging should return quickly (non-blocking). Assert it returns within 0.2s.
        XCTAssertLessThan(elapsed, 0.2)
        await fulfillment(of: [exp], timeout: 2.0)
        manager.stopPinging()
        XCTAssertNotNil(delegate.lastResult)
    }

    func testTimeoutOnlyDoesNotBlockAndReportsTimeout() async throws {
        let manager = PingManager()
        let delegate = TestDelegate()
        let exp = expectation(description: "error reported")
        delegate.errorExpectation = exp
        manager.delegate = delegate
        manager.pingerFactory = { host in
            return FakePingProvider(behavior: .timeout)
        }
        manager.startPinging()
        // Manager uses a 2s timeout window; wait slightly longer to observe timeout handling
        await fulfillment(of: [exp], timeout: 3.0)
        manager.stopPinging()
        XCTAssertNotNil(delegate.lastError)
    }

    func testIntermittentFailuresRecoverEventually() async throws {
        let manager = PingManager()
        let delegate = TestDelegate()
        let exp = expectation(description: "response reported")
        delegate.resultExpectation = exp
        manager.delegate = delegate
        // Alternate a timeout with a quick success so the manager should eventually receive a response
        var counter = 0
        manager.pingerFactory = { host in
            // Return providers that alternate timeout and immediate success
            let seq: [FakePingProvider.Behavior] = [.timeout, .immediateSuccess]
            return FakePingProvider(behavior: .intermittent(seq))
        }
        manager.startPinging()
        await fulfillment(of: [exp], timeout: 5.0)
        manager.stopPinging()
        XCTAssertNotNil(delegate.lastResult)
    }

 }
