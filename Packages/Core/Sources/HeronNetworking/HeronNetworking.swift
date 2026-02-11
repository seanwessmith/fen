import Foundation

public protocol NetworkClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}
