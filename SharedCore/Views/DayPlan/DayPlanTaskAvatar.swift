import SwiftUI

struct DayPlanTaskAvatar: View {
    var emoji: String?
    var tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.16))

            if let emoji = CalendarTaskImportSupport.displayEmoji(for: emoji) {
                Text(emoji)
                    .font(.title3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 34, height: 34)
    }
}
