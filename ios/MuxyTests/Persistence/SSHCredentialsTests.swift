import Foundation
import Testing
@testable import Muxy

struct SSHCredentialsTests {
    @Test func readsLegacyPasswordAndPrivateKeyCredentials() throws {
        let store = InMemoryKeychainStore()
        let id = UUID()
        try store.setSecret("password", .sshPassword, for: id)
        try store.setSecret("key", .sshPrivateKey, for: id)
        try store.setSecret("phrase", .sshPassphrase, for: id)

        let password = try store.sshCredentials(for: id, authMethod: .password)
        #expect(password.secret == "password")
        #expect(password.passphrase == nil)
        let key = try store.sshCredentials(for: id, authMethod: .privateKey)
        #expect(key.secret == "key")
        #expect(key.passphrase == "phrase")
    }

    @Test func replacementsTakePrecedenceWithoutClearingTrust() throws {
        let store = InMemoryKeychainStore()
        let id = UUID()
        try store.setSecret("legacy", .sshPrivateKey, for: id)
        try store.setSecret("old-phrase", .sshPassphrase, for: id)
        try store.setSecret("fingerprint", .sshHostKey, for: id)
        try store.replaceSSHCredentials(SSHCredentials(authMethod: .privateKey, secret: "new", passphrase: nil), for: id)

        let replacement = try store.sshCredentials(for: id, authMethod: .privateKey)
        #expect(replacement.secret == "new")
        #expect(replacement.passphrase == nil)
        #expect(try store.secret(.sshHostKey, for: id) == "fingerprint")
    }

    @Test func switchingAuthenticationDoesNotFallBackToObsoleteCredentials() throws {
        let store = InMemoryKeychainStore()
        let id = UUID()
        try store.setSecret("legacy", .sshPassword, for: id)
        try store.replaceSSHCredentials(SSHCredentials(authMethod: .privateKey, secret: "key", passphrase: "phrase"), for: id)
        #expect(throws: SSHError.missingCredentials) {
            try store.sshCredentials(for: id, authMethod: .password)
        }
        try store.replaceSSHCredentials(SSHCredentials(authMethod: .password, secret: "new-password", passphrase: nil), for: id)
        #expect(try store.sshCredentials(for: id, authMethod: .password).secret == "new-password")
        #expect(throws: SSHError.missingCredentials) {
            try store.sshCredentials(for: id, authMethod: .privateKey)
        }
    }

    @Test func malformedReplacementDoesNotFallBackToLegacySecrets() throws {
        let store = InMemoryKeychainStore()
        let id = UUID()
        try store.setSecret("legacy", .sshPassword, for: id)
        try store.setSecret("invalid-json", .sshCredentials, for: id)
        #expect(throws: (any Error).self) {
            try store.sshCredentials(for: id, authMethod: .password)
        }
    }

    @Test func deletingTheConnectionRemovesReplacementCredentials() throws {
        let store = KeychainTokenStore(service: "com.muxy.app.tests.\(UUID().uuidString)")
        let id = UUID()
        defer { try? store.deleteSecrets(for: id) }
        try store.replaceSSHCredentials(SSHCredentials(authMethod: .password, secret: "saved", passphrase: nil), for: id)
        #expect(try store.sshCredentials(for: id, authMethod: .password).secret == "saved")
        try store.deleteSecrets(for: id)
        #expect(try store.secret(.sshCredentials, for: id) == nil)
        #expect(throws: SSHError.missingCredentials) {
            try store.sshCredentials(for: id, authMethod: .password)
        }
    }
}
