import Foundation

enum Config {
    // Points at the KPCR production backend's Pirate Cat routes
    // (src/pages/api/piratecat/*), which are fully separate from the
    // KPCRRadio app's /api/mobile/* routes. Point this at
    // http://localhost:4321 (with an ATS exception, see setup docs) to
    // test against a local `npm run dev` backend instead.
    static let apiBaseURL = URL(string: "https://kpcr.org")!
}
