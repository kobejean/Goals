import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// A background music player that plays audio with looping sections.
/// Supports both infinite looping (single track) and playlist mode (finite loops per track).
@MainActor
@Observable
public final class BGMPlayer {

    // MARK: - Public Types

    /// Configuration for the loop section
    public struct LoopSection: Sendable {
        public let start: TimeInterval
        public let end: TimeInterval

        public init(start: TimeInterval, end: TimeInterval) {
            self.start = start
            self.end = end
        }

        var duration: TimeInterval { end - start }
    }

    /// Predefined BGM tracks
    public enum Track: Sendable {
        case konohaNoHiru
        case tennisResults
        case bowlingResults
        case golfCourseSelect
        case golfGameResults

        public var filename: String {
            switch self {
            case .konohaNoHiru: return "木ノ葉の昼"
            case .tennisResults: return "11 Tennis (Results)"
            case .bowlingResults: return "24 Bowling (Results Screen)"
            case .golfCourseSelect: return "25 Golf (Course Select)"
            case .golfGameResults: return "29 Golf (Game Results)"
            }
        }

        public var fileExtension: String {
            switch self {
            case .konohaNoHiru: return "m4a"
            case .tennisResults: return "flac"
            case .bowlingResults: return "flac"
            case .golfCourseSelect: return "flac"
            case .golfGameResults: return "flac"
            }
        }

        public var loopSection: LoopSection {
            switch self {
            case .konohaNoHiru:
                return LoopSection(start: 17.4410, end: 75.186030)
            case .tennisResults:
                return LoopSection(start: 6.411090, end: 67.502063)
            case .bowlingResults:
                return LoopSection(start: 5.496155, end: 42.41809)
            case .golfCourseSelect:
                return LoopSection(start: 2.759060, end: 46.843000)
            case .golfGameResults:
                return LoopSection(start: 22.011780, end: 124.864908)
            }
        }
    }

    /// A playlist item specifying a track and loop count
    public struct PlaylistItem: Sendable {
        public let track: Track
        public let loopCount: Int

        public init(_ track: Track, loopCount: Int = 1) {
            self.track = track
            self.loopCount = max(1, loopCount)
        }
    }

