import Foundation
import Testing
@testable import BlinkCore

@Suite("Profile lists")
struct ProfileListTests {
    @Test func readsChromiumProfilesInBrowserOrder() {
        let localState = Data("""
        {
          "browser": { "enabled_labs_experiments": [] },
          "profile": {
            "info_cache": {
              "Default": { "name": "Personal", "is_ephemeral": false },
              "Profile 5": { "name": "Client" },
              "Profile 1": { "name": "Work" },
              "Profile 3": { "name": "__ARC_SYSTEM_PROFILE" },
              "Profile 7": { "name": "Guest", "is_ephemeral": true },
              "Profile 9": { "name": "Not ordered" }
            },
            "profiles_order": ["Profile 1", "Default", "Profile 5", "Gone"]
          }
        }
        """.utf8)
        #expect(ProfileListParser.chromium(localState: localState) == [
            .init(id: "Profile 1", name: "Work"),
            .init(id: "Default", name: "Personal"),
            .init(id: "Profile 5", name: "Client"),
            .init(id: "Profile 9", name: "Not ordered"),
        ])
        #expect(ProfileListParser.chromium(localState: localState).map(\.name) == ["Work", "Personal", "Client", "Not ordered"])
    }

    @Test func readsChromiumProfilesWithoutOrder() {
        let localState = Data(#"{"profile": {"info_cache": {"Profile 1": {"name": "B"}, "Default": {"name": "A"}}}}"#.utf8)
        #expect(ProfileListParser.chromium(localState: localState).map(\.id) == ["Default", "Profile 1"])
    }

    @Test(arguments: ["", "[]", "{}", #"{"profile": {}}"#, #"{"profile": {"info_cache": []}}"#])
    func ignoresUnexpectedChromiumData(text: String) {
        #expect(ProfileListParser.chromium(localState: Data(text.utf8)).isEmpty)
    }

    @Test func readsArcSpacesInSidebarOrder() {
        let sidebar = Data("""
        {
          "version": 1,
          "sidebar": {
            "containers": [
              { "global": {} },
              {
                "items": [],
                "spaces": [
                  "A1", { "id": "A1", "title": "Work", "profile": { "default": true } },
                  "B2", { "id": "B2", "title": "  ", "profile": { "custom": { "_0": { "directoryBasename": "Profile 1" } } } },
                  "C3", { "id": "C3", "title": "Home" },
                  "A1", { "id": "A1", "title": "Duplicate" },
                  "D4", { "title": "No ID" }
                ]
              }
            ]
          }
        }
        """.utf8)
        #expect(ProfileListParser.arcSpaces(sidebar: sidebar).map(\.id) == ["A1", "B2", "C3"])
        #expect(ProfileListParser.arcSpaces(sidebar: sidebar).map(\.name) == ["Work", "Untitled Space", "Home"])
    }

    @Test(arguments: ["", "{}", #"{"sidebar": {"containers": []}}"#, #"{"sidebar": {"containers": [{"spaces": "x"}]}}"#])
    func ignoresUnexpectedArcData(text: String) {
        #expect(ProfileListParser.arcSpaces(sidebar: Data(text.utf8)).isEmpty)
    }

    @Test func readsFirefoxProfiles() {
        let ini = """
        [Profile1]
        Name=default
        IsRelative=1
        Path=Profiles/abc.default
        Default=1

        [Install278CDD2020B02885]
        Default=Profiles/xyz.Default (beta)
        Locked=1

        [Profile0]
        Name = Default (beta)
        IsRelative=1
        Path=Profiles/xyz.Default (beta)

        [Profile2]
        Name=Elsewhere
        IsRelative=0
        Path=/Volumes/Data/firefox-profile

        [Profile3]
        Name=Missing path

        [General]
        StartWithLastProfile=1
        """
        #expect(ProfileListParser.firefox(profilesINI: ini) == [
            .init(name: "default", path: "Profiles/abc.default", isRelative: true),
            .init(name: "Default (beta)", path: "Profiles/xyz.Default (beta)", isRelative: true),
            .init(name: "Elsewhere", path: "/Volumes/Data/firefox-profile", isRelative: false),
        ])
    }

    @Test func knowsWhereBrowsersKeepProfiles() {
        #expect(ProfileSupport.forBundleID("company.thebrowser.Browser")?.family == .arc)
        #expect(ProfileSupport.forBundleID("company.thebrowser.dia")?.listPath == "Dia/User Data/Local State")
        #expect(ProfileSupport.forBundleID("com.brave.Browser")?.family == .chromium)
        #expect(ProfileSupport.forBundleID("app.zen-browser.zen")?.listPath == "zen/profiles.ini")
        #expect(ProfileSupport.forBundleID("com.apple.Safari") == nil)
    }
}
