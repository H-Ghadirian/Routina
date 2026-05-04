import Foundation

enum AddRoutineImageImportSupport {
    static func loadPickedImage(
        loadData: @escaping @Sendable () async -> Data?,
        onImagePicked: @escaping @MainActor @Sendable (Data?) -> Void
    ) {
        _ = Task {
            let data = await loadData()
            await MainActor.run {
                onImagePicked(data)
            }
        }
    }

    static func loadPickedImage(
        fromFileAt url: URL,
        onImagePicked: (Data?) -> Void
    ) {
        onImagePicked(TaskImageProcessor.compressedImageData(fromFileAt: url))
    }
}
