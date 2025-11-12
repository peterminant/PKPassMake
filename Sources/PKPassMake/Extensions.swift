import Foundation

extension String {
    var trimmingToNil: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension FileManager {
    func isFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return fileExists && !isDirectory.boolValue
    }
    
    func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return fileExists && isDirectory.boolValue
    }
    
    func fileSize(_ url: URL) -> UInt64? {
        do {
            let attributes = try attributesOfItem(atPath: url.path)
            return attributes[.size] as? UInt64
        } catch {
            return nil
        }
    }
}
