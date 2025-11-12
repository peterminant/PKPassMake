import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

func sha1(_ data: some DataProtocol) -> String {
    Insecure.SHA1
        .hash(data: data)
        .map { String(format: "%02x", $0) }
        .joined()
}
