import ComposableArchitecture
import SwiftUI

struct SubscriptionPaywallView: View {
    @Environment(\.colorScheme) private var colorScheme

    let store: StoreOf<SubscriptionPaywallFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    paywallHeader
                    planSection
                    purchaseSupportSection
                }
                .padding(.horizontal, pageHorizontalPadding)
                .padding(.vertical, 22)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(pageBackground)
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
        .frame(minWidth: 560, idealWidth: 660, minHeight: 620)
        #endif
    }

    private var paywallHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "checklist.checked")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.18), radius: 14, y: 6)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Unlimited Tasks")
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text("Keep building your routines without archiving or finishing existing work just to make room.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            usageMeter
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassPanel(
            cornerRadius: 18,
            tint: .accentColor,
            tintOpacity: colorScheme == .dark ? 0.08 : 0.06
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.18), lineWidth: 1)
        }
    }

    private var usageMeter: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.limitSnapshot.activeTaskCount)")
                        .font(.title.weight(.bold))
                        .monospacedDigit()

                    Text("active tasks")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(store.limitSnapshot.freeTaskLimit)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()

                    Text("free limit")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            usageProgressBar

            if overFreeLimitCount > 0 {
                Label("\(overFreeLimitCount) over the free limit", systemImage: "arrow.up.forward")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(colorScheme == .dark ? 0.08 : 0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(colorScheme == .dark ? 0.16 : 0.12), lineWidth: 1)
        }
    }

    private var usageProgressBar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * usageProgressFraction

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.secondary.opacity(colorScheme == .dark ? 0.18 : 0.12))

                Capsule(style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: max(width, usageProgressFraction > 0 ? 8 : 0))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Choose a plan")

            if store.isLoadingProducts {
                loadingPlansRow
            }

            VStack(spacing: 10) {
                ForEach(store.visibleProducts) { product in
                    planButton(product)
                }
            }
        }
    }

    private var loadingPlansRow: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("Loading plans")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(colorScheme == .dark ? 0.08 : 0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var purchaseSupportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                store.send(.restoreTapped)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text("Restore Purchases")
                        .font(.headline)

                    Spacer(minLength: 10)

                    if store.isRestoringPurchases {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .background(Color.secondary.opacity(colorScheme == .dark ? 0.08 : 0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(colorScheme == .dark ? 0.18 : 0.12), lineWidth: 1)
            }
            .disabled(store.isRestoringPurchases || store.purchaseInProgressProductID != nil)

            if let statusMessage = store.statusMessage {
                statusBanner(statusMessage)
            }
        }
    }

    private func planButton(_ product: RoutinaSubscriptionProduct) -> some View {
        let isDisabled = store.products.isEmpty
            || store.purchaseInProgressProductID != nil
            || store.isRestoringPurchases

        return Button {
            store.send(.purchaseTapped(product.id))
        } label: {
            HStack(spacing: 14) {
                Image(systemName: product.plan.paywallIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(product.plan.paywallAccent)
                    .frame(width: 42, height: 42)
                    .background(product.plan.paywallAccent.opacity(colorScheme == .dark ? 0.16 : 0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(product.title)
                                .font(.headline)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            planPrice(product)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.title)
                                .font(.headline)
                                .lineLimit(2)

                            planPrice(product)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(product.plan.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let badgeText = product.plan.paywallBadgeText {
                            Text(badgeText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(product.plan.paywallAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(product.plan.paywallAccent.opacity(colorScheme == .dark ? 0.16 : 0.10), in: Capsule(style: .continuous))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                if store.purchaseInProgressProductID == product.id {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .routinaGlassCard(
            cornerRadius: 14,
            tint: product.plan.paywallAccent,
            tintOpacity: colorScheme == .dark ? 0.08 : 0.05,
            interactive: true
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(product.plan.paywallAccent.opacity(colorScheme == .dark ? 0.22 : 0.16), lineWidth: 1)
        }
        .opacity(isDisabled ? 0.62 : 1)
        .disabled(
            isDisabled
        )
    }

    private func planPrice(_ product: RoutinaSubscriptionProduct) -> some View {
        Text(product.priceSummary)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.trailing)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func statusBanner(_ message: String) -> some View {
        Label {
            Text(message)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: statusSystemImage(for: message))
        }
        .foregroundStyle(statusTint(for: message))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusTint(for: message).opacity(colorScheme == .dark ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func statusSystemImage(for message: String) -> String {
        message.localizedCaseInsensitiveContains("unlocked") ? "checkmark.circle.fill" : "info.circle"
    }

    private func statusTint(for message: String) -> Color {
        message.localizedCaseInsensitiveContains("unlocked") ? .green : .secondary
    }

    private var overFreeLimitCount: Int {
        max(store.limitSnapshot.activeTaskCount - store.limitSnapshot.freeTaskLimit, 0)
    }

    private var usageProgressFraction: CGFloat {
        guard store.limitSnapshot.freeTaskLimit > 0 else { return 0 }
        let cappedCount = min(store.limitSnapshot.activeTaskCount, store.limitSnapshot.freeTaskLimit)
        return CGFloat(cappedCount) / CGFloat(store.limitSnapshot.freeTaskLimit)
    }

    private var pageBackground: some ShapeStyle {
        Color.secondary.opacity(colorScheme == .dark ? 0.035 : 0.025)
    }

    private var pageHorizontalPadding: CGFloat {
        #if os(macOS)
        28
        #else
        18
        #endif
    }
}

private extension RoutinaSubscriptionPlan {
    var paywallIcon: String {
        switch self {
        case .weekly:
            return "calendar.badge.clock"
        case .monthly:
            return "calendar"
        case .annual:
            return "calendar.badge.checkmark"
        case .lifetime:
            return "infinity.circle.fill"
        }
    }

    var paywallAccent: Color {
        switch self {
        case .weekly:
            return .blue
        case .monthly:
            return .teal
        case .annual:
            return .green
        case .lifetime:
            return .indigo
        }
    }

    var paywallBadgeText: String? {
        switch self {
        case .lifetime:
            return "One-time"
        case .weekly, .monthly, .annual:
            return nil
        }
    }
}
