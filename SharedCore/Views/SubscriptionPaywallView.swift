import ComposableArchitecture
import SwiftUI

struct SubscriptionPaywallView: View {
    let store: StoreOf<SubscriptionPaywallFeature>

    var body: some View {
        NavigationStack {
            List {
                Section {
                    paywallHeader
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))

                Section("Choose a plan") {
                    if store.isLoadingProducts {
                        HStack {
                            ProgressView()
                            Text("Loading plans")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }

                    ForEach(store.visibleProducts) { product in
                        planButton(product)
                    }
                }

                Section {
                    Button {
                        store.send(.restoreTapped)
                    } label: {
                        HStack {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                            Spacer()
                            if store.isRestoringPurchases {
                                ProgressView()
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .disabled(store.isRestoringPurchases || store.purchaseInProgressProductID != nil)

                    if let statusMessage = store.statusMessage {
                        Label(statusMessage, systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Unlock Unlimited Tasks")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        store.send(.dismissTapped)
                    }
                }
            }
            .task {
                store.send(.onAppear)
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 620, minHeight: 620)
        #endif
    }

    private var paywallHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Unlimited Tasks", systemImage: "checklist.checked")
                .font(.title3.weight(.semibold))

            Text("Free Routina includes \(store.limitSnapshot.freeTaskLimit) active tasks. Upgrade when you want to keep adding tasks without archiving or finishing existing work.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(store.limitSnapshot.activeTaskCount) active")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(store.limitSnapshot.freeTaskLimit) free")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(
                    value: Double(min(store.limitSnapshot.activeTaskCount, store.limitSnapshot.freeTaskLimit)),
                    total: Double(store.limitSnapshot.freeTaskLimit)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func planButton(_ product: RoutinaSubscriptionProduct) -> some View {
        Button {
            store.send(.purchaseTapped(product.id))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: product.plan == .lifetime ? "infinity.circle.fill" : "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(product.title)
                        .font(.headline)
                    Text(product.plan.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if store.purchaseInProgressProductID == product.id {
                    ProgressView()
                } else {
                    Text(product.priceSummary)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .disabled(
            store.products.isEmpty
                || store.purchaseInProgressProductID != nil
                || store.isRestoringPurchases
        )
    }
}
