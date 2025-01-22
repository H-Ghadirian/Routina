import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationView {
            List {
#if os(iOS)
                notificationSectionView

                supportSectionView
#endif
                aboutSectionView
            }
            .navigationTitle("Settings")
            .onAppear {
                viewModel.checkNotificationStatus()
            }.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                viewModel.checkNotificationStatus()
            }
            .alert("Enable Notifications", isPresented: $viewModel.showNotificationAlert) {
                Button("Cancel", role: .cancel) {}
                Button("OK") {
                    viewModel.requestNotificationPermission()
                }
            } message: {
                Text("To remind you about your routines, please enable notifications in Settings.")
            }
        }
    }

#if os(iOS)
    private var notificationSectionView: some View {
        Section(header: Text("Notifications")) {
            Toggle("Enable Notifications", isOn: $viewModel.appSettingNotificationsEnabled)
                .onChange(of: viewModel.appSettingNotificationsEnabled) { _, newValue in
                    viewModel.updateNotificationSettings(enabled: newValue)
                }
                .disabled(!viewModel.systemSettingsNotificationsEnabled)

            if !viewModel.systemSettingsNotificationsEnabled {
                Button("Allow Notifications in System Settings is disabled") {
                    if !UserDefaults.standard.bool(forKey: "requestNotificationPermission") {
                        viewModel.showNotificationAlert = true
                        return
                    }
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
    }

    private var supportSectionView: some View {
        Section(header: Text("Support")) {
            Button(action: viewModel.openEmail) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.blue)
                    Text("Contact Us")
                }
            }
        }
    }
#endif

    private var aboutSectionView: some View {
        Section(header: Text("About")) {
            HStack {
                Text("App Version")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundColor(.gray)
            }
        }
    }
}
