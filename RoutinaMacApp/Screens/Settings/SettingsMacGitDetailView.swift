import ComposableArchitecture
import SwiftUI

struct SettingsMacGitDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Git",
                subtitle: "Connect GitHub or GitLab to display contribution activity on your dashboard."
            ) {
                Text("GitHub")
                    .font(.title2.weight(.semibold))

                SettingsMacDetailCard(title: "Mode") {
                    Picker("Source", selection: scopeBinding) {
                        ForEach(GitHubStatsScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.github.scope.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if store.github.scope == .repository {
                    SettingsMacDetailCard(title: "Repository") {
                        TextField("Owner", text: repositoryOwnerBinding)
                            .textFieldStyle(.roundedBorder)

                        TextField("Repository", text: repositoryNameBinding)
                            .textFieldStyle(.roundedBorder)

                        Text(store.github.repositorySummaryText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let validationMessage = store.github.saveValidationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    SettingsMacDetailCard(title: "Profile") {
                        Text(store.github.profileSummaryText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let validationMessage = store.github.saveValidationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }

                SettingsMacDetailCard(title: "Access Token") {
                    SecureField("Personal access token", text: gitHubAccessTokenBinding)
                        .textFieldStyle(.roundedBorder)

                    Text(store.github.tokenStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Actions") {
                    HStack(spacing: 12) {
                        Button {
                            store.send(.saveGitHubConnectionTapped)
                        } label: {
                            if store.github.isOperationInProgress {
                                ProgressView()
                            } else {
                                Label(store.github.saveButtonTitle, systemImage: "link.badge.plus")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.github.isSaveDisabled)

                        Button(role: .destructive) {
                            store.send(.clearGitHubConnectionTapped)
                        } label: {
                            Label("Remove Connection", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.github.removeButtonDisabled)
                    }

                    Text(store.github.infoText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !store.github.statusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.github.statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("GitLab")
                    .font(.title2.weight(.semibold))
                    .padding(.top, 8)

                SettingsMacDetailCard(title: "Profile") {
                    Text(store.gitlab.profileSummaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let validationMessage = store.gitlab.saveValidationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                SettingsMacDetailCard(title: "Access Token") {
                    SecureField("Personal access token", text: gitLabAccessTokenBinding)
                        .textFieldStyle(.roundedBorder)

                    Text(store.gitlab.tokenStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Actions") {
                    HStack(spacing: 12) {
                        Button {
                            store.send(.saveGitLabConnectionTapped)
                        } label: {
                            if store.gitlab.isOperationInProgress {
                                ProgressView()
                            } else {
                                Label(store.gitlab.saveButtonTitle, systemImage: "link.badge.plus")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.gitlab.isSaveDisabled)

                        Button(role: .destructive) {
                            store.send(.clearGitLabConnectionTapped)
                        } label: {
                            Label("Remove Connection", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.gitlab.removeButtonDisabled)
                    }

                    Text(store.gitlab.infoText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !store.gitlab.statusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.gitlab.statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var scopeBinding: Binding<GitHubStatsScope> {
        Binding(
            get: { store.github.scope },
            set: { store.send(.gitHubScopeChanged($0)) }
        )
    }

    private var repositoryOwnerBinding: Binding<String> {
        Binding(
            get: { store.github.repositoryOwner },
            set: { store.send(.gitHubOwnerChanged($0)) }
        )
    }

    private var repositoryNameBinding: Binding<String> {
        Binding(
            get: { store.github.repositoryName },
            set: { store.send(.gitHubRepositoryChanged($0)) }
        )
    }

    private var gitHubAccessTokenBinding: Binding<String> {
        Binding(
            get: { store.github.accessTokenDraft },
            set: { store.send(.gitHubTokenChanged($0)) }
        )
    }

    private var gitLabAccessTokenBinding: Binding<String> {
        Binding(
            get: { store.gitlab.accessTokenDraft },
            set: { store.send(.gitLabTokenChanged($0)) }
        )
    }
}
