// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// Top-level view for the notes navigation.
///
/// Phase 1 of the iPhone UX rewrite ships ``NotesList`` as the pure SwiftUI
/// replacement for the legacy `NotesTableViewController`. The editor is still
/// the UIKit one, presented modally via ``EditorPresenter`` until Phase 2.
///
struct NotesView: View {
    var body: some View {
        NotesList()
    }
}

#Preview {
    let store = Store()

    store.accounts = [
        AccountTransferObject(baseURL: "http://localhost:8080", password: "password", serverVersion: ServerVersionTransferObject(major: 31, minor: 0, micro: 0), userId: "admin")
    ]

    return ContentView(selection: 0)
        .environment(store)
        .environment(\.managedObjectContext, NotesData.mainThreadContext)
}
