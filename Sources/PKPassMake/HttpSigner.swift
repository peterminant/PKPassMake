import Foundation
import Logging

fileprivate let logger = Logger(label: "HttpSigner")

public struct HttpSigner: Signer, Sendable {
    public let url: URL
    let authorization: String?
    
    public init(url: URL, authorization: String? = nil) {
        precondition(url.scheme == "http" || url.scheme == "https", "Unsupported URL scheme: \(url.scheme.debugDescription)")
        self.url = url
        self.authorization = authorization
    }
    
    public func sign(input: Data, output: URL) async throws {
        do {
            logger.info("POST \(url) [\(input.count)B]")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = input
            if let authorization {
                request.setValue(authorization, forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as! HTTPURLResponse).statusCode
            logger.info("Status \(statusCode) [\(data.count)B]")
            guard (200..<300).contains(statusCode) else {
                throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Unexpected status code: \(statusCode)"])
            }
            try data.write(to: output)
        } catch {
            logger.error("\(error)")
            throw error
        }
    }
}
