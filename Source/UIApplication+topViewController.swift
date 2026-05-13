// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

extension UIApplication {
    ///
    /// Recursively walks the view controller hierarchy starting from the key
    /// window's root and returns whichever view controller is on top at the
    /// moment. Used by ``NoteSessionManager`` to anchor a certificate-trust
    /// banner that doesn't have a UIKit caller of its own.
    ///
    /// The legacy implementation defaulted to `UIApplication.shared.keyWindow`
    /// which is deprecated in multi-scene apps — we now ask the connected
    /// `UIWindowScene` for its key window.
    ///
    class func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let start = base ?? keyWindowRootViewController

        if let nav = start as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }

        if let tab = start as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }
        }

        if let presented = start?.presentedViewController {
            return topViewController(base: presented)
        }

        return start
    }

    private static var keyWindowRootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }
}
