import AVFoundation
import SwiftUI

struct TaskVoiceNoteRecorderControl: View {
    let voiceNote: RoutineVoiceNote?
    let onVoiceNoteChanged: (RoutineVoiceNote?) -> Void

    @StateObject private var recorder = TaskVoiceNoteRecorder()
    @StateObject private var player = TaskVoiceNotePlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            currentStateRow

            HStack(spacing: 10) {
                if recorder.isRecording {
                    Button {
                        stopRecording()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button {
                        recorder.cancelRecording()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        player.stop()
                        Task { await recorder.startRecording() }
                    } label: {
                        Label(recordButtonTitle, systemImage: "mic.fill")
                    }
                    .buttonStyle(.bordered)
                }

                if voiceNote != nil, !recorder.isRecording {
                    Button(role: .destructive) {
                        player.stop()
                        onVoiceNoteChanged(nil)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let message = recorder.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(recorder.hasError ? Color.red : Color.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .onDisappear {
            recorder.cancelRecording()
            player.stop()
        }
    }

    @ViewBuilder
    private var currentStateRow: some View {
        if recorder.isRecording {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recording")
                        .font(.subheadline.weight(.semibold))
                    Text(TaskVoiceNoteDurationFormatter.text(for: recorder.elapsedSeconds))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else if let voiceNote {
            TaskVoiceNotePlaybackControl(voiceNote: voiceNote, title: "Voice note", player: player)
        } else {
            Label("No voice note recorded", systemImage: "mic")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var recordButtonTitle: String {
        voiceNote == nil ? "Record" : "Replace"
    }

    private func stopRecording() {
        guard let note = recorder.stopRecording() else { return }
        onVoiceNoteChanged(note)
    }
}

struct TaskVoiceNotePlaybackControl: View {
    let voiceNote: RoutineVoiceNote
    var title: String = "Voice note"

    @StateObject private var ownedPlayer: TaskVoiceNotePlayer
    private let externalPlayer: TaskVoiceNotePlayer?

    init(
        voiceNote: RoutineVoiceNote,
        title: String = "Voice note",
        player: TaskVoiceNotePlayer? = nil
    ) {
        self.voiceNote = voiceNote
        self.title = title
        self.externalPlayer = player
        _ownedPlayer = StateObject(wrappedValue: player ?? TaskVoiceNotePlayer())
    }

    var body: some View {
        let player = externalPlayer ?? ownedPlayer
        HStack(spacing: 10) {
            Image(systemName: player.isPlaying ? "waveform" : "waveform.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(TaskVoiceNoteDurationFormatter.text(for: voiceNote.durationSeconds))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: player.progress(for: voiceNote))
                    .progressViewStyle(.linear)
            }

            Spacer(minLength: 8)

            Button {
                player.togglePlayback(for: voiceNote)
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.bordered)
            .help(player.isPlaying ? "Pause voice note" : "Play voice note")
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onDisappear {
            if externalPlayer == nil {
                ownedPlayer.stop()
            }
        }
    }
}

@MainActor
final class TaskVoiceNoteRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsedSeconds: Double = 0
    @Published private(set) var message: String?
    @Published private(set) var hasError = false

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startedAt: Date?

    func startRecording() async {
        guard !isRecording else { return }
        hasError = false
        message = nil

        guard await requestMicrophoneAccess() else {
            hasError = true
            message = "Microphone access is needed to record a voice note."
            return
        }

        do {
            try configureAudioSessionForRecording()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("routina-voice-note-\(UUID().uuidString)")
                .appendingPathExtension(RoutineVoiceNote.fileExtension)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else {
                throw TaskVoiceNoteRecorderError.couldNotStart
            }

            self.recorder = recorder
            startedAt = Date()
            elapsedSeconds = 0
            isRecording = true
            startTimer()
        } catch {
            cleanupTemporaryRecording()
            hasError = true
            message = "Could not start recording."
        }
    }

    func stopRecording() -> RoutineVoiceNote? {
        guard isRecording, let recorder else { return nil }
        let duration = max(recorder.currentTime, elapsedSeconds)
        let url = recorder.url
        recorder.stop()
        stopTimer()
        isRecording = false

        do {
            let data = try Data(contentsOf: url)
            try? FileManager.default.removeItem(at: url)
            guard !data.isEmpty else {
                hasError = true
                message = "The recording was empty."
                return nil
            }
            let voiceNote = RoutineVoiceNote(
                data: data,
                durationSeconds: duration,
                createdAt: Date()
            )
            hasError = false
            message = nil
            self.recorder = nil
            return voiceNote
        } catch {
            hasError = true
            message = "Could not save the recording."
            self.recorder = nil
            return nil
        }
    }

    func cancelRecording() {
        guard recorder != nil || isRecording else { return }
        cleanupTemporaryRecording()
        hasError = false
        message = nil
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func configureAudioSessionForRecording() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        #endif
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsedSeconds = Date().timeIntervalSince(startedAt)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        startedAt = nil
    }

    private func cleanupTemporaryRecording() {
        recorder?.stop()
        if let url = recorder?.url {
            try? FileManager.default.removeItem(at: url)
        }
        recorder = nil
        isRecording = false
        elapsedSeconds = 0
        stopTimer()
    }
}

@MainActor
final class TaskVoiceNotePlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func togglePlayback(for voiceNote: RoutineVoiceNote) {
        if isPlaying {
            pause()
        } else {
            play(voiceNote)
        }
    }

    func play(_ voiceNote: RoutineVoiceNote) {
        do {
            try configureAudioSessionForPlayback()
            let player = try AVAudioPlayer(data: voiceNote.data)
            player.prepareToPlay()
            self.player = player
            duration = voiceNote.durationSeconds ?? player.duration
            currentTime = 0
            player.play()
            isPlaying = true
            startTimer()
        } catch {
            stop()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
    }

    func progress(for voiceNote: RoutineVoiceNote) -> Double {
        let resolvedDuration = duration > 0 ? duration : (voiceNote.durationSeconds ?? 0)
        guard resolvedDuration > 0 else { return 0 }
        return min(max(currentTime / resolvedDuration, 0), 1)
    }

    private func configureAudioSessionForPlayback() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        #endif
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                self.duration = player.duration
                if !player.isPlaying {
                    self.stop()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

enum TaskVoiceNoteDurationFormatter {
    static func text(for seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds > 0 else { return "0:00" }
        let totalSeconds = max(Int(seconds.rounded()), 0)
        let minutes = totalSeconds / 60
        let secondsRemainder = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", secondsRemainder))"
    }
}

private enum TaskVoiceNoteRecorderError: Error {
    case couldNotStart
}
