import SwiftUI

struct TaskDetailEqualHeightPairRow<Leading: View, Trailing: View>: View {
    let spacing: CGFloat
    let leading: (CGFloat?) -> Leading
    let trailing: (CGFloat?) -> Trailing

    @State private var measuredHeight: CGFloat = 0

    init(
        spacing: CGFloat = 8,
        @ViewBuilder leading: @escaping (CGFloat?) -> Leading,
        @ViewBuilder trailing: @escaping (CGFloat?) -> Trailing
    ) {
        self.spacing = spacing
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        let synchronizedHeight = measuredHeight > 0 ? measuredHeight : nil

        HStack(alignment: .top, spacing: spacing) {
            leading(synchronizedHeight)
                .background(TaskDetailEqualHeightReader(id: "leading"))
                .frame(maxWidth: .infinity, alignment: .topLeading)

            trailing(synchronizedHeight)
                .background(TaskDetailEqualHeightReader(id: "trailing"))
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onPreferenceChange(TaskDetailEqualHeightPreferenceKey.self) { heights in
            let maxHeight = heights.values.max() ?? 0
            guard abs(maxHeight - measuredHeight) > 0.5 else { return }
            measuredHeight = maxHeight
        }
    }
}

private struct TaskDetailEqualHeightReader: View {
    let id: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: TaskDetailEqualHeightPreferenceKey.self,
                value: [id: proxy.size.height]
            )
        }
    }
}

private struct TaskDetailEqualHeightPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
