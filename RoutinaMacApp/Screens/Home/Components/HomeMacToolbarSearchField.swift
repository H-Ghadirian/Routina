import AppKit
import Foundation
import SwiftUI

enum HomeMacToolbarSearchLayout {
    static let compactWidth: CGFloat = 620
    static let focusedWidth: CGFloat = 860
    static let height: CGFloat = 44
    static let cornerRadius: CGFloat = 22
    static let horizontalPadding: CGFloat = 18
    static let iconSize: CGFloat = 18
    static let textFieldHeight: CGFloat = 26
    static let clearButtonSize: CGFloat = 22
    static let clearButtonHitSize: CGFloat = 34
    static let createHintWidth: CGFloat = 154
    static let animationDuration: TimeInterval = 0.22
    static let toolbarActionRestoreDelay: TimeInterval = animationDuration
    static let parserPreviewTopPadding: CGFloat = 12
    static let parserPreviewTrailingPadding: CGFloat = 22
    static let topToolbarHeight: CGFloat = 62
    static let topToolbarHorizontalPadding: CGFloat = 18
    static let trafficLightReservedLeadingPadding: CGFloat = 184
    static let sidebarToggleLeadingPadding: CGFloat = 28
    static let sidebarToggleButtonSize: CGFloat = 28

    static var toolbarBackground: Color {
        Color(nsColor: .windowBackgroundColor).opacity(0.98)
    }

    static func searchBackgroundColor(isFocused: Bool) -> Color {
        if isFocused {
            Color(nsColor: .textBackgroundColor).opacity(0.98)
        } else {
            Color(nsColor: .controlBackgroundColor).opacity(0.82)
        }
    }

    static func searchStrokeColor(isFocused: Bool) -> Color {
        Color.secondary.opacity(isFocused ? 0.24 : 0.14)
    }
}

struct HomeMacToolbarSearchField: View {
    @Binding var text: String
    @Binding var isTextFocused: Bool
    @Binding var isSearchExpanded: Bool
    @Binding var visiblePillWidth: CGFloat
    @Binding var searchExpansionTransitionID: Int
    @Binding var focusRequestID: Int
    @Binding var focusDismissRequestID: Int
    let isCreatingTask: Bool
    let canCreateTaskFromQuery: Bool
    let onSubmit: (String) -> Void
    let onCommandSubmit: (String) -> Void

    var body: some View {
        searchShell(width: visiblePillWidth)
            .frame(
                width: visiblePillWidth,
                height: HomeMacToolbarSearchLayout.height,
                alignment: .center
            )
            .allowsHitTesting(true)
            .animation(
                .easeInOut(duration: HomeMacToolbarSearchLayout.animationDuration),
                value: visiblePillWidth
            )
    }

