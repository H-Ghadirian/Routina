import ComposableArchitecture
import SwiftUI

struct SettingsGitDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("GitHub – Mode") {
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
                    Section("GitHub – Repository") {
                        TextField("Owner", text: repositoryOwnerBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("Repository", text: repositoryNameBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

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
                    Section("GitHub – Profile") {
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

                Section("GitHub – Access Token") {
                    SecureField("Personal access token", text: gitHubAccessTokenBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text(store.github.tokenStatusText)
                        .foregroundStyle(.secondary)
                }

                Section("GitHub – Actions") {
                    Button {
                        store.send(.saveGitHubConnectionTapped)
                    } label: {
                        HStack {
                            if store.github.isOperationInProgress {
                                ProgressView()
                            } else {
                                Label(store.github.saveButtonTitle, systemImage: "link.badge.plus")
                            }
                        }
                    }
                    .disabled(store.github.isSaveDisabled)

                    Button(role: .destructive) {
                        store.send(.clearGitHubConnectionTapped)
                    } label: {
                        Label("Remove Connection", systemImage: "trash")
                    }
                    .disabled(store.github.removeButtonDisabled)
                }

                Section("GitHub – Info") {
                    Text(store.github.infoText)
                        .foregroundStyle(.secondary)
                }

                if !store.github.statusMessage.isEmpty {
                    Section("GitHub – Status") {
                        Text(store.github.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("GitLab – Profile") {
                    Text(store.gitlab.profileSummaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let validationMessage = store.gitlab.saveValidationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("GitLab – Access Token") {
                    SecureField("Personal access token", text: gitLabAccessTokenBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text(store.gitlab.tokenStatusText)
                        .foregroundStyle(.secondary)
                }

                Section("GitLab – Actions") {
                    Button {
                        store.send(.saveGitLabConnectionTapped)
                    } label: {
                        HStack {
                            if store.gitlab.isOperationInProgress {
                                ProgressView()
                            } else {
                                Label(store.gitlab.saveButtonTitle, systemImage: "link.badge.plus")
                            }
                        }
                    }
                    .disabled(store.gitlab.isSaveDisabled)

                    Button(role: .destructive) {
                        store.send(.clearGitLabConnectionTapped)
                    } label: {
                        Label("Remove Connection", systemImage: "trash")
                    }
                    .disabled(store.gitlab.removeButtonDisabled)
                }

                Section("GitLab – Info") {
                    Text(store.gitlab.infoText)
                        .foregroundStyle(.secondary)
                }

                if !store.gitlab.statusMessage.isEmpty {
                    Section("GitLab – Status") {
                        Text(store.gitlab.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Git")
            .navigationBarTitleDisplayMode(.inline)
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
