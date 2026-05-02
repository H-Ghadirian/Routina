import SwiftUI
import UniformTypeIdentifiers

struct TaskDetailHeaderBadgeItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let systemImage: String?
    let tint: Color
}

struct TaskDetailHeaderSectionView<TagChipContent: View, AdditionalContent: View>: View {
    let title: String
    let statusContextMessage: String?
    let badgeRows: [[TaskDetailHeaderBadgeItem]]
    let tags: [String]
    let tagChip: (String) -> TagChipContent
    let additionalContent: () -> AdditionalContent

    init(
        title: String,
        statusContextMessage: String?,
        badgeRows: [[TaskDetailHeaderBadgeItem]],
        tags: [String],
        @ViewBuilder tagChip: @escaping (String) -> TagChipContent,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent
    ) {
        self.title = title
        self.statusContextMessage = statusContextMessage
        self.badgeRows = badgeRows
        self.tags = tags
        self.tagChip = tagChip
        self.additionalContent = additionalContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let statusContextMessage {
                    Text(statusContextMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(Array(badgeRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(row) { badge in
                        TaskDetailHeaderBadgeView(item: badge)
                    }
                }
            }

            additionalContent()

            if !tags.isEmpty {
                TaskDetailHeaderTagsView(tags: tags, tagChip: tagChip)
            }
        }
        .padding(16)
        .detailCardStyle(cornerRadius: 16)
    }
}

extension TaskDetailHeaderSectionView where AdditionalContent == EmptyView {
    init(
        title: String,
        statusContextMessage: String?,
        badgeRows: [[TaskDetailHeaderBadgeItem]],
        tags: [String],
        @ViewBuilder tagChip: @escaping (String) -> TagChipContent
    ) {
        self.init(
            title: title,
            statusContextMessage: statusContextMessage,
            badgeRows: badgeRows,
            tags: tags,
            tagChip: tagChip,
            additionalContent: { EmptyView() }
        )
    }
}

struct TaskDetailHeaderBadgeView: View {
    let item: TaskDetailHeaderBadgeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let systemImage = item.systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.tint)
                }

                Text(item.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(item.tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(item.tint.opacity(0.24), lineWidth: 1)
        )
    }
}

struct DetailHeaderBoxStyle: ViewModifier {
    var tint: Color = .secondary
    var minHeight: CGFloat? = nil

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
    }
}

extension View {
    func detailHeaderBoxStyle(tint: Color = .secondary, minHeight: CGFloat? = nil) -> some View {
        modifier(DetailHeaderBoxStyle(tint: tint, minHeight: minHeight))
    }
}

struct TaskDetailHeaderTagsView<TagChipContent: View>: View {
    let tags: [String]
    let tagChip: (String) -> TagChipContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TAGS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(tags, id: \.self) { tag in
                    tagChip(tag)
                }
            }
        }
    }
}

struct TaskDetailNotificationDisabledWarningView: View {
    let warningText: String
    let actionTitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "bell.slash.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text("No notification will fire")
                        .font(.subheadline.weight(.semibold))
                    Text(warningText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(actionTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.orange.opacity(0.25), lineWidth: 1)
        )
    }
}

struct TaskDetailStatusMetadataRow: View {
    let label: String
    let value: String
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct RoutineAttachmentFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct TaskDetailOverviewHeightsPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension Calendar {
    var orderedShortStandaloneWeekdaySymbols: [String] {
        let symbols = shortStandaloneWeekdaySymbols
        let startIndex = firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    func daysInMonthGrid(for monthStart: Date) -> [Date?] {
        guard
            let monthRange = range(of: .day, in: .month, for: monthStart),
            let monthInterval = dateInterval(of: .month, for: monthStart)
        else { return [] }

        let firstDay = monthInterval.start
        let firstWeekday = component(.weekday, from: firstDay)
        let leadingEmptyDays = (firstWeekday - self.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: leadingEmptyDays)
        for day in monthRange {
            if let date = date(byAdding: .day, value: day - 1, to: firstDay) {
                result.append(date)
            }
        }
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }
}

extension View {
    func detailCardStyle(cornerRadius: CGFloat = 12) -> some View {
        background(TaskDetailPlatformStyle.summaryCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
            )
    }
}
