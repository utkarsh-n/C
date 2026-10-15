import AVFoundation
import CCore
import Observation

/// Audio is rendered before scheduling. No real-time callback reads SwiftUI state.
@MainActor @Observable
final class ToneEngine {
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var player: AVAudioPlayerNode?
    @ObservationIgnored private var session: AVAudioSession?
    @ObservationIgnored private var sessionActive = false
    private let sampleRate = 48_000.0
    private var playbackGeneration = 0
    private var completionTask: Task<Void, Never>?

    private(set) var isPlaying = false
    private(set) var status = "Ready · tap a key to hear it"
    private(set) var soundingName: String?

    func play(_ pitch: MusicalPitch) {
        playNotes([pitch], duration: 0.6, description: "\(pitch.displayName) · \(pitch.frequency.formatted(.number.precision(.fractionLength(2)))) Hz")
    }

    func compare(octave: Int) {
        playNotes([MusicalPitch(pitchClass: .c, octave: octave), MusicalPitch(pitchClass: .cSharp, octave: octave)],
                  duration: 0.38, description: "C\(octave), then C♯\(octave) · equal temperament")
    }

    func playScale(_ scale: MusicScale, octave: Int, cents: Double) {
        playNotes(scale.notes(octave: octave, cents: cents), duration: 0.27, description: scale.title)
    }

    func stop(reason: String = "Stopped") {
        playbackGeneration += 1
        completionTask?.cancel()
        completionTask = nil
        player?.stop()
        engine?.stop()
        isPlaying = false
        soundingName = nil
        status = reason
        if sessionActive, let session {
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
                sessionActive = false
            } catch {
                // A later stop can retry deactivation without creating audio objects.
            }
        }
    }

    func interruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
        stop(reason: "Interrupted · tap a key to resume")
    }

    func routeChanged(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
        stop(reason: "Audio device disconnected · tap to resume")
    }

    private func prepare() throws -> AVAudioPlayerNode {
        let session = self.session ?? AVAudioSession.sharedInstance()
        self.session = session
        // Respect the silent switch and mix courteously with existing audio.
        try session.setCategory(.ambient, mode: .default, options: .mixWithOthers)
        try session.setActive(true)
        sessionActive = true
        if engine == nil {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { throw ToneError.format }
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            self.engine = engine
            self.player = player
        }
        guard let engine, let player else { throw ToneError.format }
        engine.prepare()
        if !engine.isRunning { try engine.start() }
        return player
    }

    private func playNotes(_ notes: [MusicalPitch], duration: Double, description: String) {
        stop(reason: "Preparing audio")
        do {
            let player = try prepare()
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { throw ToneError.format }
            var buffers: [AVAudioPCMBuffer] = []
            for note in notes {
                let samples = MusicSignal.samples(frequency: note.frequency, sampleRate: sampleRate, duration: duration)
                guard !samples.isEmpty,
                      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
                      let channel = buffer.floatChannelData?[0] else { throw ToneError.buffer }
                buffer.frameLength = buffer.frameCapacity
                samples.withUnsafeBufferPointer { pointer in
                    if let source = pointer.baseAddress { channel.update(from: source, count: pointer.count) }
                }
                buffers.append(buffer)
            }
            guard !buffers.isEmpty else { throw ToneError.buffer }
            let generation = playbackGeneration
            for (index, buffer) in buffers.enumerated() {
                if index == buffers.count - 1 {
                    player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            guard let self, self.playbackGeneration == generation else { return }
                            self.stop(reason: "Finished · \(description)")
                        }
                    }
                } else {
                    player.scheduleBuffer(buffer)
                }
            }
            player.play()
            soundingName = description
            status = "Playing · \(description)"
            isPlaying = true
            // A bounded fallback closes a stale UI state if an audio route drops a callback.
            let maximumPlayback = duration * Double(notes.count) + 1
            completionTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(maximumPlayback))
                guard !Task.isCancelled, let self, self.playbackGeneration == generation else { return }
                self.stop(reason: "Finished · \(description)")
            }
        } catch {
            stop(reason: "Audio unavailable · \(error.localizedDescription)")
        }
    }

    private enum ToneError: LocalizedError {
        case format, buffer
        var errorDescription: String? { "Unable to prepare a short sine-wave note." }
    }
}
