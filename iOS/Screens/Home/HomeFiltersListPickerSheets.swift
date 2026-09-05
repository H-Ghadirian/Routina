import SwiftUI

struct HomeFiltersGroupingPickerSheet: View {
    @Binding var routineListSectioningMode: RoutineListSectioningMode

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Group rows", selection: $routineListSectioningMode) {
                        ForEach(RoutineListSectioningMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text(routineListSectioningMode.subtitle)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Group rows")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct HomeFiltersSortPickerSheet: View {
    @Binding var taskListSortOrder: HomeTaskListSortOrder

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Task order", selection: $taskListSortOrder) {
                        ForEach(HomeTaskListSortOrder.allCases) { order in
                            Label(order.title, systemImage: order.systemImage).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Task order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
