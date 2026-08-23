import CodexBarCore
import Foundation

extension SettingsStore {
    var cursorCookieHeader: String {
        get { self.configSnapshot.providerConfig(for: .cursor)?.sanitizedCookieHeader ?? "" }
        set {
            self.updateProviderConfig(provider: .cursor) { entry in
                entry.cookieHeader = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .cursor, field: "cookieHeader", value: newValue)
        }
    }

    var cursorCookieSource: ProviderCookieSource {
        get { self.resolvedCookieSource(provider: .cursor, fallback: .auto) }
        set {
            self.updateProviderConfig(provider: .cursor) { entry in
                entry.cookieSource = newValue
            }
            self.logProviderModeChange(provider: .cursor, field: "cookieSource", value: newValue.rawValue)
        }
    }

    /// Whether the Grok Bot weekly usage window renders on the Cursor card.
    /// Data comes from Cursor's GetSandUsageStatus RPC (Grok Bot is Cursor-billed).
    var cursorGrokBotWindowEnabled: Bool {
        get { self.configSnapshot.providerConfig(for: .cursor)?.grokBotWindowEnabled ?? true }
        set {
            self.updateProviderConfig(provider: .cursor) { entry in
                entry.grokBotWindowEnabled = newValue
            }
        }
    }

    func ensureCursorCookieLoaded() {}
}

extension SettingsStore {
    func cursorSettingsSnapshot(tokenOverride: TokenAccountOverride?) -> ProviderSettingsSnapshot
    .CursorProviderSettings {
        let cookieSnapshot: ProviderSettingsSnapshot.CursorProviderSettings = self
            .resolvedCookieSettings(
                provider: .cursor,
                configuredSource: self.cursorCookieSource,
                configuredHeader: self.cursorCookieHeader,
                tokenOverride: tokenOverride)
        return ProviderSettingsSnapshot.CursorProviderSettings(
            cookieSource: cookieSnapshot.cookieSource,
            manualCookieHeader: cookieSnapshot.manualCookieHeader,
            grokBotWindowEnabled: self.cursorGrokBotWindowEnabled)
    }
}
