// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

///
/// Wraps the legacy ``PreviewViewController`` (markdown → HTML rendering via
/// the bundled WKWebView template) in a SwiftUI sheet with native chrome.
///
/// The legacy editor pushed the preview as a separate screen which made it
/// hard to compare source and rendered output. Presenting as a sheet keeps the
/// editor visible underneath and matches what users expect from Apple Notes
/// or Bear.
///
struct MarkdownPreviewSheet: View {
    let title: String
    let date: String?
    let content: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PreviewControllerRepresentable(title: title, date: date, content: content)
                .ignoresSafeArea(.container, edges: .bottom)
                .navigationTitle(title.isEmpty ? String(localized: "Preview", comment: "Sheet title") : title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                        }
                    }
                }
        }
    }
}

private struct PreviewControllerRepresentable: UIViewControllerRepresentable {
    let title: String
    let date: String?
    let content: String

    func makeUIViewController(context: Context) -> PreviewViewController {
        let controller = PreviewViewController()
        controller.noteTitle = title
        controller.noteDate = date
        controller.content = content
        return controller
    }

    func updateUIViewController(_ uiViewController: PreviewViewController, context: Context) {}
}
