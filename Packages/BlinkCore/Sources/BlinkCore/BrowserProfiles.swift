import Foundation

/// How Blink lists a browser's profiles and opens a link in one.
public enum ProfileFamily: Equatable, Sendable {
    /// Arc: spaces from `StorableSidebar.json`, opened through AppleScript by space ID. Each space
    /// belongs to one profile.
    case arc
    /// Dia: Chromium profiles from `Local State`, opened through AppleScript by name.
    case dia
    /// Chromium-based browsers: profiles from `Local State`, opened with `--profile-directory`.
    case chromium
    /// Firefox-based browsers: profiles from `profiles.ini`, opened with `-P <name>`.
    case firefox
}

/// Where a browser keeps its profile list, for the browsers Blink knows.
public struct ProfileSupport: Equatable, Sendable {
    public let family: ProfileFamily
    /// The file listing profiles, relative to `~/Library/Application Support`.
    public let listPath: String

    private static let known: [String: ProfileSupport] = {
        func chromium(_ folder: String) -> ProfileSupport { .init(family: .chromium, listPath: "\(folder)/Local State") }
        return [
            "company.thebrowser.Browser": .init(family: .arc, listPath: "Arc/StorableSidebar.json"),
            "company.thebrowser.dia": .init(family: .dia, listPath: "Dia/User Data/Local State"),
            "com.google.Chrome": chromium("Google/Chrome"),
            "com.google.Chrome.beta": chromium("Google/Chrome Beta"),
            "com.google.Chrome.dev": chromium("Google/Chrome Dev"),
            "com.google.Chrome.canary": chromium("Google/Chrome Canary"),
            "org.chromium.Chromium": chromium("Chromium"),
            "com.brave.Browser": chromium("BraveSoftware/Brave-Browser"),
            "com.microsoft.edgemac": chromium("Microsoft Edge"),
            "com.vivaldi.Vivaldi": chromium("Vivaldi"),
            "app.zen-browser.zen": .init(family: .firefox, listPath: "zen/profiles.ini"),
            "org.mozilla.firefox": .init(family: .firefox, listPath: "Firefox/profiles.ini"),
        ]
    }()

    /// Nil for browsers without profile support, including Safari.
    public static func forBundleID(_ bundleID: String) -> ProfileSupport? {
        known[bundleID]
    }

    public static var supportedBundleIDs: Set<String> { Set(known.keys) }
}

/// Parses browsers' profile lists. Every parser returns an empty list for data it doesn't understand.
public enum ProfileListParser {
    /// Profiles from a Chromium `Local State` file, in the browser's own order. IDs are profile
    /// directories (`Default`, `Profile 1`).
    public static func chromium(localState data: Data) -> [ProfileReference] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = root["profile"] as? [String: Any],
              let cache = profile["info_cache"] as? [String: [String: Any]]
        else { return [] }

        var directories = (profile["profiles_order"] as? [String] ?? []).filter { cache[$0] != nil }
        let unordered = cache.keys.filter { !directories.contains($0) }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        directories += unordered

        return directories.compactMap { directory in
            guard let entry = cache[directory], let name = entry["name"] as? String, !name.isEmpty,
                  entry["is_ephemeral"] as? Bool != true,
                  entry["is_omitted_from_profile_list"] as? Bool != true,
                  // Arc keeps an internal profile here, `__ARC_SYSTEM_PROFILE`, that no space uses.
                  !name.hasPrefix("__")
            else { return nil }
            return ProfileReference(id: directory, name: name)
        }
    }

    /// Spaces from Arc's `StorableSidebar.json`, in sidebar order. IDs are space IDs.
    public static func arcSpaces(sidebar data: Data) -> [ProfileReference] {
        struct Sidebar: Decodable {
            struct Inner: Decodable { var containers: [Container] }
            struct Container: Decodable {
                var spaces: [Entry]?
                /// Present on the key that precedes the main window's container.
                var global: Empty?
            }
            struct Empty: Decodable {}
            /// Arc stores ordered maps as a flat list alternating IDs and values.
            enum Entry: Decodable {
                case space(id: String, title: String?)
                case other

                init(from decoder: any Decoder) throws {
                    struct Space: Decodable { var id: String; var title: String? }
                    if let space = try? Space(from: decoder) {
                        self = .space(id: space.id, title: space.title)
                    } else {
                        self = .other
                    }
                }
            }
            var sidebar: Inner
        }

        guard let containers = try? JSONDecoder().decode(Sidebar.self, from: data).sidebar.containers else { return [] }
        // Containers alternate keys and values. The main window's spaces follow the `global` key;
        // Little Arc's follow `littleBrowser` and hold a single untitled space.
        let main = containers.firstIndex { $0.global != nil }.flatMap { index in
            containers.indices.contains(index + 1) ? containers[index + 1].spaces : nil
        }
        guard let entries = main ?? containers.lazy.compactMap(\.spaces).first else { return [] }

        var seen = Set<String>()
        return entries.compactMap { entry in
            guard case let .space(id, title) = entry, !id.isEmpty, seen.insert(id).inserted else { return nil }
            let name = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return ProfileReference(id: id, name: name.isEmpty ? "Untitled Space" : name)
        }
    }

    public struct FirefoxProfile: Equatable, Sendable {
        public var name: String
        /// As written in `profiles.ini`: relative to the file's folder when `isRelative`.
        public var path: String
        public var isRelative: Bool

        public var reference: ProfileReference { ProfileReference(id: path, name: name) }
    }

    /// Profiles from a Firefox or Zen `profiles.ini`, in file order. IDs are profile paths.
    public static func firefox(profilesINI text: String) -> [FirefoxProfile] {
        var profiles: [FirefoxProfile] = []
        var current: [String: String]?

        func flush() {
            guard let section = current, let name = section["Name"], !name.isEmpty,
                  let path = section["Path"], !path.isEmpty
            else { return }
            profiles.append(FirefoxProfile(name: name, path: path, isRelative: section["IsRelative"] != "0"))
        }

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") && line.hasSuffix("]") {
                flush()
                current = line.dropFirst().dropLast().hasPrefix("Profile") ? [:] : nil
            } else if let separator = line.firstIndex(of: "="), current != nil {
                let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
                current?[key] = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        flush()
        return profiles
    }
}