    private func searchShell(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            searchFocusTarget(width: width)

            if usesCenteredIdleContent {
                centeredIdleContent
                    .frame(
                        width: width,
                        height: HomeMacToolbarSearchLayout.height,
                        alignment: .center
                    )
                    .transition(.opacity)
            }

            Image(systemName: "magnifyingglass")
                .font(.system(size: HomeMacToolbarSearchLayout.iconSize, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(
                    width: HomeMacToolbarSearchLayout.iconSize,
                    height: HomeMacToolbarSearchLayout.iconSize
                )
                .offset(x: HomeMacToolbarSearchLayout.horizontalPadding)
                .opacity(usesCenteredIdleContent ? 0 : 1)
                .allowsHitTesting(false)

            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        placeholderLabel
                    }

                    textEditor
                }
                .layoutPriority(1)

                if !text.isEmpty {
                    clearSearchButton
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .layoutPriority(2)
                        .zIndex(2)
                }

                if showsCreateHint {
                    createHint
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .layoutPriority(3)
                }

                if isTextFocused {
                    closeButton
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .layoutPriority(2)
                }
            }
            .padding(.leading, textLeading)
            .padding(.trailing, 12)
            .frame(width: width, height: HomeMacToolbarSearchLayout.height, alignment: .leading)
            .opacity(usesCenteredIdleContent ? 0 : 1)
            .allowsHitTesting(!usesCenteredIdleContent)
        }
        .frame(width: width, height: HomeMacToolbarSearchLayout.height)
        .background {
            searchBackground
        }
        .overlay {
            searchBorder
        }
        .overlay {
            outsideClickDismissLayer
                .allowsHitTesting(false)
        }
        .contentShape(searchShape)
        .animation(.easeOut(duration: 0.12), value: text.isEmpty)
        .animation(.easeOut(duration: 0.12), value: showsCreateHint)
        .animation(.easeOut(duration: 0.12), value: usesCenteredIdleContent)
        .help(HomeMacToolbarSearchCopy.help)
        .accessibilityLabel(HomeMacToolbarSearchCopy.accessibilityLabel)
    }

    private var searchBackground: some View {
        searchShape
            .fill(HomeMacToolbarSearchLayout.searchBackgroundColor(isFocused: isTextFocused))
    }

    private var searchBorder: some View {
        searchShape
            .stroke(HomeMacToolbarSearchLayout.searchStrokeColor(isFocused: isTextFocused), lineWidth: 1)
    }

    private var searchShape: some Shape {
        RoundedRectangle(
            cornerRadius: HomeMacToolbarSearchLayout.cornerRadius,
            style: .continuous
        )
    }

    private func searchFocusTarget(width: CGFloat) -> some View {
        Button {
            beginSearchFocusRequest()
        } label: {
            Color.clear
                .frame(width: width, height: HomeMacToolbarSearchLayout.height)
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: HomeMacToolbarSearchLayout.cornerRadius,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(.plain)
        .frame(width: width, height: HomeMacToolbarSearchLayout.height)
        .contentShape(
            RoundedRectangle(
                cornerRadius: HomeMacToolbarSearchLayout.cornerRadius,
                style: .continuous
            )
        )
        .accessibilityHidden(true)
    }

    private var outsideClickDismissLayer: some View {
        HomeMacSearchOutsideDismissView(
            isFocused: searchFocusBinding,
            focusRequestID: $focusRequestID,
            focusDismissRequestID: $focusDismissRequestID
        )
        .accessibilityHidden(true)
    }

    private var placeholderLabel: some View {
        Text(HomeMacToolbarSearchCopy.placeholder)
            .font(Font.body.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .allowsHitTesting(false)
    }

    private var centeredIdleContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: HomeMacToolbarSearchLayout.iconSize, weight: .medium))
                .foregroundStyle(.secondary)

            Text(HomeMacToolbarSearchCopy.placeholder)
                .font(Font.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, HomeMacToolbarSearchLayout.horizontalPadding)
        .allowsHitTesting(false)
    }

    private var textEditor: some View {
        HomeMacToolbarSearchTextField(
            text: $text,
            isCreatingTask: isCreatingTask,
            isFocused: searchFocusBinding,
            focusRequestID: focusRequestID,
            focusDismissRequestID: focusDismissRequestID,
            onSubmit: onSubmit,
            onCommandSubmit: onCommandSubmit
        )
        .frame(maxWidth: .infinity)
        .frame(height: HomeMacToolbarSearchLayout.textFieldHeight)
        .layoutPriority(1)
    }

    private var clearSearchButton: some View {
        Button {
            clearSearchText()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(
                    width: HomeMacToolbarSearchLayout.clearButtonSize,
                    height: HomeMacToolbarSearchLayout.clearButtonSize
                )
        }
        .buttonStyle(.plain)
        .frame(
            width: HomeMacToolbarSearchLayout.clearButtonHitSize,
            height: HomeMacToolbarSearchLayout.clearButtonHitSize
        )
        .contentShape(Circle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !text.isEmpty else { return }
                    clearSearchText()
                }
        )
        .accessibilityLabel(HomeMacToolbarSearchCopy.clearAccessibilityLabel)
        .help(HomeMacToolbarSearchCopy.clearHelp)
    }

    private var closeButton: some View {
        Button {
            dismissSearchFocusFromKeycap()
        } label: {
            Text("Esc")
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(Color.secondary)
        }
        .buttonStyle(.plain)
        .frame(width: 34, height: 28)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
        }
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityLabel(HomeMacToolbarSearchCopy.closeAccessibilityLabel)
        .help(HomeMacToolbarSearchCopy.closeHelp)
    }

    private var textLeading: CGFloat {
        HomeMacToolbarSearchLayout.horizontalPadding
            + HomeMacToolbarSearchLayout.iconSize
            + 10
    }

    private var usesCenteredIdleContent: Bool {
        !isTextFocused && text.isEmpty
    }

    private var searchFocusBinding: Binding<Bool> {
        Binding(
            get: { isTextFocused },
            set: { setSearchFocused($0) }
        )
    }

    private func beginSearchFocusRequest() {
        focusRequestID += 1
        setSearchFocused(true)
    }

    private func clearSearchText() {
        text = ""
        focusRequestID += 1
        setSearchFocused(true)

        DispatchQueue.main.async {
            text = ""
            focusRequestID += 1
        }
    }

    private func dismissSearchFocusFromKeycap() {
        setSearchFocused(false)
        focusDismissRequestID += 1
    }

    private func setSearchFocused(_ nextValue: Bool) {
        if nextValue {
            searchExpansionTransitionID += 1
            let transitionID = searchExpansionTransitionID
            if !isSearchExpanded {
                visiblePillWidth = HomeMacToolbarSearchLayout.compactWidth
                isSearchExpanded = true
                DispatchQueue.main.async {
                    guard searchExpansionTransitionID == transitionID else { return }
                    animateVisiblePillWidth(to: HomeMacToolbarSearchLayout.focusedWidth)
                }
            } else {
                animateVisiblePillWidth(to: HomeMacToolbarSearchLayout.focusedWidth)
            }
            if !isTextFocused {
                isTextFocused = true
            }
            return
        }

        guard isTextFocused || isSearchExpanded else { return }
        isTextFocused = false
        animateVisiblePillWidth(to: HomeMacToolbarSearchLayout.compactWidth)
        let transitionID = searchExpansionTransitionID
        DispatchQueue.main.asyncAfter(deadline: .now() + HomeMacToolbarSearchLayout.toolbarActionRestoreDelay) {
            guard searchExpansionTransitionID == transitionID else { return }
            isSearchExpanded = false
        }
    }

    private func animateVisiblePillWidth(to width: CGFloat) {
        withAnimation(.easeInOut(duration: HomeMacToolbarSearchLayout.animationDuration)) {
            visiblePillWidth = width
        }
    }

    private var showsCreateHint: Bool {
        isTextFocused && (isCreatingTask || canCreateTaskFromQuery)
    }

    private var createHint: some View {
        HStack(spacing: 6) {
            if isCreatingTask {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.72)

                Text(HomeMacToolbarSearchCopy.creatingHint)
            } else {
                Text(HomeMacToolbarSearchCopy.returnKeyHint)
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.secondary.opacity(0.14))
                    }

                Text(HomeMacToolbarSearchCopy.createHint)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isCreatingTask ? Color.accentColor : Color.secondary)
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal, 10)
        .frame(width: HomeMacToolbarSearchLayout.createHintWidth, alignment: .leading)
        .frame(height: 28)
        .background {
            Capsule(style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
