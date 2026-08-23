# Task Ladder metrics change independently over time

Area: Tasks / Recurrence / Task Ladder

Decision links: [0649](../decisions/0649-give-each-task-ladder-metric-an-independent-time-rule.md), [0592](../decisions/0592-derive-time-based-task-ladder-values-from-repeating-due-dates.md), [0648](../decisions/0648-keep-time-varying-task-ladder-values-read-only-in-details.md)

Current behavior: [Tasks](../current-behavior/tasks.md)

Coverage:

- `Tests/Shared/TaskRankingPresentationTests.swift`
- `Tests/Shared/TaskFormMacLayoutRegressionTests.swift`
- `Tests/Shared/TaskFormIOSLayoutRegressionTests.swift`

Given a repeating Due task is eligible for Changes over time
When the person configures Task Ladder values
Then Importance, Urgency, and Pressure each have one sentence
And each sentence states the After done value and whether it changes
And every editable choice uses a menu picker
And no shared timing control, segmented control, toggle, checkbox, or stepper is shown

Given Importance changes only on due, Urgency changes gradually before due, and Pressure changes gradually while overdue
When the task moves through those calendar states
Then each metric follows only its own policy
And Pressure remains at its After done value on the due date
And Pressure advances one categorical level after every configured full overdue interval

Given a task repeats two days after completion
When a before-due policy is configured or migrated with seven days
Then its effective lead window is capped to two days
And the new occurrence starts at its After done value

Given a task has an old shared temporal-rule payload
When the payload is read
Then each old target receives the old shared timing as an independent policy
And a later write stores only the independent policy format

Given a configured task is reviewed in Task Details
Then its Task Ladder values remain read-only
And the summary lists each metric's independent policy, After done value, and Now value
