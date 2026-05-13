// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftNextcloudUI
import SwiftUI

///
/// Top level router for views based on availability of local accounts.
///
/// See ``NotesView``, ``SettingsView`` and ``ServerAddressView`` for previews
/// in context of this.
///
/// The iOS-26 UI rewrite drops the previous bottom `TabView` (Notes / Settings)
/// in favour of a single notes screen. Settings is presented as a sheet via a
/// gear button in the top-right of the navigation bar.
///
struct ContentView: View {
    @Environment(Store.self) var store

    @State private var showSettings = false

    var sharedAccounts: [SharedAccount] {
        store.sharedAccounts.compactMap {
            guard let url = URL(string: $0.url) else {
                return nil
            }

            let image: Image

            if let uiImage = $0.image {
                image = Image(uiImage: uiImage)
            } else {
                image = Image(systemName: "person.circle.fill")
            }

            return SharedAccount($0.user, on: url, with: image)
        }
    }

    var body: some View {
        if store.accounts.isEmpty {
            ServerAddressView(backgroundColor: .constant(Color.accent), brandImage: Image("BrandLogo"), sharedAccounts: sharedAccounts, userAgent: userAgent) { host, name, password in
                store.addAccount(host: host, name: name, password: password)
            } beginPolling: { url, _ in
               try await store.beginPolling(at: url)
            } cancelPolling: {
                store.cancelPolling()
            }
            .onAppear {
                store.readSharedAccounts()
            }
        } else {
            NavigationStack {
                NotesView(showSettings: $showSettings)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .tint(Color(NCBrandColor.shared.brandColor))
        }
    }
}
