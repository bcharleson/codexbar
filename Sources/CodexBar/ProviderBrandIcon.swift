import AppKit
import CodexBarCore

@MainActor
enum ProviderBrandIcon {
    private static let size = NSSize(width: 16, height: 16)
    private static var cache: [UsageProvider: NSImage] = [:]

    /// Lazy-loaded resource bundle for provider icons.
    private static let resourceBundle: Bundle? = {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return Bundle.module
        }
        // SwiftPM creates a CodexBar_CodexBar.bundle for resources in the CodexBar target.
        if let bundleURL = Bundle.main.url(forResource: "CodexBar_CodexBar", withExtension: "bundle"),
           let bundle = Bundle(url: bundleURL)
        {
            return bundle
        }
        // Fallback to main bundle for development/testing.
        return Bundle.main
    }()

    static func image(for provider: UsageProvider) -> NSImage? {
        if let cached = self.cache[provider] {
            return cached
        }

        let baseName = ProviderDescriptorRegistry.descriptor(for: provider).branding.iconResourceName
        guard let image = Self.image(resourceNamed: baseName) else {
            return nil
        }
        self.cache[provider] = image
        return image
    }

    /// Loads a provider icon SVG by resource name (for branded sub-features that
    /// ride on another provider's card, e.g. Grok Bot on Cursor).
    static func image(resourceNamed baseName: String) -> NSImage? {
        if let cached = self.resourceCache[baseName] {
            return cached
        }
        guard let bundle = self.resourceBundle,
              let url = bundle.url(forResource: baseName, withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.size = self.size
        image.isTemplate = true
        self.resourceCache[baseName] = image
        return image
    }

    private static var resourceCache: [String: NSImage] = [:]

    static func resetCacheForTesting() {
        self.cache.removeAll()
        self.resourceCache.removeAll()
    }
}
