import Foundation

nonisolated struct SSHCredentials: Codable, Sendable {
    let authMethod: SSHAuthMethod
    let secret: String
    let passphrase: String?
}

extension KeychainStore {
    func replaceSSHCredentials(_ credentials: SSHCredentials, for connectionID: Connection.ID) throws {
        let data = try JSONEncoder().encode(credentials)
        guard let value = String(data: data, encoding: .utf8) else { throw KeychainError.encodingFailed }
        try setSecret(value, .sshCredentials, for: connectionID)
    }

    func sshCredentials(for connectionID: Connection.ID, authMethod: SSHAuthMethod) throws -> SSHCredentials {
        if let value = try secret(.sshCredentials, for: connectionID) {
            let credentials = try JSONDecoder().decode(SSHCredentials.self, from: Data(value.utf8))
            guard credentials.authMethod == authMethod else { throw SSHError.missingCredentials }
            return credentials
        }
        let secretKind: KeychainSecret = authMethod == .password ? .sshPassword : .sshPrivateKey
        guard let secret = try secret(secretKind, for: connectionID) else { throw SSHError.missingCredentials }
        let passphrase = authMethod == .privateKey ? try self.secret(.sshPassphrase, for: connectionID) : nil
        return SSHCredentials(authMethod: authMethod, secret: secret, passphrase: passphrase)
    }
}
