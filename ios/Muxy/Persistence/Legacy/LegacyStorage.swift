import Foundation

protocol LegacyStorage {
    func value(for key: String) throws -> Data?
    func secret(for key: String) throws -> String?
}

enum LegacyImportError: Error {
    case unsupportedVersion
    case invalidRecord
    case missingCredential
    case saveFailed
}
