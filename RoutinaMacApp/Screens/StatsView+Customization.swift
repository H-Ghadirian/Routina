import Foundation
import SwiftUI

extension StatsView {
    var dashboardEditButton: some View {
        Button(isEditingDashboard ? "Done" : "Edit") {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isEditingDashboard.toggle()
            }
        }
        .help(isEditingDashboard ? "Finish editing stats dashboard" : "Edit stats dashboard")
        .accessibilityLabel(isEditingDashboard ? "Finish editing stats dashboard" : "Edit stats dashboard")
    }

    var summaryDisplayModeMenu: some View {
        Menu {
            Picker("Summary view", selection: summaryDisplayModeBinding) {
                ForEach(StatsSummaryDisplayMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Summary view", systemImage: summaryDisplayMode.systemImage)
        }
        .help("Change summary card density")
        .accessibilityLabel("Summary card view")
    }

    var dashboardEditControls: some View {
        HStack(spacing: 12) {
            Button {
                isAddDashboardItemSheetPresented = true
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(hiddenAvailableDashboardItems.isEmpty)
            .accessibilityLabel("Add stats item")

            Button {
                showAllDashboardItems()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .disabled(hiddenDashboardItemIDs.isEmpty && dashboardItemOrderIDsRaw.isEmpty)
            .accessibilityLabel("Reset stats dashboard")
        }
    }

    var addDashboardItemSheet: some View {
        NavigationStack {
            List {
                if hiddenAvailableDashboardItems.isEmpty {
                    ContentUnavailableView(
                        "All items are visible",
                        systemImage: "checkmark.circle",
                        description: Text("Remove a stats item to add it back here.")
                    )
                } else {
                    Section("Hidden items") {
                        ForEach(hiddenAvailableDashboardItems) { item in
                            Button {
                                addDashboardItem(item)
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .foregroundStyle(.primary)

                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: item.systemImage)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(item.title)")
                        }
                    }
                }
            }
            .frame(minWidth: 360, minHeight: 320)
            .navigationTitle("Add to Stats")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isAddDashboardItemSheetPresented = false
                    }
                }
            }
        }
    }

    private func removeDashboardItem(_ item: StatsMacDashboardItem) {
        var hiddenIDs = hiddenDashboardItemIDs
        hiddenIDs.insert(item.rawValue)
        setHiddenDashboardItemIDs(hiddenIDs)
    }

    private func addDashboardItem(_ item: StatsMacDashboardItem) {
        var hiddenIDs = hiddenDashboardItemIDs
        hiddenIDs.remove(item.rawValue)
        setHiddenDashboardItemIDs(hiddenIDs)

        if hiddenAvailableDashboardItems.isEmpty {
            isAddDashboardItemSheetPresented = false
        }
    }

    private func showAllDashboardItems() {
        setHiddenDashboardItemIDs([])
        setDashboardItemOrderIDs([])
    }

    private func setHiddenDashboardItemIDs(_ itemIDs: Set<String>) {
        let rawValue = itemIDs.sorted().joined(separator: ",")
        CloudSettingsKeyValueSync.setString(
            rawValue,
            for: .appSettingMacStatsDashboardHiddenItemIDs
        )
    }

    private func moveDashboardItem(_ draggedItemID: String, before targetItemID: String) {
        let defaultItemIDs = StatsMacDashboardItem.allCases.map(\.rawValue)
        let orderedItemIDs = StatsDashboardOrderSupport.normalizedItemIDs(
            defaultItemIDs: defaultItemIDs,
            storedRawValue: dashboardItemOrderIDsRaw
        )
        let movedItemIDs = StatsDashboardOrderSupport.movedItemIDs(
            draggedItemID: draggedItemID,
            before: targetItemID,
            in: orderedItemIDs
        )
        setDashboardItemOrderIDs(movedItemIDs)
    }

    private func setDashboardItemOrderIDs(_ itemIDs: [String]) {
        let defaultItemIDs = StatsMacDashboardItem.allCases.map(\.rawValue)
        let rawValue = StatsDashboardOrderSupport.storedRawValue(
            for: itemIDs,
            defaultItemIDs: defaultItemIDs
        )
        CloudSettingsKeyValueSync.setString(
            rawValue,
            for: .appSettingMacStatsDashboardItemOrderIDs
        )
    }

    func editableDashboardSection<Content: View>(
        _ item: StatsMacDashboardItem,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Group {
            if isEditingDashboard {
                ZStack(alignment: .topLeading) {
                    content()
                        .opacity(0.96)

                    Button {
                        removeDashboardItem(item)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 34, height: 34)
                            .routinaGlassPill(interactive: true)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                    }
                    .buttonStyle(.plain)
                    .offset(x: -7, y: -10)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Remove \(item.title)")

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .routinaGlassPill(interactive: true)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.16), radius: 5, y: 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 7, y: -10)
                        .help("Move \(item.title)")
                        .accessibilityLabel("Move \(item.title)")
                }
                .contentShape(Rectangle())
                .onDrag {
                    draggedDashboardItemID = item.rawValue
                    return NSItemProvider(object: item.rawValue as NSString)
                }
                .onDrop(
                    of: StatsDashboardReorderDropDelegate.supportedContentTypes,
                    delegate: StatsDashboardReorderDropDelegate(
                        itemID: item.rawValue,
                        draggedItemID: $draggedDashboardItemID,
                        orderedItemIDs: scopedVisibleOrderedDashboardItems.map(\.rawValue),
                        onMove: moveDashboardItem
                    )
                )
                .zIndex(draggedDashboardItemID == item.rawValue ? 1 : 0)
            } else {
                content()
            }
        }
    }
}
