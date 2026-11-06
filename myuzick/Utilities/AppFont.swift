import CoreText
import SwiftUI
import UIKit

enum AppFont {
    private static let fontNameKey = "myuzick.customFontPostScriptName"
    private static let fontFileKey = "myuzick.customFontFileName"

    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = UserDefaults.standard.string(forKey: fontNameKey) {
            return .custom(name, size: size, relativeTo: .body).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    static func registerSavedFont() {
        guard let filename = UserDefaults.standard.string(forKey: fontFileKey) else { return }
        let url = fontsDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? register(url: url, persist: false)
    }

    static func install(from source: URL) throws {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.createDirectory(at: fontsDirectory, withIntermediateDirectories: true)
        let filename = source.lastPathComponent
        let destination = fontsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        try register(url: destination, persist: true)
    }

    static func remove() {
        if let filename = UserDefaults.standard.string(forKey: fontFileKey) {
            try? FileManager.default.removeItem(at: fontsDirectory.appendingPathComponent(filename))
        }
        UserDefaults.standard.removeObject(forKey: fontNameKey)
        UserDefaults.standard.removeObject(forKey: fontFileKey)
    }

    private static var fontsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fonts", isDirectory: true)
    }

    private static func register(url: URL, persist: Bool) throws {
        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
            if let error = error?.takeRetainedValue() { throw error }
            throw FontError.registrationFailed
        }
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first,
              let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else {
            throw FontError.missingFontName
        }
        if persist {
            UserDefaults.standard.set(name, forKey: fontNameKey)
            UserDefaults.standard.set(url.lastPathComponent, forKey: fontFileKey)
        }
    }

    enum FontError: LocalizedError {
        case registrationFailed
        case missingFontName
        var errorDescription: String? {
            switch self {
            case .registrationFailed: return "This font couldn't be registered. Try a valid TTF or OTF font."
            case .missingFontName: return "The font file doesn't contain a readable font name."
            }
        }
    }
}
