// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// Top-level view for the notes navigation.
///
/// Receives a binding to the global "show settings" sheet flag from
/// ``ContentView`` and forwards it to ``NotesList`` so the gear button in
/// the navigation bar can present settings without a second sheet stack.
///
struct NotesView: View {
    @Binding var showSettings: Bool

    var body: some View {
        NotesList(showSettings: $showSettings)
    }
}

#Preview {
    let store = Store()

    store.accounts = [
        AccountTransferObject(baseURL: "http://localhost:8080", password: "password", serverVersion: ServerVersionTransferObject(major: 31, minor: 0, micro: 0), userId: "admin")
    ]

    return ContentView()
        .environment(store)
        .environment(\.managedObjectContext, NotesData.mainThreadContext)
}
