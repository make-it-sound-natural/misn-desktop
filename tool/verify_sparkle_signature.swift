// Verify the DMG against the public key embedded in the app, without Keychain.
import CryptoKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 4,
      let publicKeyData = Data(base64Encoded: arguments[2]),
      let signature = Data(base64Encoded: arguments[3]) else {
    fputs("Usage: verify_sparkle_signature.swift DMG PUBLIC_KEY SIGNATURE\n", stderr)
    exit(64)
}
do {
    let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
    let archive = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
    guard publicKey.isValidSignature(signature, for: archive) else {
        fputs("Sparkle signature does not match the app's public key\n", stderr)
        exit(1)
    }
    print("Sparkle signature matches the app's public key")
} catch {
    fputs("Cannot verify Sparkle signature: \(error)\n", stderr)
    exit(1)
}
