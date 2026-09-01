# CloudKit Production Schema Gate

`production-schema.manifest` is the repository's record of the SwiftData
properties that have been deployed to CloudKit **Production**.

It starts intentionally unacknowledged. The first production archive after
adding this gate must be deployed and acknowledged using the steps below.

Every iOS and macOS production archive runs
`script/cloudkit_schema_guard.sh --xcode-build`. If a persisted model field or
type has changed since the manifest was last acknowledged, the archive fails
before it can be uploaded to TestFlight.

Xcode's user-script sandbox receives the manifest as an exact input and every
Swift source under `SharedCore/Models` through
`production-schema-model-inputs.xcfilelist`. When a model source is added,
removed, or renamed, update that file list in the same change; the shared test
suite verifies that it exactly matches the directory.

When the guard fails:

1. Open CloudKit Dashboard and select `iCloud.ir.hamedgh.Routinam.prod` in the
   **Development** environment.
2. Choose **Deploy Schema Changes…**, review the diff, and deploy it to
   **Production**.
3. After the Dashboard confirms success, run:

   ```sh
   script/cloudkit_schema_guard.sh --acknowledge-production-deployment --yes-i-deployed-to-production
   ```

4. Commit the resulting manifest with the schema change and archive again.

The acknowledgement is intentionally explicit: a local build cannot securely
query CloudKit Dashboard to prove that a remote Production deployment has
completed.
