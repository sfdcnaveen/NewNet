import Foundation
import CryptoKit

/// In-app private encrypted credential storage.
/// Does not use macOS Keychain, completely eliminating Keychain password prompts and OS modal alerts.
/// Credentials are encrypted with AES-256-GCM and stored in the user's private Application Support directory
/// with POSIX 0600 (owner-only) permissions, keeping them completely inaccessible to other apps and users.
final class KeychainManager: @unchecked Sendable {
    static let shared = KeychainManager()

    private let fileURL: URL
    private let lock = NSLock()
    private let symmetricKey: SymmetricKey

    init(service: String = "com.newnet.app") {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dirURL = appSupport.appendingPathComponent("NewNet", isDirectory: true)
        try? fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let sanitizedService = service.replacingOccurrences(of: "/", with: "-")
        self.fileURL = dirURL.appendingPathComponent("vault-\(sanitizedService).dat")

        // Derive stable 256-bit AES key unique to this machine, user, and service
        let seed = "\(NSUserName())-NewNet-Storage-\(sanitizedService)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        self.symmetricKey = SymmetricKey(data: digest)
    }

    @discardableResult
    func save(key: String, value: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        var dict = loadDecryptedDictionary()
        dict[key] = value
        return persistEncryptedDictionary(dict)
    }

    func get(key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        let dict = loadDecryptedDictionary()
        return dict[key]
    }

    @discardableResult
    func delete(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        var dict = loadDecryptedDictionary()
        dict.removeValue(forKey: key)
        return persistEncryptedDictionary(dict)
    }

    private func loadDecryptedDictionary() -> [String: String] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            let dict = try JSONDecoder().decode([String: String].self, from: decryptedData)
            return dict
        } catch {
            return [:]
        }
    }

    private func persistEncryptedDictionary(_ dict: [String: String]) -> Bool {
        do {
            let jsonData = try JSONEncoder().encode(dict)
            let sealedBox = try AES.GCM.seal(jsonData, using: symmetricKey)
            guard let combined = sealedBox.combined else { return false }

            try combined.write(to: fileURL, options: .atomic)

            // Set POSIX permissions to 0600 (read & write by owner ONLY)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            return true
        } catch {
            return false
        }
    }
}
