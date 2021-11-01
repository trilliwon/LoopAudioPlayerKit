import AVFoundation
import os.log

// MARK: - Notification Names

public extension Notification.Name {
    static let currentSoundChanged: NSNotification.Name = NSNotification.Name(rawValue: "currentSoundChanged")
    static let soundPlayerStateChanged: NSNotification.Name = NSNotification.Name(rawValue: "soundPlayerStateChanged")
}

// MARK: protocols

public protocol SoundPlayable: AnyObject {
    var volume: Float { get set }
    var isPlaying: Bool { get }
    
    func playNow()
    func stop()
}

public protocol VolumeProvidable {
    func volume(for sound: Sound) -> Float
}

// MARK: - SoundPlayer

@available(iOS 12.0, *)
public class SoundPlayer: NSObject {
    
    public var isPlaying: Bool {
        soundPlayer?.isPlaying ?? false
    }
    
    public var volume: Float {
        set { soundPlayer?.volume = newValue }
        get { soundPlayer?.volume ?? 0 }
    }
    
    public var sound: Sound {
        didSet {
            guard oldValue.title != self.sound.title else { return }
            oldValue.isPlaying = false
            notificationCenter.post(name: .currentSoundChanged, object: self.sound)
        }
    }
    
    public func changeSound<S: Sound>(_ sound: S) {
        let isPlaying = self.isPlaying
        self.sound = sound
        isPlaying ? play() : ()
    }
    
    public func play() {
        play(sound: sound)
    }
    
    public func play(sound: Sound) {
        if isPlaying {
            soundPlayer?.stop()
            soundPlayer = nil
        }
        self.sound.isPlaying = false
        self.sound = sound
        sound.isPlaying = true
        
        soundPlayQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                self.soundPlayer?.playNow()
                self.notificationCenter.post(name: .soundPlayerStateChanged, object: self.isPlaying)
            }
            
            guard let soundURL = sound.fileURL else {
                self.soundPlayer = self.defaultLoopPlayer(soundName: "Mute")
                Logger.debug.error("Sound.fileURL does not exist")
                return
            }
            
            do {
                self.soundPlayer = try LoopAudioPlayer(contentsOf: soundURL)
            } catch let error as LoopAudioPlayer.LoopAudioPlayerError {
                self.soundPlayer = self.defaultLoopPlayer(soundName: sound.title)
                Logger.debug.error("LoopAudioPlayer.LoopAudioPlayerError: \(error.localizedDescription)")
            } catch {
                Logger.debug.error("Error creating SoundPlayer \(error.localizedDescription)")
                return
            }
            
            self.volume = self.volumeProvider.volume(for: sound)
        }
    }
    
    public func stop() {
        soundPlayer?.stop()
        self.sound.isPlaying = false
        notificationCenter.post(name: .soundPlayerStateChanged, object: isPlaying)
    }
    
    // MARK: - initializer

    public let notificationCenter: NotificationCenter

    public init(sound: Sound, notificationCenter: NotificationCenter = .default, volumeProvider: VolumeProvidable) {
        self.notificationCenter = notificationCenter
        self.sound = sound
        self.volumeProvider = volumeProvider
        super.init()

#if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.debug.error("Error setting audio session, \(error.localizedDescription)")
        }
#elseif os(watchOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(
                AVAudioSession.Category.playback,
                mode: .default,
                policy: .longFormAudio,
                options: []
            )
        } catch {
            Logger.debug.error("Error setting audio session, \(error.localizedDescription)")
        }

        AVAudioSession.sharedInstance().activate(options: []) { (success, error) in
            // Check for an error and play audio.
            if let error = error {
                Logger.debug.error("Error setting audio session, \(error.localizedDescription)")
            }
        }

#else

        Logger.debug.error("Not supporting OS")

#endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    // MARK: private
    
    private var soundPlayer: SoundPlayable?
    private var volumeProvider: VolumeProvidable
    private var shouldResumeAfterInterruption: Bool = false
    private let soundPlayQueue = DispatchQueue(label: "Playing Sound")
    
    @objc
    private func handleInterruption(_ notification: Notification) {
        soundPlayQueue.sync { [unowned self] in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                      return
                  }
            if type == .began {
                self.shouldResumeAfterInterruption = self.sound.isPlaying
            } else if type == .ended {
                guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                    return
                }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Interruption Ended - playback should resume
                    if self.shouldResumeAfterInterruption {
                        self.play(sound: self.sound)
                    }
                }
            }
        }
    }
}

@available(iOS 12.0, *)
public extension SoundPlayer {
    
    func defaultLoopPlayer(soundName: String, volume: Float = .zero) -> SoundPlayable? {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            fatalError("⚠️ : Mute.mp3 does not exist")
        }
        
        do {
            let soundPlayer = try AVAudioPlayer(contentsOf: url)
            soundPlayer.numberOfLoops = -1
            soundPlayer.volume = volume
            return soundPlayer
        } catch {
            Logger.debug.error("\(error.localizedDescription)")
            return nil
        }
    }
}

extension AVAudioPlayer: SoundPlayable {
    public func playNow() {
        Logger.debug.error("\(#function)")
#if os(watchOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                policy: .longFormAudio,
                options: [.mixWithOthers]
            )
        } catch {
            Logger.debug.error("Error setting audio session, \(error.localizedDescription)")
        }
        AVAudioSession.sharedInstance().activate(options: []) { [weak self] (success, error) in
            // Check for an error and play audio.
            if let error = error {
                Logger.debug.error("Error setting audio session, \(error.localizedDescription)")
            } else {
                self?.play()
            }
        }
#else
        play()
#endif
    }
}

extension Logger {
    static let debug = Logger(subsystem: "LoopAudioPlayerKit", category: "debug")
}
