// FILE: CodexDedicatedBootstrap.swift
// Purpose: 解析专用版 IPA 内置的固定连接配置，用于首次安装后直接走 trusted reconnect。
// Layer: Service support
// Exports: CodexDedicatedBootstrapConfig
// Depends on: Foundation

import Foundation

struct CodexDedicatedBootstrapConfig: Codable, Sendable {
    let relayURL: String
    let macDeviceId: String
    let macIdentityPublicKey: String
    let macDisplayName: String?
    let phoneDeviceId: String
    let phoneIdentityPrivateKey: String
    let phoneIdentityPublicKey: String

    var normalizedRelayURL: String? {
        codexDedicatedNormalizedString(relayURL)
    }

    var normalizedMacDeviceId: String? {
        codexDedicatedNormalizedString(macDeviceId)
    }

    var normalizedMacIdentityPublicKey: String? {
        codexDedicatedNormalizedString(macIdentityPublicKey)
    }

    var normalizedMacDisplayName: String? {
        codexDedicatedNormalizedString(macDisplayName)
    }

    var normalizedPhoneDeviceId: String? {
        codexDedicatedNormalizedString(phoneDeviceId)
    }

    var normalizedPhoneIdentityPrivateKey: String? {
        codexDedicatedNormalizedString(phoneIdentityPrivateKey)
    }

    var normalizedPhoneIdentityPublicKey: String? {
        codexDedicatedNormalizedString(phoneIdentityPublicKey)
    }

    var phoneIdentityState: CodexPhoneIdentityState? {
        guard let normalizedPhoneDeviceId,
              let normalizedPhoneIdentityPrivateKey,
              let normalizedPhoneIdentityPublicKey else {
            return nil
        }

        return CodexPhoneIdentityState(
            phoneDeviceId: normalizedPhoneDeviceId,
            phoneIdentityPrivateKey: normalizedPhoneIdentityPrivateKey,
            phoneIdentityPublicKey: normalizedPhoneIdentityPublicKey
        )
    }

    static func decode(fromInfoPlistValue rawValue: String) -> CodexDedicatedBootstrapConfig? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        if let decodedData = Data(base64Encoded: trimmedValue),
           let decodedConfig = try? JSONDecoder().decode(CodexDedicatedBootstrapConfig.self, from: decodedData) {
            return decodedConfig
        }

        guard let rawJSONData = trimmedValue.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(CodexDedicatedBootstrapConfig.self, from: rawJSONData)
    }
}

private func codexDedicatedNormalizedString(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else {
        return nil
    }
    return value
}
