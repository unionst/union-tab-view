import UIKit

/// The height the bar rests against: the app's own window. The main screen
/// is not it on a phone with two displays, where the window can stand on the
/// larger inner screen while `UIScreen.main` still reports the outer one,
/// which left the bar floating in the middle of an unfolded phone.
@MainActor
enum UnionTabBarWindow {
    static var height: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first { $0.activationState == .foregroundActive }?.keyWindow ?? scenes.first?.keyWindow
        return window?.bounds.height ?? UIScreen.main.bounds.height
    }
}
