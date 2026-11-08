import Foundation

/// Known apps and the URL schemes that open them.
///
/// URL schemes are set by each app's developer and can change. If one stops working,
/// edit the icon and switch it to "Shortcut" — that works for every app.
struct CatalogEntry: Identifiable, Hashable {
    enum Category: String, CaseIterable {
        case apple = "Apple"
        case social = "Social & Messaging"
        case media = "Music & Video"
        case productivity = "Productivity"
        case everyday = "Shopping & Travel"
    }

    let name: String
    let url: String
    let symbol: String
    let colorHex: String
    let category: Category
    var keywords: String = ""

    var id: String { name }

    func makeApp(groupID: UUID) -> LauncherApp {
        LauncherApp(
            name: name,
            launch: .url(url),
            glyph: .symbol(symbol),
            colorHex: colorHex,
            groupID: groupID,
            keywords: keywords
        )
    }
}

enum AppCatalog {
    static let entries: [CatalogEntry] = [
        // Apple
        CatalogEntry(name: "Phone", url: "tel:", symbol: "phone.fill", colorHex: "#22C55E", category: .apple, keywords: "call dial"),
        CatalogEntry(name: "Messages", url: "sms:", symbol: "message.fill", colorHex: "#22C55E", category: .apple, keywords: "text chat imessage sms"),
        CatalogEntry(name: "Mail", url: "message://", symbol: "envelope.fill", colorHex: "#3B82F6", category: .apple, keywords: "email inbox"),
        CatalogEntry(name: "Safari", url: "x-web-search://", symbol: "safari.fill", colorHex: "#0EA5E9", category: .apple, keywords: "web browser internet"),
        CatalogEntry(name: "Music", url: "music://", symbol: "music.note", colorHex: "#F43F5E", category: .apple, keywords: "songs"),
        CatalogEntry(name: "Photos", url: "photos-redirect://", symbol: "photo.on.rectangle", colorHex: "#F59E0B", category: .apple, keywords: "pictures gallery"),
        CatalogEntry(name: "Maps", url: "maps://", symbol: "map.fill", colorHex: "#10B981", category: .apple, keywords: "directions navigation"),
        CatalogEntry(name: "Calendar", url: "calshow://", symbol: "calendar", colorHex: "#EF4444", category: .apple, keywords: "events schedule"),
        CatalogEntry(name: "Notes", url: "mobilenotes://", symbol: "note.text", colorHex: "#EAB308", category: .apple),
        CatalogEntry(name: "Reminders", url: "x-apple-reminderkit://", symbol: "checklist", colorHex: "#F97316", category: .apple, keywords: "todo tasks"),
        CatalogEntry(name: "Weather", url: "weather://", symbol: "cloud.sun.fill", colorHex: "#38BDF8", category: .apple),
        CatalogEntry(name: "Podcasts", url: "podcasts://", symbol: "antenna.radiowaves.left.and.right", colorHex: "#A855F7", category: .apple),
        CatalogEntry(name: "Books", url: "ibooks://", symbol: "book.fill", colorHex: "#F97316", category: .apple, keywords: "read"),
        CatalogEntry(name: "Files", url: "shareddocuments://", symbol: "folder.fill", colorHex: "#3B82F6", category: .apple, keywords: "documents"),
        CatalogEntry(name: "Wallet", url: "shoebox://", symbol: "wallet.pass.fill", colorHex: "#111827", category: .apple, keywords: "cards pay"),
        CatalogEntry(name: "Health", url: "x-apple-health://", symbol: "heart.fill", colorHex: "#EC4899", category: .apple, keywords: "fitness steps"),
        CatalogEntry(name: "App Store", url: "itms-apps://", symbol: "bag.fill", colorHex: "#0EA5E9", category: .apple, keywords: "download"),
        CatalogEntry(name: "Shortcuts", url: "shortcuts://", symbol: "square.stack.3d.up.fill", colorHex: "#6366F1", category: .apple, keywords: "automation"),
        CatalogEntry(name: "Settings", url: "App-prefs:", symbol: "gearshape.fill", colorHex: "#78716C", category: .apple, keywords: "preferences wifi bluetooth"),

        // Social & messaging
        CatalogEntry(name: "Instagram", url: "instagram://", symbol: "camera.fill", colorHex: "#D946EF", category: .social, keywords: "ig insta"),
        CatalogEntry(name: "WhatsApp", url: "whatsapp://", symbol: "bubble.left.and.bubble.right.fill", colorHex: "#22C55E", category: .social, keywords: "chat"),
        CatalogEntry(name: "Messenger", url: "fb-messenger://", symbol: "bubble.left.fill", colorHex: "#6366F1", category: .social, keywords: "chat facebook"),
        CatalogEntry(name: "Facebook", url: "fb://", symbol: "person.2.fill", colorHex: "#3B82F6", category: .social, keywords: "fb"),
        CatalogEntry(name: "X", url: "twitter://", symbol: "at", colorHex: "#111827", category: .social, keywords: "twitter"),
        CatalogEntry(name: "Threads", url: "barcelona://", symbol: "at.circle.fill", colorHex: "#111827", category: .social),
        CatalogEntry(name: "TikTok", url: "snssdk1233://", symbol: "music.note.tv", colorHex: "#111827", category: .social),
        CatalogEntry(name: "Snapchat", url: "snapchat://", symbol: "camera.viewfinder", colorHex: "#EAB308", category: .social, keywords: "snap"),
        CatalogEntry(name: "Telegram", url: "tg://", symbol: "paperplane.fill", colorHex: "#0EA5E9", category: .social, keywords: "chat"),
        CatalogEntry(name: "Discord", url: "discord://", symbol: "gamecontroller.fill", colorHex: "#6366F1", category: .social, keywords: "chat"),
        CatalogEntry(name: "Reddit", url: "reddit://", symbol: "text.bubble.fill", colorHex: "#F97316", category: .social),
        CatalogEntry(name: "Pinterest", url: "pinterest://", symbol: "pin.fill", colorHex: "#EF4444", category: .social),
        CatalogEntry(name: "LinkedIn", url: "linkedin://", symbol: "briefcase.fill", colorHex: "#0369A1", category: .social, keywords: "jobs"),

        // Music & video
        CatalogEntry(name: "Spotify", url: "spotify://", symbol: "music.note.list", colorHex: "#22C55E", category: .media, keywords: "music"),
        CatalogEntry(name: "YouTube", url: "youtube://", symbol: "play.rectangle.fill", colorHex: "#EF4444", category: .media, keywords: "video"),
        CatalogEntry(name: "Netflix", url: "nflx://", symbol: "tv.fill", colorHex: "#B91C1C", category: .media, keywords: "movies shows"),

        // Productivity
        CatalogEntry(name: "Gmail", url: "googlegmail://", symbol: "envelope.open.fill", colorHex: "#EF4444", category: .productivity, keywords: "email google"),
        CatalogEntry(name: "Outlook", url: "ms-outlook://", symbol: "tray.fill", colorHex: "#0369A1", category: .productivity, keywords: "email microsoft"),
        CatalogEntry(name: "Chrome", url: "googlechrome://", symbol: "globe", colorHex: "#F59E0B", category: .productivity, keywords: "browser google"),
        CatalogEntry(name: "Slack", url: "slack://", symbol: "number", colorHex: "#A855F7", category: .productivity, keywords: "chat work"),
        CatalogEntry(name: "Teams", url: "msteams://", symbol: "person.3.fill", colorHex: "#6366F1", category: .productivity, keywords: "microsoft work"),
        CatalogEntry(name: "Zoom", url: "zoomus://", symbol: "video.fill", colorHex: "#3B82F6", category: .productivity, keywords: "meeting call"),
        CatalogEntry(name: "Notion", url: "notion://", symbol: "doc.text.fill", colorHex: "#111827", category: .productivity, keywords: "notes docs"),

        // Shopping & travel
        CatalogEntry(name: "Google Maps", url: "comgooglemaps://", symbol: "mappin.and.ellipse", colorHex: "#10B981", category: .everyday, keywords: "directions"),
        CatalogEntry(name: "Uber", url: "uber://", symbol: "car.fill", colorHex: "#111827", category: .everyday, keywords: "ride taxi"),
        CatalogEntry(name: "Venmo", url: "venmo://", symbol: "dollarsign.circle.fill", colorHex: "#0EA5E9", category: .everyday, keywords: "pay money"),
    ]

    static func entry(named name: String) -> CatalogEntry? {
        entries.first { $0.name == name }
    }
}
