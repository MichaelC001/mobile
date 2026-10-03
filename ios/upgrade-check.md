# iOS 2.5.1 upgrade check

Use a test iPhone or iPad running iOS 26.2 or newer. Do not uninstall Muxy, clear its data, or change its bundle identifier between builds. A clean installation does not exercise migration.

## Prepare the released app

1. Install App Store version 2.5.1 and pair with a Muxy 1 computer.
2. If available, pair with a second computer so both connections share the old installation credential.
3. Add SSH connections using a password and a private key with a passphrase. Connect once to save their trusted host fingerprints.
4. Record the connection names and addresses without copying tokens, passwords, or private keys.
5. Force-quit the app.

## Install the candidate over 2.5.1

Install the candidate using the same `com.muxy.app` application identity and signing team as the released app, without removing 2.5.1 first. Prefer a TestFlight candidate over the App Store installation to exercise distribution signing and Keychain access.

Launch the candidate yourself and check:

- The saved Muxy and SSH connections are present, with their original names and addresses. If onboarding appears, choose **Skip** rather than adding the computers again.
- Each previously working Muxy 1 connection opens projects and a terminal without a new approval prompt on the computer, including any saved bracketed IPv6 address such as `[fd12:3456::10]`.
- Password and private-key SSH connections work without re-entering credentials.
- A changed SSH host key is rejected rather than silently trusted. Only change a host key on a disposable SSH server.
- Force-quitting and reopening does not create duplicate connections.
- Deleting a migrated connection and reopening does not bring it back.
- A newly added native connection continues to work after reopening.

Already revoked pairings and credentials that were missing before the upgrade still need repair. This migration preserves Muxy 1 pairings; it does not convert them into Muxy 2 pairings.

## Storage compatibility

Release `ios-v2.5.1` stores `muxy.devices.v1`, `muxy.ssh.connections.v1`, and `muxy.ssh.knownHosts.v1` using AsyncStorage 2.2.0. The importer reads `Library/Application Support/com.muxy.app/RCTAsyncLocalStorage_V1/manifest.json`, including values stored separately under MD5-derived filenames.

Expo SecureStore 15.0.8 stores credentials in the `app:no-auth` Keychain service, with a fallback for the older `app` service. The importer copies secrets directly into the native Keychain store. Muxy connections retain the original, case-preserved `installDeviceID` independently of their local connection IDs. SSH connections retain their original credentials and SHA-256 host fingerprints.

Successful imports are recorded individually, so retrying after a storage failure neither overwrites native connections nor restores entries the user has deleted. The legacy files and Keychain entries are left untouched; migration is marked complete only when all records have been processed successfully. Failed records are retried on the next launch.

In Console, filter the Muxy process for `Legacy` or `Imported a legacy connection` to diagnose migration failures. Logs contain categories and error codes, not credentials or connection data. Do not dump the Keychain or upload the legacy storage files.
