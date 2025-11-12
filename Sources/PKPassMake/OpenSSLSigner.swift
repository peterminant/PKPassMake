#if !os(iOS)
import Foundation
import Subprocess
import Logging

fileprivate let logger = Logger(label: "OpenSSLSigner")

public struct OpenSSLSigner: Signer, Sendable {
    static let supportedDirectories = [
        "~/.pkpassmake",
        "/opt/pkpassmake",
        "/etc/pkpassmake"
    ]
    
    public let directory: URL
    let args: [String]
    
    public init() async throws {
        let env = ProcessInfo.processInfo.environment
        let password = env["PKPASSMAKE_PASSWORD"]?.trimmingToNil
        var directory = env["PKPASSMAKE_HOME"]?.trimmingToNil
        
        if directory == nil {
            for candidateDirectory in Self.supportedDirectories {
                if FileManager.default.isDirectory(URL(filePath: candidateDirectory)) {
                    directory = candidateDirectory
                    break
                }
            }
        }
        
        guard let directory else {
            logger.error("Failed to find PKPassMake home directory. Supported paths:\n\(Self.supportedDirectories.joined(separator: "\n"))")
            throw URLError(.fileDoesNotExist, userInfo: [NSLocalizedDescriptionKey: "Failed to find PKPassMake home directory"])
        }
        
        try await self.init(directory: URL(filePath: directory), password: password)
    }
    
    public init(directory: URL, password: String? = nil) async throws {
        logger.info("PKPassMake home directory: \(directory.path)")
        self.directory = directory
        guard FileManager.default.isDirectory(directory) else {
            logger.error("Not a directory: \(directory.path)")
            throw URLError(.fileDoesNotExist, userInfo: [NSLocalizedDescriptionKey: "Not a directory: \(directory.path)"])
        }
        
        let certFile = directory.appending(component: "cert.pem")
        guard FileManager.default.isFile(certFile) else {
            logger.error("Not a file: \(certFile.path)")
            throw URLError(.fileDoesNotExist, userInfo: [NSLocalizedDescriptionKey: "Not a file: \(certFile.path)"])
        }
        
        let keyFile = directory.appending(component: "key.pem")
        guard FileManager.default.isFile(keyFile) else {
            logger.error("Not a file: \(keyFile.path)")
            throw URLError(.fileDoesNotExist, userInfo: [NSLocalizedDescriptionKey: "Not a file: \(keyFile.path)"])
        }
        
        var caCertFile = directory.appending(component: "cacert.pem")
        let manager = FileManager.default
        if !manager.isFile(caCertFile) {
            let supportDir = URL.applicationSupportDirectory.appending(component: "pkpassmake")
            if !manager.isDirectory(supportDir) {
                try manager.createDirectory(at: supportDir, withIntermediateDirectories: true)
            }
            caCertFile = supportDir.appending(component: "cacert.pem")
            if !manager.isFile(caCertFile) {
                logger.info("CA certificate not found")
                try await downloadCaCert(to: caCertFile)
            }
        }
        
        var args = [
            "smime", "-binary", "-sign",
            "-certfile", caCertFile.path,
            "-signer", certFile.path,
            "-inkey", keyFile.path,
            "-outform", "DER"
        ]
        if let password {
            args += ["-passin", "pass:\(password)"]
        }
        self.args = args
    }
    
    public func sign(input: Data, output: URL) async throws {
        do {
            try await openssl(args + ["-out", output.path], stdin: input)
        } catch {
            logger.error("\(error)")
            throw error
        }
    }
}

fileprivate let caCertURLs: [String] = [
    "AppleWWDRCAG6.cer",
    "AppleWWDRCAG5.cer",
    "AppleWWDRCAG4.cer",
    "AppleWWDRCAG3.cer",
    "AppleWWDRCAG2.cer",
    "AppleWWDRMPCA1G1.cer"
].map { "https://www.apple.com/certificateauthority/\($0)" }

fileprivate func downloadCaCert(to file: URL) async throws {
    for url in caCertURLs {
        logger.info("Downloading CA certificate from \(url)")
        let request = URLRequest(url: URL(string: url)!)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as! HTTPURLResponse).statusCode
            guard (200..<300).contains(statusCode) else {
                throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Unexpected status code: \(statusCode)"])
            }
            try await openssl(["x509", "-inform", "DER", "-outform", "PEM", "-out", file.path], stdin: data)
            logger.info("CA certificate: \(file.path)")
            return
        } catch {
            logger.warning("\(error)")
        }
    }
    logger.error("Failed to download CA certificate")
    throw URLError(.fileDoesNotExist, userInfo: [NSLocalizedDescriptionKey: "Failed to download CA certificate"])
}

fileprivate func openssl(_ args: [String], stdin input: Data = Data()) async throws {
    let argsString = args.map { arg in
        if arg.contains(where: \.isWhitespace) {
            return "\"\(arg.replacingOccurrences(of: "\"", with: "\\\""))\""
        } else {
            return arg
        }
    }.joined(separator: " ")
    let inputString = !input.isEmpty ? " < [\(input.count)B]" : ""
    logger.info("openssl \(argsString)\(inputString)")
    
    let limit = 16 * 1024
    let result = try await run(
        .name("openssl"),
        arguments: Arguments(args),
        input: .array(Array(input)),
        output: .string(limit: limit),
        error: .string(limit: limit)
    )
    guard result.terminationStatus.isSuccess else {
        logger.error("openssl failed: \(result.terminationStatus)")
        throw OpenSSLError(terminationStatus: result.terminationStatus, stderr: result.standardError)
    }
}

public struct OpenSSLError: LocalizedError, Sendable {
    let terminationStatus: Subprocess.TerminationStatus
    let stderr: String?
    
    public var errorDescription: String? {
        var result = "openssl failed: \(terminationStatus)"
        if let stderr {
            result += ", stderr \(stderr)"
        }
        return result
    }
}
#endif
