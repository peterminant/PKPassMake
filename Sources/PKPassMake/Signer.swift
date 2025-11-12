import Foundation

public protocol Signer {
    func sign(input: Data, output: URL) async throws
}
