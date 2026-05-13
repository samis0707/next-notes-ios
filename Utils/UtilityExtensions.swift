// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

#if os(macOS)
import Foundation
#else
import UIKit
#endif
import Version

extension NSNotification.Name {
    static let deletingNote = NSNotification.Name("DeletingNote")
    static let syncNotes = NSNotification.Name("SyncNotes")
    static let networkSuccess = NSNotification.Name("NetworkSucces")
    static let networkError = NSNotification.Name("NetworkError")
    static let offlineModeChanged = NSNotification.Name("OfflineModeChanged")
    static let doneSelectingCategory = NSNotification.Name("DoneSelectingCategory")
    static let editorUpdatedNote = NSNotification.Name("EditorUpdatedNote")
    static let categoryUpdated = NSNotification.Name("CategoryUpdated")
}

struct DisclosureSection: Codable {
    var title: String
    var collapsed: Bool
}

typealias DisclosureSections = [DisclosureSection]

extension UIImage {
    static func colorResizableImage(color: UIColor) -> UIImage {
        var image = UIImage()
        let rect = CGRect(x: 0, y: 0, width: 3, height: 3)
        UIGraphicsBeginImageContext(rect.size)
        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(color.cgColor)
            context.fill(rect)
            image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        }
        UIGraphicsEndImageContext()
        image = image.resizableImage(withCapInsets: UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1))
        return image
    }
    
}

extension String {
    
    func truncate(length: Int, trailing: String = "…") -> String {
        if (self.count <= length) {
            return self
        }
        var truncated = self.prefix(length)
        while truncated.last != " ", !truncated.isEmpty {
            truncated = truncated.dropLast()
        }
        return truncated + trailing
    }

    func strippingHTML() -> String {
        var result = self
        result = result.replacingOccurrences(
            of: "(?is)<script\\b[^>]*>.*?</script>",
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "(?is)<style\\b[^>]*>.*?</style>",
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "(?is)<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
}

func noteTitle(_ note: NoteProtocol) -> String {
    var result = note.title
    if note.content.isEmpty {
        result = note.title
    } else {
        if note.title.count <= 50 || note.title.hasPrefix(Constants.newNote) {
            let components = note.content.split(separator: "\n")
            result = String(components.first ?? "")
            let forbiddenCharacters: Set<Character> = ["*", "|", "/", "\\", ":", "\"", "<", ">", "?"]
            result.removeAll(where: { forbiddenCharacters.contains($0) })
            result = result.trimmingCharacters(in: .whitespaces)
            result = result.truncate(length: 50)
        }
    }
    return result
}

func isNextcloud() -> Bool {
    var isNextcloud = false
    do {
        let version = try Version(KeychainHelper.productVersion)
        if version.major > 13 {
            isNextcloud = true
        }
    } catch { }
    return isNextcloud
}
