import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// A background music player that plays audio with a looping section.
/// Uses AVAudioEngine for sample-accurate, seamless looping.
/// The player starts from the beginning, loops a specified section until
/// `finishPlaying()` is called, then continues to the end of the track.
@MainActor
@Observable
public final class BGMPlayer {

    /// Configuration for the loop section
    public struct LoopSection: Sendable {
        /// Start time of the loop in seconds
        public let start: TimeInterval
        /// End time of the loop in seconds
        public let end: TimeInterval

        public init(start: TimeInterval, end: TimeInterval) {
            self.start = start
            self.end = end
        }
    }

    /// Predefined BGM tracks
    public enum Track: Sendable {
        case konohaNoHiru
        case golfGameResults

        /// The filename of the track (without extension)
        public var filename: String {
            switch self {
            case .konohaNoHiru: return "木ノ葉の昼"
            case .golfGameResults: return "29 Golf (Game Results)"
            }
        }

        /// The file extension
        public var fileExtension: String {
            switch self {
            case .konohaNoHiru: return "m4a"
            case .golfGameResults: return "flac"
            }
        }

        /// The loop section for this track
        public var loopSection: LoopSection {
            switch self {
            case .konohaNoHiru:
                return LoopSection(start: 17.4410, end: 75.186030)
            case .golfGameResults:
                return LoopSection(start: 22.011780, end: 124.864908)
            }
        }
    }

