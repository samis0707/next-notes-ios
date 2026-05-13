// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

///
/// Bridges the new SwiftUI ``NotesList`` to the still-UIKit ``EditorViewController``.
///
/// Phase 1 of the iPhone UX rewrite intentionally leaves the editor untouched —
/// it has its own mature markdown text storage and rewriting it without a
/// migration would be reckless. This helper instantiates the editor from the
/// existing storyboard so all `@IBOutlet` connections (toolbar buttons, gestures)
/// remain wired up.
///
/// In Phase 2 the editor itself will be replaced and this presenter retired.
///
enum EditorPresenter {
    ///
    /// Instantiate the editor navigation controller from the legacy storyboard
    /// and present it modally on top of the SwiftUI hierarchy.
    ///
    /// Modal presentation is chosen for Phase 1 because mixing SwiftUI's
    /// `NavigationStack` with a UIKit `UINavigationController` that owns
    /// `navigationItem.rightBarButtonItems` would produce two stacked navigation
    /// bars on iPhone.
    ///
    static func present(note: Note?, isNewNote: Bool = false) {
        let storyboard = UIStoryboard(name: "Main_iPhone", bundle: nil)

        guard let navigationController = storyboard.instantiateViewController(withIdentifier: "Editor") as? UINavigationController else {
            return
        }

        guard let editor = navigationController.topViewController as? EditorViewController else {
            return
        }

        editor.note = note
        editor.isNewNote = isNewNote

        navigationController.modalPresentationStyle = .fullScreen
        UIApplication.topViewController()?.present(navigationController, animated: true)
    }
}
