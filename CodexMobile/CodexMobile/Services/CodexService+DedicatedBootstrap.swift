// FILE: CodexService+DedicatedBootstrap.swift
// Purpose: 在专用版 IPA 中预置固定的 phone/mac 身份，避免每次安装后重新扫码配对。
// Layer: Service
// Exports: CodexService dedicated bootstrap helpers
// Depends on: Foundation

import Foundation

extension CodexService {
    func applyDedicatedBootstrapConfigurationIfPresent() {
        guard let config = AppEnvironment.dedicatedBootstrapConfig,
              let relayURL = config.normalizedRelayURL,
              let macDeviceId = config.normalizedMacDeviceId,
              let macIdentityPublicKey = config.normalizedMacIdentityPublicKey,
              let phoneIdentityState = config.phoneIdentityState else {
            return
        }

        let shouldResetSavedRelaySession = dedicatedBootstrapRequiresRelaySessionReset(
            macDeviceId: macDeviceId,
            relayURL: relayURL,
            phoneIdentityState: phoneIdentityState
        )

        applyDedicatedPhoneIdentityIfNeeded(phoneIdentityState)
        applyDedicatedTrustedMac(
            macDeviceId: macDeviceId,
            macIdentityPublicKey: macIdentityPublicKey,
            relayURL: relayURL,
            displayName: config.normalizedMacDisplayName
        )

        if shouldResetSavedRelaySession {
            clearSavedRelaySessionForDedicatedBootstrap()
        }
    }
}

private extension CodexService {
    func dedicatedBootstrapRequiresRelaySessionReset(
        macDeviceId: String,
        relayURL: String,
        phoneIdentityState: CodexPhoneIdentityState
    ) -> Bool {
        let existingIdentityMatchesDedicatedIdentity =
            self.phoneIdentityState.phoneDeviceId == phoneIdentityState.phoneDeviceId
            && self.phoneIdentityState.phoneIdentityPrivateKey == phoneIdentityState.phoneIdentityPrivateKey
            && self.phoneIdentityState.phoneIdentityPublicKey == phoneIdentityState.phoneIdentityPublicKey

        let savedRelayMatchesDedicatedMac =
            normalizedRelayMacDeviceId == macDeviceId
            && normalizedRelayURL == relayURL

        return !existingIdentityMatchesDedicatedIdentity || !savedRelayMatchesDedicatedMac
    }

    func applyDedicatedPhoneIdentityIfNeeded(_ phoneIdentityState: CodexPhoneIdentityState) {
        self.phoneIdentityState = phoneIdentityState
        SecureStore.writeCodable(phoneIdentityState, for: CodexSecureKeys.phoneIdentityState)
    }

    func applyDedicatedTrustedMac(
        macDeviceId: String,
        macIdentityPublicKey: String,
        relayURL: String,
        displayName: String?
    ) {
        let now = Date()
        let existingRecord = trustedMacRegistry.records[macDeviceId]
        let nextRecord = CodexTrustedMacRecord(
            macDeviceId: macDeviceId,
            macIdentityPublicKey: macIdentityPublicKey,
            lastPairedAt: existingRecord?.lastPairedAt ?? now,
            relayURL: relayURL,
            displayName: displayName ?? existingRecord?.displayName,
            lastResolvedSessionId: existingRecord?.lastResolvedSessionId,
            lastResolvedAt: existingRecord?.lastResolvedAt,
            lastUsedAt: now
        )

        trustedMacRegistry = CodexTrustedMacRegistry(records: [macDeviceId: nextRecord])
        SecureStore.writeCodable(trustedMacRegistry, for: CodexSecureKeys.trustedMacRegistry)
        SecureStore.writeString(macDeviceId, for: CodexSecureKeys.lastTrustedMacDeviceId)
        lastTrustedMacDeviceId = macDeviceId
    }

    func clearSavedRelaySessionForDedicatedBootstrap() {
        SecureStore.deleteValue(for: CodexSecureKeys.relaySessionId)
        SecureStore.deleteValue(for: CodexSecureKeys.relayUrl)
        SecureStore.deleteValue(for: CodexSecureKeys.relayMacDeviceId)
        SecureStore.deleteValue(for: CodexSecureKeys.relayMacIdentityPublicKey)
        SecureStore.deleteValue(for: CodexSecureKeys.relayProtocolVersion)
        SecureStore.deleteValue(for: CodexSecureKeys.relayLastAppliedBridgeOutboundSeq)

        relaySessionId = nil
        relayUrl = nil
        relayMacDeviceId = nil
        relayMacIdentityPublicKey = nil
        relayProtocolVersion = codexSecureProtocolVersion
        lastAppliedBridgeOutboundSeq = 0
        shouldForceQRBootstrapOnNextHandshake = false
        trustedReconnectFailureCount = 0
    }
}
