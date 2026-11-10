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
        case ai = "AI"
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
            keywords: keywords,
            bundleID: AppCatalog.bundleIDs[name]
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
        CatalogEntry(name: "Prime Video", url: "aiv://", symbol: "play.rectangle.on.rectangle.fill", colorHex: "#0EA5E9", category: .media, keywords: "amazon movies shows"),
        CatalogEntry(name: "Disney+", url: "disneyplus://", symbol: "sparkles.tv.fill", colorHex: "#1E3A8A", category: .media, keywords: "disney movies shows"),
        CatalogEntry(name: "Hulu", url: "hulu://", symbol: "tv", colorHex: "#16A34A", category: .media, keywords: "movies shows"),
        CatalogEntry(name: "Twitch", url: "twitch://", symbol: "play.tv.fill", colorHex: "#9146FF", category: .media, keywords: "stream live"),
        CatalogEntry(name: "Shazam", url: "shazam://", symbol: "waveform", colorHex: "#0EA5E9", category: .media, keywords: "song identify music"),

        // Productivity
        CatalogEntry(name: "Gmail", url: "googlegmail://", symbol: "envelope.open.fill", colorHex: "#EF4444", category: .productivity, keywords: "email google"),
        CatalogEntry(name: "Outlook", url: "ms-outlook://", symbol: "tray.fill", colorHex: "#0369A1", category: .productivity, keywords: "email microsoft"),
        CatalogEntry(name: "Chrome", url: "googlechrome://", symbol: "globe", colorHex: "#F59E0B", category: .productivity, keywords: "browser google"),
        CatalogEntry(name: "Slack", url: "slack://", symbol: "number", colorHex: "#A855F7", category: .productivity, keywords: "chat work"),
        CatalogEntry(name: "Teams", url: "msteams://", symbol: "person.3.fill", colorHex: "#6366F1", category: .productivity, keywords: "microsoft work"),
        CatalogEntry(name: "Zoom", url: "zoomus://", symbol: "video.fill", colorHex: "#3B82F6", category: .productivity, keywords: "meeting call"),
        CatalogEntry(name: "Notion", url: "notion://", symbol: "doc.text.fill", colorHex: "#111827", category: .productivity, keywords: "notes docs"),
        CatalogEntry(name: "Google Drive", url: "googledrive://", symbol: "externaldrive.fill", colorHex: "#F59E0B", category: .productivity, keywords: "files docs google"),
        CatalogEntry(name: "Google Photos", url: "googlephotos://", symbol: "photo.stack.fill", colorHex: "#3B82F6", category: .productivity, keywords: "pictures google"),
        CatalogEntry(name: "Duolingo", url: "duolingo://", symbol: "graduationcap.fill", colorHex: "#58CC02", category: .productivity, keywords: "language learn"),
        CatalogEntry(name: "Strava", url: "strava://", symbol: "figure.run", colorHex: "#FC4C02", category: .productivity, keywords: "run bike fitness"),

        // Shopping & travel
        CatalogEntry(name: "Google Maps", url: "comgooglemaps://", symbol: "mappin.and.ellipse", colorHex: "#10B981", category: .everyday, keywords: "directions"),
        CatalogEntry(name: "Uber", url: "uber://", symbol: "car.fill", colorHex: "#111827", category: .everyday, keywords: "ride taxi"),
        CatalogEntry(name: "Venmo", url: "venmo://", symbol: "dollarsign.circle.fill", colorHex: "#0EA5E9", category: .everyday, keywords: "pay money"),
        CatalogEntry(name: "Lyft", url: "lyft://", symbol: "car.side.fill", colorHex: "#FF00BF", category: .everyday, keywords: "ride taxi"),
        CatalogEntry(name: "Waze", url: "waze://", symbol: "location.fill", colorHex: "#33CCFF", category: .everyday, keywords: "directions traffic"),
        CatalogEntry(name: "Amazon", url: "com.amazon.mobile.shopping://", symbol: "cart.fill", colorHex: "#F59E0B", category: .everyday, keywords: "shop shopping"),
        CatalogEntry(name: "Airbnb", url: "airbnb://", symbol: "house.fill", colorHex: "#FF5A5F", category: .everyday, keywords: "travel stay"),
        CatalogEntry(name: "DoorDash", url: "doordash://", symbol: "takeoutbag.and.cup.and.straw.fill", colorHex: "#EF4444", category: .everyday, keywords: "food delivery"),
        CatalogEntry(name: "PayPal", url: "paypal://", symbol: "p.circle.fill", colorHex: "#1E40AF", category: .everyday, keywords: "pay money"),
        CatalogEntry(name: "Cash App", url: "squarecash://", symbol: "dollarsign.square.fill", colorHex: "#00D632", category: .everyday, keywords: "pay money"),
        CatalogEntry(name: "Signal", url: "sgnl://", symbol: "lock.circle.fill", colorHex: "#3A76F0", category: .social, keywords: "chat private"),

        // AI — these links are less established; if one doesn't open, switch the icon to a Shortcut.
        CatalogEntry(name: "ChatGPT", url: "chatgpt://", symbol: "sparkles", colorHex: "#10A37F", category: .ai, keywords: "ai openai chat gpt"),
        CatalogEntry(name: "Claude", url: "claude://", symbol: "asterisk", colorHex: "#D97757", category: .ai, keywords: "ai anthropic chat"),
        CatalogEntry(name: "Gemini", url: "googlegemini://", symbol: "sparkle", colorHex: "#4F7DF3", category: .ai, keywords: "ai google bard"),
        CatalogEntry(name: "Perplexity", url: "perplexity-app://", symbol: "magnifyingglass.circle.fill", colorHex: "#1F6F78", category: .ai, keywords: "ai search answer"),
        CatalogEntry(name: "Copilot", url: "ms-copilot://", symbol: "wand.and.stars", colorHex: "#6366F1", category: .ai, keywords: "ai microsoft bing"),
    ]

    static func entry(named name: String) -> CatalogEntry? {
        entries.first { $0.name == name }
    }

    /// App Store bundle IDs, used to fetch each app's official icon.
    static let bundleIDs: [String: String] = [
        "Mail": "com.apple.mobilemail", "Music": "com.apple.Music", "Maps": "com.apple.Maps",
        "Calendar": "com.apple.mobilecal", "Notes": "com.apple.mobilenotes", "Reminders": "com.apple.reminders",
        "Weather": "com.apple.weather", "Podcasts": "com.apple.podcasts", "Books": "com.apple.iBooks",
        "Files": "com.apple.DocumentsApp", "Shortcuts": "com.apple.shortcuts",
        "Instagram": "com.burbn.instagram", "WhatsApp": "net.whatsapp.WhatsApp", "Messenger": "com.facebook.Messenger",
        "Facebook": "com.facebook.Facebook", "X": "com.atebits.Tweetie2", "Threads": "com.burbn.barcelona",
        "TikTok": "com.zhiliaoapp.musically", "Snapchat": "com.toyopagroup.picaboo", "Telegram": "ph.telegra.Telegraph",
        "Discord": "com.hammerandchisel.discord", "Reddit": "com.reddit.Reddit", "LinkedIn": "com.linkedin.LinkedIn",
        "Spotify": "com.spotify.client", "YouTube": "com.google.ios.youtube", "Netflix": "com.netflix.Netflix",
        "Gmail": "com.google.Gmail", "Outlook": "com.microsoft.Office.Outlook", "Chrome": "com.google.chrome.ios",
        "Slack": "com.tinyspeck.chatlyio", "Teams": "com.microsoft.skype.teams", "Zoom": "us.zoom.videomeetings",
        "Notion": "notion.id", "Google Maps": "com.google.Maps", "Uber": "com.ubercab.UberClient",
        "Venmo": "net.kortina.labs.Venmo", "ChatGPT": "com.openai.chat", "Claude": "com.anthropic.claude",
        "Gemini": "com.google.gemini",
        "Prime Video": "com.amazon.aiv.AIVApp", "Disney+": "com.disney.disneyplus", "Hulu": "com.hulu.plus",
        "Twitch": "tv.twitch", "Shazam": "com.shazam.Shazam", "Google Drive": "com.google.Drive",
        "Google Photos": "com.google.photos", "Duolingo": "com.duolingo.DuolingoMobile", "Strava": "com.strava.stravaride",
        "Lyft": "com.zimride.instant", "Waze": "com.waze.iphone", "Amazon": "com.amazon.Amazon",
        "Airbnb": "com.airbnb.app", "DoorDash": "doordash.DoorDashConsumer", "PayPal": "com.yourcompany.PPClient",
        "Cash App": "com.squareup.cash", "Signal": "org.whispersystems.signal",
    ]

    /// The URL scheme Go asks iOS about to tell whether an app is installed ("spotify" for "spotify://").
    /// Every non-Apple scheme must also be listed under LSApplicationQueriesSchemes in project.yml
    /// (iOS allows at most 50), or iOS always answers "not installed".
    static func scheme(of entry: CatalogEntry) -> String? {
        guard entry.category != .apple, let colon = entry.url.firstIndex(of: ":") else { return nil }
        return String(entry.url[..<colon])
    }

    /// Built-in Apple apps that aren't on the App Store, so they have no icon to fetch.
    static let noStoreIcon: Set<String> = [
        "Phone", "Messages", "Safari", "Photos", "Wallet", "Health", "App Store", "Settings",
    ]
}
