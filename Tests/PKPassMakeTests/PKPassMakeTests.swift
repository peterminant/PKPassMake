import Foundation
import Testing
@testable import PKPassMake

@Suite(.serialized) class PKPassMakeTests {
    let source = Bundle.module.url(forResource: "pass", withExtension: "json", subdirectory: "Example")!.appending(component: "..").standardized
    #if !os(iOS)
    let destination = URL.desktopDirectory.appending(component: "Example.pkpass")
    #endif
    
    init() {
        setupLogging()
    }
    
    #if !os(iOS)
    @Test func testSignAndCompressUsingLocalOpenSSLSigner() async throws {
        let signer = try await OpenSSLSigner()
        try await signAndCompress(source, using: signer, to: destination)
    }
    
    @Test func testSignAndCompressUsingLocalHttpSigner() async throws {
        let signer = HttpSigner(url: URL(string: "http://127.0.0.1:8080")!)
        try await signAndCompress(source, using: signer, to: destination)
    }
    #endif
}
