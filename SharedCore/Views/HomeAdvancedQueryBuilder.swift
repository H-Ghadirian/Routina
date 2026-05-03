import SwiftUI

struct HomeAdvancedQueryBuilder: View {
    @Binding var query: String
    var usesFlowLayout: Bool = false
    var options = HomeAdvancedQueryOptions()

    @FocusState private var isFocused: Bool

    private var state: HomeAdvancedQueryInputState {
        HomeAdvancedQueryInputState(query: query, options: options)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            inlineQueryInput

            suggestionRow
        }
    }

    private var inlineQueryInput: some View {
        HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(Array(state.tokens.enumerated()), id: \.offset) { index, token in
                committedTokenChip(token, at: index)
            }

            queryDraftInput
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? Color.accentColor : Color.secondary.opacity(0.24), lineWidth: isFocused ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture { isFocused = true }
    }

    private var queryDraftInput: some View {
        ZStack(alignment: .leading) {
            if isFocused, let ghostSuffix = state.primaryGhostSuffix, !ghostSuffix.isEmpty {
                HStack(spacing: 0) {
                    Text(state.draft)
                        .foregroundStyle(.clear)
                    Text(ghostSuffix)
                        .foregroundStyle(.tertiary)
                }
                .font(.body)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            TextField(state.tokens.isEmpty ? "tag:work -is:done type:todo" : "", text: draftBinding)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .advancedQueryInputTraits()
                .frame(minWidth: state.draft.isEmpty ? 140 : 40)
                .onSubmit { acceptPrimarySuggestionOrCommitDraft() }
                .onKeyPress(SwiftUI.KeyEquivalent.tab) {
                    acceptPrimarySuggestionOrCommitDraft()
                    return SwiftUI.KeyPress.Result.handled
                }
                .onKeyPress(SwiftUI.KeyEquivalent.space) {
                    commitDraftFromSpace()
                    return SwiftUI.KeyPress.Result.handled
                }
                .onKeyPress(SwiftUI.KeyEquivalent.delete) {
                    if state.draft.isEmpty, !state.tokens.isEmpty {
                        query = state.removingToken(at: state.tokens.count - 1)
                        return SwiftUI.KeyPress.Result.handled
                    }
                    return SwiftUI.KeyPress.Result.ignored
                }
        }
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { state.draft },
            set: { newValue in
                if newValue.contains(where: \.isWhitespace) {
                    let draft = newValue.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
                    query = HomeAdvancedQueryInputState(query: query, options: options).committingDraft(draft)
                } else {
                    query = HomeAdvancedQueryInputState(query: query, options: options).replacingDraftOrCommittingExactAtomicToken(with: newValue)
                }
            }
        )
    }

    @ViewBuilder
    private var suggestionRow: some View {
        let suggestions = state.suggestions
        if usesFlowLayout {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(suggestions) { suggestionButton($0) }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { suggestionButton($0) }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func committedTokenChip(_ token: String, at index: Int) -> some View {
        Button {
            query = state.removingToken(at: index)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)

                ForEach(state.displayParts(for: token)) { part in
                    Text(part.title)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(part.kind.color.opacity(0.18))
                        )
                        .foregroundStyle(part.kind.color)
                }
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.plain)
        .controlSize(.small)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(token.isAdvancedQueryOperator ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
        )
        .help("Remove \(token)")
    }

    private func suggestionButton(_ suggestion: HomeAdvancedQuerySuggestion) -> some View {
        Button {
            query = state.accepting(suggestion)
            isFocused = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.token)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(suggestion.kind.color)
                Text(suggestion.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 30, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(suggestion.description)
    }

    private func acceptPrimarySuggestionOrCommitDraft() {
        if let suggestion = state.primarySuggestion {
            query = state.accepting(suggestion)
        } else {
            query = state.committingDraft()
        }
    }

    private func commitDraftFromSpace() {
        query = state.draft.isEmpty ? state.query : state.committingDraft()
    }
}

private extension HomeAdvancedQueryPartKind {
    var color: Color {
        switch self {
        case .key:
            return .blue
        case .operatorToken:
            return .orange
        case .value:
            return .green
        case .conjunction:
            return .purple
        }
    }
}

private extension View {
    @ViewBuilder
    func advancedQueryInputTraits() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }
}
