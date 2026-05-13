// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// State view shown when the user has no notes yet.
///
/// Uses `ContentUnavailableView` so the empty state matches native iOS apps and
/// supports Dynamic Type, Dark Mode and VoiceOver out of the box.
///
struct EmptyNotesView: View {
    let onCreate: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("No Notes Yet")
            } icon: {
                Image(systemName: "note.text")
            }
        } description: {
            Text("Tap the button below to write your first note.")
        } actions: {
            Button(action: onCreate) {
                Label {
                    Text("New Note")
                } icon: {
                    Image(systemName: "square.and.pencil")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

///
/// State view shown when a search yields no matches.
///
struct NoSearchResultsView: View {
    let searchText: String

    var body: some View {
        ContentUnavailableView.search(text: searchText)
    }
}