    public enum BGMError: Error, LocalizedError {
        case fileNotFound(String)
        case failedToCreateBuffer

        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let filename): return "BGM file not found: \(filename)"
            case .failedToCreateBuffer: return "Failed to create audio buffer"
            }
        }
    }

    public enum State: Sendable {
        case stopped, playing, looping, finishing
    }

    // MARK: - Public Properties

    public private(set) var state: State = .stopped

    // MARK: - Private Types

    /// Which section of the track we're in
    private enum Section {
        case intro, loop, outro
    }

    // MARK: - Audio Engine

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var loopBuffer: AVAudioPCMBuffer?
    private var outroBuffer: AVAudioPCMBuffer?
    private var loopSection: LoopSection?
    private var volume: Float = 1.0

    // MARK: - Playback State

    private var playbackStartTime: Date?
    private var savedElapsedTime: TimeInterval = 0
    private var generation: Int = 0  // Invalidates stale completion handlers

    // MARK: - Playlist State

    private var playlist: [PlaylistItem] = []
    private var playlistIndex: Int = 0
    private var loopIteration: Int = 0
    private var targetLoops: Int = 0  // 0 = infinite
    private var bundle: Bundle = .main

    // MARK: - Fade

    private var fadeTask: Task<Void, Never>?

    // MARK: - State Monitoring

    #if canImport(UIKit)
    private var displayLink: CADisplayLink?
    #else
    private var timer: Timer?
    #endif

    // MARK: - Initialization

    public init() {
        setupAudioSession()
    }

    // MARK: - Public API

    /// Play a single track with infinite looping
    public func play(track: Track, bundle: Bundle = .main) throws {
        playlist = []
        targetLoops = 0
        try playTrack(track, bundle: bundle, loopCount: 0)
    }

    /// Play a playlist of tracks
    public func play(playlist items: [PlaylistItem], bundle: Bundle = .main) throws {
        guard !items.isEmpty else { return }
        playlist = items
        self.bundle = bundle
        playlistIndex = 0
        try playCurrentPlaylistItem()
    }

    public func stop() {
        stopStateMonitoring()
        fadeTask?.cancel()
        playerNode?.stop()
        engine?.stop()

        engine = nil
        playerNode = nil
        audioFile = nil
        loopBuffer = nil
        outroBuffer = nil
        loopSection = nil
        state = .stopped
        savedElapsedTime = 0
        playbackStartTime = nil
        playlist = []
        playlistIndex = 0
        loopIteration = 0
        targetLoops = 0
    }

    public func pause() {
        stopStateMonitoring()
        savePlaybackPosition()
        playerNode?.pause()
        engine?.pause()
    }

    public func resume() {
        guard let engine, let player = playerNode, let file = audioFile,
              let loop = loopSection, let loopBuffer else {
            playerNode?.play()
            return
        }

        do {
            if !engine.isRunning { try engine.start() }
            player.stop()
            generation += 1
            player.volume = volume

            let section = currentSection(elapsed: savedElapsedTime, loop: loop)
            scheduleFromSection(section, elapsed: savedElapsedTime, file: file, loop: loop, loopBuffer: loopBuffer, player: player)

            player.play()
            playbackStartTime = Date().addingTimeInterval(-savedElapsedTime)
            startStateMonitoring()
        } catch {
            print("BGM resume failed: \(error)")
        }
    }

    public func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        playerNode?.volume = volume
    }

    public func fadeOutAndPause(duration: TimeInterval = 0.5) {
        guard let player = playerNode, state != .stopped else { return }
        fadeTask?.cancel()

        let startVolume = player.volume
        fadeTask = Task { @MainActor in
            for i in 1...20 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(Int(duration * 50)))
                guard !Task.isCancelled else { return }
                player.volume = startVolume * (1 - Float(i) / 20)
            }
            guard !Task.isCancelled else { return }
            self.pause()
        }
    }

    public func resumeWithFadeIn(duration: TimeInterval = 0.3) {
        guard state != .stopped else { return }
        fadeTask?.cancel()
        fadeTask = nil

        playerNode?.volume = 0
        resume()

        let target = volume
        Task { @MainActor in
            for i in 1...15 {
                try? await Task.sleep(for: .milliseconds(Int(duration / 15 * 1000)))
                self.playerNode?.volume = target * Float(i) / 15
            }
        }
    }

    /// Exit loop and play outro (for single track infinite mode)
    public func finishPlaying() {
        guard let player = playerNode, loopSection != nil,
              state == .playing || state == .looping else { return }

        state = .finishing
        player.stop()

        if let outroBuffer {
            player.scheduleBuffer(outroBuffer) { [weak self] in
                Task { @MainActor in self?.state = .stopped }
            }
            player.play()
        } else {
            state = .stopped
        }
    }

    // MARK: - Private: Track Loading

    private func playCurrentPlaylistItem() throws {
        if playlistIndex >= playlist.count {
            playlistIndex = 0  // Loop playlist
        }
        let item = playlist[playlistIndex]
        try playTrack(item.track, bundle: bundle, loopCount: item.loopCount)
    }

    private func playTrack(_ track: Track, bundle: Bundle, loopCount: Int) throws {
        guard let url = bundle.url(forResource: track.filename, withExtension: track.fileExtension) else {
            throw BGMError.fileNotFound(track.filename)
        }

        stopStateMonitoring()
        playerNode?.stop()
        engine?.stop()
        generation += 1

        let file = try AVAudioFile(forReading: url)
        audioFile = file
        loopSection = track.loopSection
        targetLoops = loopCount
        loopIteration = 0

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
        self.engine = engine
        self.playerNode = player

        try engine.start()
        player.volume = volume

        try setupBuffers(file: file, loop: track.loopSection)
        scheduleIntroAndLoops(file: file, loop: track.loopSection, player: player)

        state = .playing
        player.play()
        playbackStartTime = Date()
        startStateMonitoring()
    }

    private func setupBuffers(file: AVAudioFile, loop: LoopSection) throws {
        let sampleRate = file.processingFormat.sampleRate
        let loopStartFrame = AVAudioFramePosition(loop.start * sampleRate)
        let loopEndFrame = AVAudioFramePosition(loop.end * sampleRate)
        let loopFrames = AVAudioFrameCount(loopEndFrame - loopStartFrame)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: loopFrames) else {
            throw BGMError.failedToCreateBuffer
        }
        file.framePosition = loopStartFrame
        try file.read(into: buffer, frameCount: loopFrames)
        loopBuffer = buffer

        let outroFrames = AVAudioFrameCount(file.length - loopEndFrame)
        if outroFrames > 0 {
            guard let outro = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: outroFrames) else {
                throw BGMError.failedToCreateBuffer
            }
            file.framePosition = loopEndFrame
            try file.read(into: outro, frameCount: outroFrames)
            outroBuffer = outro
        } else {
            outroBuffer = nil
        }
    }

    private func scheduleIntroAndLoops(file: AVAudioFile, loop: LoopSection, player: AVAudioPlayerNode) {
        let sampleRate = file.processingFormat.sampleRate
        let introFrames = AVAudioFrameCount(loop.start * sampleRate)

        if introFrames > 0 {
            player.scheduleSegment(file, startingFrame: 0, frameCount: introFrames, at: nil)
        }

        if targetLoops == 0 {
            // Infinite looping
            player.scheduleBuffer(loopBuffer!, at: nil, options: .loops)
        } else {
            // Finite looping with completion handlers
            scheduleLoopIteration()
        }
    }

    // MARK: - Private: Loop Scheduling

    private func scheduleLoopIteration() {
        guard let player = playerNode, let buffer = loopBuffer else { return }

        loopIteration += 1
        let gen = generation

        if loopIteration <= targetLoops {
            player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                Task { @MainActor in
                    guard let self, self.generation == gen else { return }
                    self.scheduleLoopIteration()
                }
            }
        } else {
            scheduleOutroAndAdvance(generation: gen)
        }
    }

    private func scheduleOutroAndAdvance(generation gen: Int) {
        guard let player = playerNode else { return }

        if let outro = outroBuffer {
            player.scheduleBuffer(outro, at: nil) { [weak self] in
                Task { @MainActor in
                    guard let self, self.generation == gen else { return }
                    self.advancePlaylist()
                }
            }
        } else {
            advancePlaylist()
        }
    }

    private func advancePlaylist() {
        guard !playlist.isEmpty else { return }
        playlistIndex += 1
        loopIteration = 0
        try? playCurrentPlaylistItem()
    }

    // MARK: - Private: Resume Logic

    private func currentSection(elapsed: TimeInterval, loop: LoopSection) -> Section {
        if elapsed < loop.start { return .intro }
        if targetLoops == 0 || elapsed < loop.end { return .loop }
        return .outro
    }

    private func scheduleFromSection(_ section: Section, elapsed: TimeInterval, file: AVAudioFile,
                                      loop: LoopSection, loopBuffer: AVAudioPCMBuffer, player: AVAudioPlayerNode) {
        let sampleRate = file.processingFormat.sampleRate
        let gen = generation

        switch section {
        case .intro:
            let currentFrame = AVAudioFramePosition(elapsed * sampleRate)
            let loopStartFrame = AVAudioFramePosition(loop.start * sampleRate)
            if currentFrame < loopStartFrame {
                let remaining = AVAudioFrameCount(loopStartFrame - currentFrame)
                player.scheduleSegment(file, startingFrame: currentFrame, frameCount: remaining, at: nil)
            }
            if targetLoops == 0 {
                player.scheduleBuffer(loopBuffer, at: nil, options: .loops)
            } else {
                loopIteration = 0
                scheduleLoopIteration()
            }

        case .loop:
            let timeInLoop = (elapsed - loop.start).truncatingRemainder(dividingBy: loop.duration)
            let frameOffset = Int(timeInLoop * sampleRate)
            let totalFrames = Int(loopBuffer.frameLength)
            let remaining = totalFrames - frameOffset

            // Update loop iteration from elapsed time
            if targetLoops > 0 {
                loopIteration = min(Int((elapsed - loop.start) / loop.duration) + 1, targetLoops)
            }

            if frameOffset > 0, remaining > 0,
               let remainder = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(remaining)) {
                copyBuffer(from: loopBuffer, to: remainder, offset: AVAudioFrameCount(frameOffset), count: AVAudioFrameCount(remaining))
                if remainder.frameLength > 0 {
                    if targetLoops == 0 {
                        player.scheduleBuffer(remainder, at: nil, options: [])
                        player.scheduleBuffer(loopBuffer, at: nil, options: .loops)
                    } else {
                        player.scheduleBuffer(remainder, at: nil, options: []) { [weak self] in
                            Task { @MainActor in
                                guard let self, self.generation == gen else { return }
                                self.scheduleLoopIteration()
                            }
                        }
                    }
                    return
                }
            }

            // Fallback: start fresh loop
            if targetLoops == 0 {
                player.scheduleBuffer(loopBuffer, at: nil, options: .loops)
            } else {
                scheduleLoopIteration()
            }

        case .outro:
            let outroElapsed = elapsed - loop.end
            let outroStart = AVAudioFramePosition(loop.end * sampleRate)
            let currentFrame = outroStart + AVAudioFramePosition(outroElapsed * sampleRate)

            guard currentFrame < file.length else {
                advancePlaylist()
                return
            }

            let remaining = AVAudioFrameCount(file.length - currentFrame)
            player.scheduleSegment(file, startingFrame: currentFrame, frameCount: remaining, at: nil) { [weak self] in
                Task { @MainActor in
                    guard let self, self.generation == gen else { return }
                    self.advancePlaylist()
                }
            }
        }
    }

    private func savePlaybackPosition() {
        guard let startTime = playbackStartTime else { return }
        savedElapsedTime = Date().timeIntervalSince(startTime)

        if targetLoops > 0, let loop = loopSection, savedElapsedTime >= loop.start {
            loopIteration = min(Int((savedElapsedTime - loop.start) / loop.duration) + 1, targetLoops)
        }
    }

    // MARK: - Private: Buffer Copy

    private func copyBuffer(from src: AVAudioPCMBuffer, to dst: AVAudioPCMBuffer, offset: AVAudioFrameCount, count: AVAudioFrameCount) {
        let channels = Int(src.format.channelCount)

        if let srcData = src.floatChannelData, let dstData = dst.floatChannelData {
            for ch in 0..<channels {
                memcpy(dstData[ch], srcData[ch].advanced(by: Int(offset)), Int(count) * MemoryLayout<Float>.size)
            }
            dst.frameLength = count
        } else if let srcData = src.int16ChannelData, let dstData = dst.int16ChannelData {
            for ch in 0..<channels {
                memcpy(dstData[ch], srcData[ch].advanced(by: Int(offset)), Int(count) * MemoryLayout<Int16>.size)
            }
            dst.frameLength = count
        } else if let srcData = src.int32ChannelData, let dstData = dst.int32ChannelData {
            for ch in 0..<channels {
                memcpy(dstData[ch], srcData[ch].advanced(by: Int(offset)), Int(count) * MemoryLayout<Int32>.size)
            }
            dst.frameLength = count
        }
    }

    // MARK: - Private: Audio Session

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

    // MARK: - Private: State Monitoring

    private func startStateMonitoring() {
        stopStateMonitoring()
        #if canImport(UIKit)
        let link = CADisplayLink(target: DisplayLinkTarget { [weak self] in
            Task { @MainActor in self?.updateState() }
        }, selector: #selector(DisplayLinkTarget.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        #else
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateState() }
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
        if loopSection != nil && state == .playing && player.isPlaying {
            state = .looping
        }
        if state != .stopped && state != .finishing && !player.isPlaying && engine?.isRunning == false {
            state = .stopped
            stopStateMonitoring()
        }
    }
}

#if canImport(UIKit)
private final class DisplayLinkTarget {
    private let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func tick() { action() }
}
#endif
