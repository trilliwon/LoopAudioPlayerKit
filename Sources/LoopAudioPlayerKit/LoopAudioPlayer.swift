//
//  LoopAudioPlayer.swift
//  Pomodoro
//
//  Created by Won on 2020/03/07.
//  Copyright © 2020 won. All rights reserved.
//

import AVFoundation
import os.log

@available(iOS 12.0, *)
public class LoopAudioPlayer: NSObject, SoundPlayable {
    
    public var isPlaying: Bool {
        return soundPlayerPrev.isPlaying || soundPlayerNext.isPlaying
    }
    
    enum LoopAudioPlayerError: LocalizedError {
        case durationTooShort
        
        var errorDescription: String? {
            "LoopAudioPlayer only work for audio that has longer duration than 5 sec"
        }
    }
    
    public var volume: Float = 1.0 {
        didSet {
            soundPlayerNext.volume = volume
            soundPlayerPrev.volume = volume
        }
    }
    
    private var soundPlayerPrev: AVAudioPlayer
    private var playerPrevTimer: Timer?
    
    private var soundPlayerNext: AVAudioPlayer
    private var playerNextTimer: Timer?
    
    private let fadeDuration: TimeInterval
    let duration: TimeInterval
    
    init(contentsOf url: URL, fadeDuration: TimeInterval = 5) throws {
        self.fadeDuration = fadeDuration
        soundPlayerPrev = try AVAudioPlayer(contentsOf: url)
        soundPlayerNext = try AVAudioPlayer(contentsOf: url)
        duration = soundPlayerPrev.duration
        if soundPlayerPrev.duration <= fadeDuration {
            throw LoopAudioPlayerError.durationTooShort
        }
    }
    
    public func playNow() {
        soundPlayerPrev.prepareToPlay()
        soundPlayerPrev.volume = 0.0
        soundPlayerPrev.playNow()
        soundPlayerPrev.setVolume(volume, fadeDuration: self.fadeDuration)
        
        self.addTransitionTimeObserver(audioPlayer: self.soundPlayerPrev) { [weak self] in
            guard let self = self else { return }
            self.soundPlayerNext.prepareToPlay()
            self.soundPlayerNext.volume = 0.0
            self.soundPlayerNext.playNow()
            self.soundPlayerNext.setVolume(self.volume, fadeDuration: self.fadeDuration)
            
            self.addTransitionTimeObserver(audioPlayer: self.soundPlayerNext, transitionTimeHandler: self.playNow)
        }
    }
    
    public func stop() {
        timer?.suspend()
        soundPlayerPrev.stop()
        soundPlayerNext.stop()
    }
    
    private var timer: RepeatingTimer?
    private func addTransitionTimeObserver(audioPlayer: AVAudioPlayer, transitionTimeHandler: @escaping () -> Void) {
        timer = RepeatingTimer(timeInterval: 1.0)
        timer?.eventHandler = { [weak self] in
            guard let self = self else { return }
            guard audioPlayer.duration > audioPlayer.currentTime else {
                return
            }
            guard audioPlayer.duration - audioPlayer.currentTime < self.fadeDuration else { return }
            self.timer?.suspend()
            audioPlayer.setVolume(0.0, fadeDuration: self.fadeDuration)
            transitionTimeHandler()
        }
        
        timer?.resume()
    }
}
