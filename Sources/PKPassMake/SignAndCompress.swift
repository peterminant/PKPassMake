import Foundation
import Logging
import ZIPFoundation

fileprivate let logger = Logger(label: "PKPassMake")

@discardableResult
public func signAndCompress(_ sourceURL: URL, using signer: any Signer, to destinationURL: URL? = nil) async throws -> URL {
    logger.info("Signing and compressing \(sourceURL.path)")
    do {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) && isDirectory.boolValue else {
            throw URLError(.cannotOpenFile, userInfo: [NSLocalizedDescriptionKey: "Not a directory: \(sourceURL)"])
        }
        
        let manifestURL = sourceURL.appendingPathComponent("manifest.json")
        let signatureURL = sourceURL.appendingPathComponent("signature")
        let destinationURL = destinationURL ?? sourceURL.appendingPathExtension("pkpass")
        
        var manifest: [String: String] = [:]
        let enumerator = manager.enumerator(at: sourceURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        
        while let file = enumerator?.nextObject() as? URL {
            let resourceValues = try file.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }
            
            let relativePath = file.path.replacingOccurrences(of: sourceURL.path + "/", with: "")
            if relativePath == "manifest.json" || relativePath == "signature" { continue }
            
            let data = try Data(contentsOf: file)
            manifest[relativePath] = sha1(data)
        }
        
        logger.debug("Manifest: \(manifest)")
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: manifestURL)
        try await signer.sign(input: manifestData, output: signatureURL)
        let signatureSize = manager.fileSize(signatureURL).map(String.init) ?? "?"
        logger.debug("Signature: [\(signatureSize)B]")
        
        if manager.fileExists(atPath: destinationURL.path) {
            try manager.removeItem(at: destinationURL)
        }
        
        let archive = try Archive(url: destinationURL, accessMode: .create)
        let filePaths = Array(manifest.keys) + ["manifest.json", "signature"]
        for filePath in filePaths {
            try archive.addEntry(
                with: filePath,
                relativeTo: sourceURL,
                compressionMethod: .deflate
            )
        }
        let compressedSize = manager.fileSize(destinationURL).map(String.init) ?? "?"
        logger.info("Output: \(destinationURL.path) [\(compressedSize)B]")
        
        return destinationURL
    } catch {
        logger.error("\(error)")
        throw error
    }
}
