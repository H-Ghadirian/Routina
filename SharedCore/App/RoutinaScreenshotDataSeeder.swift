import Foundation

extension RoutinaScreenshotDataSeeder {
    struct ScreenshotTaskFixtureContext {
        var dates: SeedDates
        var launchSectionID: UUID
        var appStoreSectionID: UUID
        var personalSectionID: UUID
        var laterSectionID: UUID
        var researchSectionID: UUID
        var releaseSubmissionID: UUID
        var verifyBackupID: UUID
        var currentWeekday: Int
    }

    static func makeTasks(
        dates: SeedDates,
        customSections: [HomeCustomTaskSection]
    ) -> [RoutineTask] {
        let context = ScreenshotTaskFixtureContext(
            dates: dates,
            launchSectionID: customSections[0].id,
            appStoreSectionID: customSections[1].id,
            personalSectionID: customSections[2].id,
            laterSectionID: customSections[3].id,
            researchSectionID: customSections[4].id,
            releaseSubmissionID: seedID(11),
            verifyBackupID: seedID(12),
            currentWeekday: dates.calendar.component(.weekday, from: dates.today)
        )
        let tasks = [
            makeMorningStretchTask(context),
            makeDeepWorkSessionTask(context),
            makeWalkOutsideTask(context),
            makeReadTwentyPagesTask(context),
            makeWeeklyReviewTask(context),
            makeGroceryRestockTask(context),
            makeScreenshotPreparationTask(context),
            makeProjectUpdateTask(context),
            makeDentistAppointmentTask(context),
            makeSoftwareRenewalTask(context),
            makeReleaseSubmissionTask(context),
            makeBackupVerificationTask(context),
            makeAutumnWeekendTask(context),
            makeStandingDeskResearchTask(context),
            makeFamilyCallTask(context),
            makeFriendMeetupTask(context),
        ]

        tasks[6].linkItems = [
            RoutineTaskLink(
                title: "App Store product-page guidance",
                url: "https://developer.apple.com/app-store/product-page/"
            )
        ]
        return tasks
    }
}
