import CryptoKit
import Foundation
import Security

struct IOSLegacyStorage: LegacyStorage {
    private let directory: URL
    private let keychainService: String

    init(
        directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.muxy.app")
            .appendingPathComponent("RCTAsyncLocalStorage_V1"),
        keychainService: String = "app"
    ) {
        self.directory = directory
        self.keychainService = keychainService
    }

    func value(for key: String) throws -> Data? {
        let data: Data
        do {
            data = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
        let manifest = try JSONDecoder().decode([String: String?].self, from: data)
        guard let entry = manifest[key] else { return nil }
        if let entry { return Data(entry.utf8) }

        let filename = Insecure.MD5.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return try Data(contentsOf: directory.appendingPathComponent(filename))
    }

    func secret(for key: String) throws -> String? {
        for service in ["\(keychainService):no-auth", keychainService] {
            let encodedKey = Data(key.utf8)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: encodedKey,
                kSecAttrGeneric as String: encodedKey,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecItemNotFound { continue }
            guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
            guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.encodingFailed
            }
            return value
        }
        return nil
    }
}
