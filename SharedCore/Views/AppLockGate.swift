import ComposableArchitecture
import SwiftUI

@MainActor
final class AppLockCoordinator: ObservableObject {
    static let shared = AppLockCoordinator()

    @Published private(set) var isLocked = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var statusMessage = ""
    @Published private(set) var authenticationStatus = DeviceAuthenticationStatus.unavailable

    func synchronize(
        settings: AppSettingsClient,
        deviceAuthentication: DeviceAuthenticationClient,
        authenticateIfNeeded: Bool
    ) async {
        let appLockEnabled = settings.appLockEnabled()
        let authenticationStatus = deviceAuthentication.status()
        self.authenticationStatus = authenticationStatus

        guard appLockEnabled else {
            isLocked = false
            statusMessage = ""
            return
        }

        isLocked = true
        guard authenticateIfNeeded else { return }
        await attemptUnlock(settings: settings, deviceAuthentication: deviceAuthentication)
    }

    func lockIfNeeded(
        settings: AppSettingsClient,
        deviceAuthentication: DeviceAuthenticationClient
    ) {
        guard settings.appLockEnabled() else { return }
        authenticationStatus = deviceAuthentication.status()
        isLocked = true
        statusMessage = ""
    }

    func attemptUnlock(
        settings: AppSettingsClient,
        deviceAuthentication: DeviceAuthenticationClient
    ) async {
        guard settings.appLockEnabled() else {
            isLocked = false
            statusMessage = ""
            return
        }
        guard !isAuthenticating else { return }

        let authenticationStatus = deviceAuthentication.status()
        self.authenticationStatus = authenticationStatus

        guard authenticationStatus.isAvailable else {
            isLocked = true
            statusMessage = authenticationStatus.unavailableReason ?? "Device authentication is unavailable."
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        switch await deviceAuthentication.authenticate("Unlock Routina") {
        case .success:
            isLocked = false
            statusMessage = ""
        case .failure(let message):
            isLocked = true
            statusMessage = message
        }
    }

    func disableAppLock(settings: AppSettingsClient) {
        settings.setAppLockEnabled(false)
        isLocked = false
        statusMessage = ""
    }
}

struct AppLockGate<Content: View>: View {
    @Dependency(\.appSettingsClient) private var appSettingsClient
    @Dependency(\.deviceAuthenticationClient) private var deviceAuthenticationClient
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var coordinator = AppLockCoordinator.shared

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .blur(radius: coordinator.isLocked ? 5 : 0)
                .allowsHitTesting(!coordinator.isLocked)

            if coordinator.isLocked {
                lockOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .task {
            await coordinator.synchronize(
                settings: appSettingsClient,
                deviceAuthentication: deviceAuthenticationClient,
                authenticateIfNeeded: true
            )
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task { @MainActor in
                switch newPhase {
                case .active:
                    await coordinator.synchronize(
                        settings: appSettingsClient,
                        deviceAuthentication: deviceAuthenticationClient,
                        authenticateIfNeeded: true
                    )
                case .inactive, .background:
                    coordinator.lockIfNeeded(
                        settings: appSettingsClient,
                        deviceAuthentication: deviceAuthenticationClient
                    )
                @unknown default:
                    break
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: coordinator.isLocked)
    }

    private var lockOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.14))
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Unlock Routina")
                        .font(.title3.weight(.semibold))

                    Text(lockExplanationText)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                if !coordinator.statusMessage.isEmpty {
                    Text(coordinator.statusMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { @MainActor in
                        await coordinator.attemptUnlock(
                            settings: appSettingsClient,
                            deviceAuthentication: deviceAuthenticationClient
                        )
                    }
                } label: {
                    if coordinator.isAuthenticating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Unlock", systemImage: "lock.open.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(coordinator.isAuthenticating)

                if coordinator.authenticationStatus.isAvailable == false {
                    Button("Turn Off App Lock") {
                        coordinator.disableAppLock(settings: appSettingsClient)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
            .padding(24)
        }
    }

    private var lockExplanationText: String {
        let methodDescription = coordinator.authenticationStatus.methodDescription

        if coordinator.authenticationStatus.isAvailable {
            return "Use \(methodDescription) to continue."
        }

        return coordinator.authenticationStatus.unavailableReason
            ?? "Device authentication is unavailable right now."
    }
}
