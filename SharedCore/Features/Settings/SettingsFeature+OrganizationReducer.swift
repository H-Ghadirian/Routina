import ComposableArchitecture

extension SettingsFeature {
    func reducePlaceEditingActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .automaticPlaceCheckInToggled(isEnabled):
            return SettingsPlaceActionHandler.automaticPlaceCheckInToggled(
                isEnabled,
                state: &state.places,
                appSettingsClient: appSettingsClient,
                modelContext: modelContext
            )
        case let .placesLoaded(places):
            return SettingsPlaceActionHandler.placesLoaded(
                places,
                state: &state.places
            )
        case let .locationSnapshotUpdated(snapshot):
            return SettingsPlaceActionHandler.locationSnapshotUpdated(
                snapshot,
                state: &state.places
            )
        case let .placeDraftNameChanged(name):
            return SettingsPlaceActionHandler.placeDraftNameChanged(
                name,
                state: &state.places
            )
        case let .placeDraftKindChanged(kind):
            return SettingsPlaceActionHandler.placeDraftKindChanged(
                kind,
                state: &state.places
            )
        case let .placeDraftCoordinateChanged(coordinate):
            return SettingsPlaceActionHandler.placeDraftCoordinateChanged(
                coordinate,
                state: &state.places
            )
        case let .placeDraftRadiusChanged(radius):
            return SettingsPlaceActionHandler.placeDraftRadiusChanged(
                radius,
                state: &state.places
            )
        default:
            return .none
        }
    }

    func reducePlaceMutationActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .setDeletePlaceConfirmation(isPresented):
            return SettingsPlaceActionHandler.setDeletePlaceConfirmation(
                isPresented,
                state: &state.places
            )
        case .savePlaceTapped:
            return SettingsPlaceActionHandler.savePlaceTapped(
                state: &state.places,
                modelContext: modelContext
            )
        case let .deletePlaceTapped(placeID):
            return SettingsPlaceActionHandler.deletePlaceTapped(
                placeID,
                state: &state.places
            )
        case .deletePlaceConfirmed:
            return SettingsPlaceActionHandler.deletePlaceConfirmed(
                state: &state.places,
                modelContext: modelContext
            )
        case let .placeOperationFinished(success, message):
            return SettingsPlaceActionHandler.placeOperationFinished(
                success: success,
                message: message,
                state: &state.places
            )
        default:
            return .none
        }
    }

    func reduceTagLoadingActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .tagsLoaded(tags):
            return SettingsFastFilterActionHandler.tagsLoaded(
                tags,
                state: &state.tags,
                appSettingsClient: appSettingsClient
            )
        case let .fastFilterTagsLoaded(tags):
            return SettingsFastFilterActionHandler.fastFilterTagsLoaded(
                tags,
                state: &state.tags,
                appSettingsClient: appSettingsClient
            )
        case let .tagColorsLoaded(colors):
            return SettingsTagMetadataActionHandler.tagColorsLoaded(
                colors,
                state: &state.tags
            )
        case let .relatedTagRulesLoaded(rules):
            return SettingsTagMetadataActionHandler.relatedTagRulesLoaded(
                rules,
                state: &state.tags
            )
        case let .tagRulesLoaded(rules):
            return SettingsTagMetadataActionHandler.tagRulesLoaded(
                rules,
                state: &state.tags
            )
        case let .learnedRelatedTagRulesLoaded(rules):
            return SettingsTagMetadataActionHandler.learnedRelatedTagRulesLoaded(
                rules,
                state: &state.tags
            )
        default:
            return .none
        }
    }

    func reduceTagEditingActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .setDeleteTagConfirmation(isPresented):
            return SettingsTagMutationActionHandler.setDeleteTagConfirmation(
                isPresented,
                state: &state.tags
            )
        case let .setTagRenameSheet(isPresented):
            return SettingsTagMutationActionHandler.setTagRenameSheet(
                isPresented,
                state: &state.tags
            )
        case let .setTagNormalizationConfirmation(isPresented):
            return SettingsTagMutationActionHandler.setTagNormalizationConfirmation(
                isPresented,
                state: &state.tags
            )
        case let .tagRenameDraftChanged(name):
            return SettingsTagMutationActionHandler.tagRenameDraftChanged(
                name,
                state: &state.tags
            )
        case let .tagSearchQueryChanged(query):
            return SettingsTagMetadataActionHandler.tagSearchQueryChanged(
                query,
                state: &state.tags
            )
        case let .fastFilterTagToggled(tag):
            return SettingsFastFilterActionHandler.fastFilterTagToggled(
                tag,
                state: &state.tags,
                appSettingsClient: appSettingsClient
            )
        default:
            return .none
        }
    }

    func reduceTagMetadataMutationActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .relatedTagDraftChanged(tagName, draft):
            return SettingsTagMetadataActionHandler.relatedTagDraftChanged(
                tagName: tagName,
                draft: draft,
                state: &state.tags
            )
        case let .tagColorChanged(tagName, colorHex):
            return SettingsTagMetadataActionHandler.tagColorChanged(
                tagName: tagName,
                colorHex: colorHex,
                state: &state.tags,
                appSettingsClient: appSettingsClient
            )
        case let .addTagRuleTapped(tagName, kind):
            return SettingsTagMetadataActionHandler.addTagRuleTapped(
                tagName: tagName,
                kind: kind,
                state: &state.tags,
                appSettingsClient: appSettingsClient
            )
        case let .removeTagRuleTapped(tagName, kind):
            return SettingsTagMetadataActionHandler.removeTagRuleTapped(
                tagName: tagName,
                kind: kind,
                state: &state.tags,
                appSettingsClient: appSettingsClient
            )
        case let .saveRelatedTagsTapped(tagName):
            return SettingsTagMetadataActionHandler.saveRelatedTagsTapped(
                tagName,
                state: &state.tags,
                appSettingsClient: appSettingsClient
            )
        case let .addRelatedTagDraftSubmitted(tagName, draft):
            return SettingsTagMetadataActionHandler.addRelatedTagDraftSubmitted(
                tagName: tagName,
                draft: draft,
                state: &state.tags,
                appSettingsClient: appSettingsClient
            )
        case let .appendRelatedTagSuggestionTapped(tagName, suggestion):
            return SettingsTagMetadataActionHandler.appendRelatedTagSuggestionTapped(
                tagName: tagName,
                suggestion: suggestion,
                state: &state.tags,
                appSettingsClient: appSettingsClient
            )
        case let .removeRelatedTagTapped(tagName, relatedTag):
            return SettingsTagMetadataActionHandler.removeRelatedTagTapped(
                tagName: tagName,
                relatedTag: relatedTag,
                state: &state.tags,
                appSettingsClient: appSettingsClient
            )
        default:
            return .none
        }
    }

    func reduceFlagActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .flagRulesLoaded(rules):
            SettingsFlagEditor.loadedRules(rules, state: &state.flags)
            return .none
        case let .definedFlagsLoaded(flags):
            SettingsFlagEditor.loadedDefinedFlags(flags, state: &state.flags)
            return .none
        case let .flagDraftChanged(draft):
            SettingsFlagEditor.updateDraft(draft, state: &state.flags)
            return .none
        case .addFlagTapped:
            let flags = SettingsFlagEditor.addDraft(state: &state.flags)
            appSettingsClient.setDefinedFlags(flags)
            return .none
        case let .removeFlagTapped(flagName):
            let result = SettingsFlagEditor.removeFlag(flagName, state: &state.flags)
            appSettingsClient.setDefinedFlags(result.flags)
            appSettingsClient.setFlagRules(result.rules)
            return .none
        case let .addFlagRuleTapped(flagName, kind):
            let result = SettingsFlagEditor.addRule(kind, for: flagName, state: &state.flags)
            appSettingsClient.setDefinedFlags(result.flags)
            appSettingsClient.setFlagRules(result.rules)
            return kind == .autoAssumeDone
                ? synchronizeAutoAssumeDoneFlagRules(affectedFlag: flagName)
                : .none
        case let .removeFlagRuleTapped(flagName, kind):
            let rules = SettingsFlagEditor.removeRule(kind, for: flagName, state: &state.flags)
            appSettingsClient.setFlagRules(rules)
            return kind == .autoAssumeDone
                ? synchronizeAutoAssumeDoneFlagRules(affectedFlag: flagName)
                : .none
        default:
            return .none
        }
    }

    func reduceTagPersistenceActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .renameTagTapped(tagName):
            return SettingsTagMutationActionHandler.renameTagTapped(
                tagName,
                state: &state.tags
            )
        case .saveTagRenameTapped:
            return SettingsTagMutationActionHandler.saveTagRenameTapped(
                state: &state.tags,
                appSettingsClient: appSettingsClient,
                modelContext: modelContext
            )
        case let .normalizeTagSuggestionTapped(sourceTagName, replacementTagName):
            return SettingsTagMutationActionHandler.normalizeTagSuggestionTapped(
                sourceTagName: sourceTagName,
                replacementTagName: replacementTagName,
                state: &state.tags
            )
        case .normalizeTagSuggestionConfirmed:
            return SettingsTagMutationActionHandler.normalizeTagSuggestionConfirmed(
                state: &state.tags,
                appSettingsClient: appSettingsClient,
                modelContext: modelContext
            )
        case let .deleteTagTapped(tagName):
            return SettingsTagMutationActionHandler.deleteTagTapped(
                tagName,
                state: &state.tags
            )
        case .deleteTagConfirmed:
            return SettingsTagMutationActionHandler.deleteTagConfirmed(
                state: &state.tags,
                appSettingsClient: appSettingsClient,
                modelContext: modelContext
            )
        case let .tagOperationFinished(_, message):
            return SettingsTagMutationActionHandler.tagOperationFinished(
                message: message,
                state: &state.tags
            )
        default:
            return .none
        }
    }
}
