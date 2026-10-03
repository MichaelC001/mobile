import SwiftUI

struct ConnectionDetailsFields: View {
    @Binding var name: String
    @Binding var host: String
    @Binding var portText: String

    var body: some View {
        TextField("Name", text: $name)
            .textInputAutocapitalization(.words)
        TextField("Host", text: $host)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
        TextField("Port", text: $portText)
            .keyboardType(.numberPad)
    }
}

struct SSHAuthenticationFields: View {
    @Binding var authMethod: SSHAuthMethod
    @Binding var password: String
    @Binding var privateKey: String
    @Binding var passphrase: String
    var showsSecrets = true
    var allowsMethodChange = true

    var body: some View {
        Picker("Authentication", selection: $authMethod) {
            Text("Password").tag(SSHAuthMethod.password)
            Text("Private Key").tag(SSHAuthMethod.privateKey)
        }
        .disabled(!allowsMethodChange)
        if showsSecrets {
            if authMethod == .password {
                SecureField("Password", text: $password)
            } else {
                TextField("Private Key", text: $privateKey, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(4...8)
                SecureField("Passphrase (optional)", text: $passphrase)
            }
        }
    }
}
