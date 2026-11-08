import SwiftUI
import UIKit

struct SymbolPickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private static let symbols: [String] = [
        "app.fill", "star.fill", "heart.fill", "bolt.fill", "flame.fill", "leaf.fill", "drop.fill",
        "sparkles", "moon.fill", "sun.max.fill", "cloud.sun.fill", "snowflake", "globe", "safari.fill",
        "phone.fill", "message.fill", "bubble.left.fill", "bubble.left.and.bubble.right.fill", "envelope.fill",
        "paperplane.fill", "at", "person.fill", "person.2.fill", "person.3.fill", "house.fill",
        "music.note", "music.note.list", "headphones", "mic.fill", "radio.fill", "play.fill",
        "play.rectangle.fill", "tv.fill", "film.fill", "camera.fill", "camera.viewfinder", "photo.fill",
        "photo.on.rectangle", "paintbrush.fill", "paintpalette.fill", "pencil", "scribble", "book.fill",
        "books.vertical.fill", "newspaper.fill", "doc.text.fill", "note.text", "checklist", "list.bullet",
        "calendar", "clock.fill", "alarm.fill", "timer", "folder.fill", "tray.fill", "archivebox.fill",
        "map.fill", "mappin.and.ellipse", "location.fill", "car.fill", "bus.fill", "airplane", "bicycle",
        "figure.walk", "figure.run", "dumbbell.fill", "sportscourt.fill", "gamecontroller.fill", "puzzlepiece.fill",
        "cart.fill", "bag.fill", "creditcard.fill", "dollarsign.circle.fill", "wallet.pass.fill", "gift.fill",
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "birthday.cake.fill", "pawprint.fill", "tortoise.fill",
        "briefcase.fill", "building.2.fill", "graduationcap.fill", "lightbulb.fill", "brain.head.profile", "cross.case.fill",
        "pills.fill", "bed.double.fill", "gearshape.fill", "wrench.and.screwdriver.fill", "hammer.fill", "lock.fill",
        "key.fill", "wifi", "antenna.radiowaves.left.and.right", "square.stack.3d.up.fill", "number", "terminal.fill",
        "chevron.left.forwardslash.chevron.right", "cpu.fill", "magnifyingglass", "bell.fill", "flag.fill", "bookmark.fill",
    ]

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Self.symbols }
        return Self.symbols.filter { $0.contains(q) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
                ForEach(filtered, id: \.self) { name in
                    Button {
                        selection = name
                        dismiss()
                    } label: {
                        Image(systemName: name)
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 56, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(name == selection ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(name)
                }
            }
            .padding()

            // Any SF Symbol works — browse them all in Apple's free "SF Symbols" app.
            let custom = query.trimmingCharacters(in: .whitespaces)
            if !custom.isEmpty && UIImage(systemName: custom) != nil && !Self.symbols.contains(custom) {
                Button {
                    selection = custom
                    dismiss()
                } label: {
                    Label("Use “\(custom)”", systemImage: custom)
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
        }
        .searchable(text: $query, prompt: "Search or type any SF Symbol name")
        .textInputAutocapitalization(.never)
        .navigationTitle("Symbol")
        .navigationBarTitleDisplayMode(.inline)
    }
}
