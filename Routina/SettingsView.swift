import SwiftUI

struct SettingsView: View {
    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .padding()

            Text("App Version: \(appVersion)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }
}