    /// Errors that can occur during BGM playback
    public enum BGMError: Error, LocalizedError {
        case fileNotFound(String)
        case failedToLoadAudio(String)
        case failedToCreateBuffer

        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let filename):
                return "BGM file not found: \(filename)"
            case .failedToLoadAudio(let reason):
                return "Failed to load audio: \(reason)"
            case .failedToCreateBuffer:
                return "Failed to create audio buffer"
            }
        }
    }

    /// Current playback state
    public enum State: Sendable {
        case stopped
        case playing
        case looping
        case finishing
    }

    // MARK: - Public Properties

    /// Current playback state
    public private(set) var state: State = .stopped

    // MARK: - Private Properties

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var loopBuffer: AVAudioPCMBuffer?
    private var outroBuffer: AVAudioPCMBuffer?
    private var loopSection: LoopSection?
    private var volume: Float = 1.0

    // Time tracking for position save/restore
    private var playbackStartTime: Date?
    private var savedElapsedTime: TimeInterval = 0  // Total elapsed time when paused

    // Fade task tracking
    private var fadeTask: Task<Void, Never>?

    // MARK: - Initialization

    public init() {
        setupAudioSession()
    }

    // MARK: - Public Methods

    /// Plays a predefined BGM track with its configured loop section.
    /// - Parameter track: The track to play
    /// - Parameter bundle: The bundle containing the audio file (defaults to main bundle)
    public func play(track: Track, bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: track.filename, withExtension: track.fileExtension) else {
            throw BGMError.fileNotFound(track.filename)
        }
        try play(url: url, loopSection: track.loopSection)
    }

    /// Plays audio from the specified URL with an optional loop section.
    /// - Parameters:
    ///   - url: The URL of the audio file to play
    ///   - loopSection: The section to loop until `finishPlaying()` is called.
    ///                  If nil, the audio plays straight through without looping.
    public func play(url: URL, loopSection: LoopSection? = nil) throws {
        stop()

        // Load audio file
        let file = try AVAudioFile(forReading: url)
        self.audioFile = file
        self.loopSection = loopSection

        // Setup engine
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)

        self.engine = engine
        self.playerNode = player

        try engine.start()
        player.volume = volume

        if let loopSection = loopSection {
            let sampleRate = file.processingFormat.sampleRate
            let loopStartFrame = AVAudioFramePosition(loopSection.start * sampleRate)
            let loopEndFrame = AVAudioFramePosition(loopSection.end * sampleRate)

            // Schedule intro (from start to loop start) using scheduleSegment
            if loopStartFrame > 0 {
                player.scheduleSegment(file, startingFrame: 0, frameCount: AVAudioFrameCount(loopStartFrame), at: nil)
            }

            // Create loop buffer for seamless looping
            let loopFrameCount = AVAudioFrameCount(loopEndFrame - loopStartFrame)
            guard let loopBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: loopFrameCount) else {
                throw BGMError.failedToCreateBuffer
            }
            file.framePosition = loopStartFrame
            try file.read(into: loopBuffer, frameCount: loopFrameCount)
            self.loopBuffer = loopBuffer

            // Schedule loop buffer with looping option (plays after intro)
            player.scheduleBuffer(loopBuffer, at: nil, options: .loops)

            // Pre-create outro buffer for when finishPlaying() is called
            let outroFrameCount = AVAudioFrameCount(file.length - loopEndFrame)
            if outroFrameCount > 0 {
                guard let outroBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: outroFrameCount) else {
                    throw BGMError.failedToCreateBuffer
                }
                file.framePosition = loopEndFrame
                try file.read(into: outroBuffer, frameCount: outroFrameCount)
                self.outroBuffer = outroBuffer
            }

            state = .playing
        } else {
            // No loop section - just play the whole file
            player.scheduleFile(file, at: nil)
            state = .playing
        }

        player.play()
        playbackStartTime = Date()

        // Monitor for state changes
        startStateMonitoring()
    }

    /// Signals the player to exit the loop and play to the end of the track.
    /// Has no effect if not currently looping.
    public func finishPlaying() {
        guard let player = playerNode,
              loopSection != nil,
              state == .playing || state == .looping else { return }

        state = .finishing

        // Stop looping and schedule outro
        player.stop()

        if let outroBuffer = outroBuffer {
            player.scheduleBuffer(outroBuffer, at: nil) { [weak self] in
                Task { @MainActor in
                    self?.state = .stopped
                }
            }
            player.play()
        } else {
            state = .stopped
        }
    }

    /// Stops playback immediately.
    public func stop() {
        stopStateMonitoring()
        playerNode?.stop()
        engine?.stop()

        playerNode = nil
        engine = nil
        audioFile = nil
        loopBuffer = nil
        outroBuffer = nil
        loopSection = nil
        state = .stopped
        savedElapsedTime = 0
        playbackStartTime = nil
    }

    /// Pauses playback.
    public func pause() {
        stopStateMonitoring()

        // Save elapsed time
        if let startTime = playbackStartTime {
            savedElapsedTime = Date().timeIntervalSince(startTime)
            print("BGM pause: savedElapsedTime=\(savedElapsedTime)s")
        }

        playerNode?.pause()
        engine?.pause()
    }

    /// Resumes playback after pausing.
    public func resume() {
        guard let engine = engine,
              let player = playerNode,
              let file = audioFile,
              let loopSection = loopSection,
              let loopBuffer = loopBuffer else {
            playerNode?.play()
            return
        }

        do {
            if !engine.isRunning {
                try engine.start()
            }
            player.stop()
            player.volume = volume

            let sampleRate = file.processingFormat.sampleRate
            let loopStart = loopSection.start
            let loopEnd = loopSection.end
            let loopDuration = loopEnd - loopStart

            // Calculate current position based on saved elapsed time
            let elapsed = savedElapsedTime

            if elapsed < loopStart {
                // In intro: schedule from current position to loop start, then loop
                let currentFrame = AVAudioFramePosition(elapsed * sampleRate)
                let loopStartFrame = AVAudioFramePosition(loopStart * sampleRate)
                let remainingIntroFrames = AVAudioFrameCount(loopStartFrame - currentFrame)

                if remainingIntroFrames > 0 {
                    player.scheduleSegment(file, startingFrame: currentFrame, frameCount: remainingIntroFrames, at: nil)
                }
                player.scheduleBuffer(loopBuffer, at: nil, options: .loops)
                print("BGM resume: from intro at \(elapsed)s")

            } else if elapsed < loopEnd {
                // In loop: calculate position within loop, schedule remainder then loop
                let timeInLoop = (elapsed - loopStart).truncatingRemainder(dividingBy: loopDuration)
                let savedFrame = Int(timeInLoop * sampleRate)
                let loopFrameCount = Int(loopBuffer.frameLength)
                let remainingFrames = loopFrameCount - savedFrame

                if savedFrame > 0 && remainingFrames > 0,
                   let remainderBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(remainingFrames)) {
                    copyBuffer(from: loopBuffer, to: remainderBuffer, sourceOffset: AVAudioFrameCount(savedFrame), frameCount: AVAudioFrameCount(remainingFrames))
                    if remainderBuffer.frameLength > 0 {
                        player.scheduleBuffer(remainderBuffer, at: nil, options: [])
                    }
                }
                player.scheduleBuffer(loopBuffer, at: nil, options: .loops)
                print("BGM resume: from loop at \(timeInLoop)s into loop")

            } else {
                // In outro: schedule from current position to end
                let currentFrame = AVAudioFramePosition(loopEnd * sampleRate) + AVAudioFramePosition((elapsed - loopEnd) * sampleRate)
                let remainingFrames = AVAudioFrameCount(file.length - currentFrame)

                if remainingFrames > 0 {
                    player.scheduleSegment(file, startingFrame: currentFrame, frameCount: remainingFrames, at: nil)
                }
                print("BGM resume: from outro at \(elapsed - loopEnd)s into outro")
            }

            player.play()
            playbackStartTime = Date().addingTimeInterval(-savedElapsedTime)
            startStateMonitoring()
        } catch {
            print("BGM resume failed: \(error)")
        }
    }

    /// Copies audio data from one buffer to another
    private func copyBuffer(from source: AVAudioPCMBuffer, to destination: AVAudioPCMBuffer, sourceOffset: AVAudioFrameCount, frameCount: AVAudioFrameCount) {
        let channelCount = Int(source.format.channelCount)

        // Try float format first
        if let srcData = source.floatChannelData,
           let dstData = destination.floatChannelData {
            for channel in 0..<channelCount {
                memcpy(dstData[channel],
                       srcData[channel].advanced(by: Int(sourceOffset)),
                       Int(frameCount) * MemoryLayout<Float>.size)
            }
            destination.frameLength = frameCount
            print("BGM copyBuffer: copied \(frameCount) float frames from offset \(sourceOffset)")
            return
        }

        // Try int16 format
        if let srcData = source.int16ChannelData,
           let dstData = destination.int16ChannelData {
            for channel in 0..<channelCount {
                memcpy(dstData[channel],
                       srcData[channel].advanced(by: Int(sourceOffset)),
                       Int(frameCount) * MemoryLayout<Int16>.size)
            }
            destination.frameLength = frameCount
            print("BGM copyBuffer: copied \(frameCount) int16 frames from offset \(sourceOffset)")
            return
        }

        // Try int32 format
        if let srcData = source.int32ChannelData,
           let dstData = destination.int32ChannelData {
            for channel in 0..<channelCount {
                memcpy(dstData[channel],
                       srcData[channel].advanced(by: Int(sourceOffset)),
                       Int(frameCount) * MemoryLayout<Int32>.size)
            }
            destination.frameLength = frameCount
            print("BGM copyBuffer: copied \(frameCount) int32 frames from offset \(sourceOffset)")
            return
        }

        print("BGM copyBuffer: FAILED - unsupported format. float=\(source.floatChannelData != nil), int16=\(source.int16ChannelData != nil), int32=\(source.int32ChannelData != nil)")
    }

    /// Sets the playback volume (0.0 to 1.0).
    public func setVolume(_ volume: Float) {
        self.volume = max(0, min(1, volume))
        playerNode?.volume = self.volume
    }

    /// Fades out the audio over the specified duration, then pauses.
    /// - Parameter duration: Fade duration in seconds (default 0.5)
    public func fadeOutAndPause(duration: TimeInterval = 0.5) {
        guard let player = playerNode, state != .stopped else { return }

        // Cancel any existing fade task
        fadeTask?.cancel()

        let startVolume = player.volume
        let steps = 20
        let stepDuration = duration / Double(steps)

        fadeTask = Task { @MainActor in
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(Int(stepDuration * 1000)))
                guard !Task.isCancelled else { return }
                let progress = Float(step) / Float(steps)
                player.volume = startVolume * (1 - progress)
            }
            guard !Task.isCancelled else { return }
            self.pause()
        }
    }

    /// Fades in the audio over the specified duration after resuming.
    /// - Parameter duration: Fade duration in seconds (default 0.3)
    public func resumeWithFadeIn(duration: TimeInterval = 0.3) {
        guard state != .stopped else { return }

        // Cancel any pending fade-out task
        fadeTask?.cancel()
        fadeTask = nil

        playerNode?.volume = 0
        resume()

        let targetVolume = volume
        let steps = 15
        let stepDuration = duration / Double(steps)

        Task { @MainActor in
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(Int(stepDuration * 1000)))
                let progress = Float(step) / Float(steps)
                self.playerNode?.volume = targetVolume * progress
            }
        }
    }

    // MARK: - Private Methods

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #endif
    }

    // MARK: - State Monitoring

    #if canImport(UIKit)
    private var displayLink: CADisplayLink?
    #else
    private var timer: Timer?
    #endif

    private func startStateMonitoring() {
        stopStateMonitoring()

        #if canImport(UIKit)
        let link = CADisplayLink(target: DisplayLinkTarget { [weak self] in
            Task { @MainActor in
                self?.updateState()
            }
        }, selector: #selector(DisplayLinkTarget.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        #else
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateState()
            }
        }
        #endif
    }

    private func stopStateMonitoring() {
        #if canImport(UIKit)
        displayLink?.invalidate()
        displayLink = nil
        #else
        timer?.invalidate()
        timer = nil
        #endif
    }

    private func updateState() {
        guard let player = playerNode else { return }

        // Update state based on playback
        if loopSection != nil && state == .playing && player.isPlaying {
            state = .looping
        }

        // Check if playback stopped unexpectedly
        if state != .stopped && state != .finishing && !player.isPlaying {
            // Player stopped but we didn't expect it
            if engine?.isRunning == false {
                state = .stopped
                stopStateMonitoring()
            }
        }
    }
}

#if canImport(UIKit)
/// Helper class to avoid exposing @objc to the main actor-isolated BGMPlayer
private final class DisplayLinkTarget {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func tick() {
        action()
    }
}
#endif
