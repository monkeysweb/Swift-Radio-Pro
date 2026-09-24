import SwiftUI

/// The KPCR Pirate Cat Radio brand palette — same values as the native
/// radio app's UIColor extension (SwiftRadio/App/SceneDelegate.swift) and
/// the website's Tailwind theme, so Pirate Cat reads as part of the same
/// family without literally reusing the radio app's identity.
extension Color {
    static let pcCream = Color(red: 0.96, green: 0.95, blue: 0.84)
    static let pcInk = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let pcCoral = Color(red: 1.00, green: 0.43, blue: 0.40)
    static let pcYellow = Color(red: 1.00, green: 0.82, blue: 0.32)
    static let pcPurple = Color(red: 0.78, green: 0.46, blue: 0.96)
    static let pcCyan = Color(red: 0.39, green: 0.87, blue: 0.88)
    static let pcGreen = Color(red: 0.25, green: 0.75, blue: 0.38)
}

/// A bold black-bordered pill button, matching the site's "Join Now" /
/// "Donate via PayPal" buttons: solid ink fill, white text, fully rounded.
struct PCPrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.pcInk, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A thick black-bordered card on a bright accent color, matching the
/// donate/join pages' rounded-xl colored blocks.
struct PCCard<Content: View>: View {
    let color: Color
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.pcInk, lineWidth: 3))
    }
}

struct PCTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.pcInk, lineWidth: 2.5))
    }
}
