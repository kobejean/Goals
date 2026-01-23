import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// A background music player that plays audio with a looping section.
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

    /// Current playback time
    public var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }

    /// Total duration of the audio
    public var duration: TimeInterval {
        player?.duration ?? 0
    }

    // MARK: - Private Properties

    private var player: AVAudioPlayer?
    private var loopSection: LoopSection?
    private var shouldFinish = false

    #if canImport(UIKit)
    private var displayLink: CADisplayLink?
    #else
    private var timer: Timer?
    #endif

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Plays audio from the specified URL with an optional loop section.
    /// - Parameters:
    ///   - url: The URL of the audio file to play
    ///   - loopSection: The section to loop until `finishPlaying()` is called.
    ///                  If nil, the audio plays straight through without looping.
    public func play(url: URL, loopSection: LoopSection? = nil) throws {
        stop()

        player = try AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()

        self.loopSection = loopSection
        self.shouldFinish = false

        if loopSection != nil {
            startPolling()
        }

        player?.play()
        state = .playing
    }

    /// Signals the player to exit the loop and play to the end of the track.
    /// Has no effect if not currently looping.
    public func finishPlaying() {
        guard loopSection != nil else { return }
        shouldFinish = true
        state = .finishing
    }

    /// Stops playback immediately.
    public func stop() {
        stopPolling()
        player?.stop()
        player = nil
        loopSection = nil
        shouldFinish = false
        state = .stopped
    }

    /// Pauses playback.
    public func pause() {
        player?.pause()
    }

    /// Resumes playback after pausing.
    public func resume() {
        player?.play()
    }

    /// Sets the playback volume (0.0 to 1.0).
    public func setVolume(_ volume: Float) {
        player?.volume = max(0, min(1, volume))
    }

    // MARK: - Private Methods

    private func startPolling() {
        stopPolling()

        #if canImport(UIKit)
        let link = CADisplayLink(target: DisplayLinkTarget { [weak self] in
            Task { @MainActor in
                self?.checkLoopBoundary()
            }
        }, selector: #selector(DisplayLinkTarget.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        #else
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkLoopBoundary()
            }
        }
        #endif
    }

    private func stopPolling() {
        #if canImport(UIKit)
        displayLink?.invalidate()
        displayLink = nil
        #else
        timer?.invalidate()
        timer = nil
        #endif
    }

    private func checkLoopBoundary() {
        guard let player = player,
              let loopSection = loopSection else {
            return
        }

        let currentTime = player.currentTime

        // Update state when entering loop section
        if currentTime >= loopSection.start && state == .playing {
            state = .looping
        }

        // Check if we've reached the end of the loop section
        if currentTime >= loopSection.end {
            if shouldFinish {
                // Let it continue to the end
                stopPolling()
                self.loopSection = nil
            } else {
                // Loop back to the start of the loop section
                player.currentTime = loopSection.start
            }
        }

        // Check if playback finished
        if !player.isPlaying && currentTime >= player.duration - 0.1 {
            state = .stopped
            stopPolling()
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
