import Foundation

// Protocol to abstract over SwiftyPing for easier testing and injection
public protocol PingProviding: AnyObject {
    var observer: Observer? { get set }
    var targetCount: Int? { get set }
    func startPinging() throws
    func haltPinging(resetSequence: Bool)
}

// Make SwiftyPing conform to PingProviding without redeclaring existing methods
extension SwiftyPing: PingProviding {}
