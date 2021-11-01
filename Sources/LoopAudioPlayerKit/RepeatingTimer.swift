//
//  RepeatingTimer.swift
//  Pomodoro
//
//  Created by Won on 2020/03/07.
//  Copyright © 2020 won. All rights reserved.
//

import Foundation
import os.log

final class RepeatingTimer {
    
    private let timeInterval: TimeInterval
    
    init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
    }
    
    private lazy var timer: DispatchSourceTimer = {
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)
        timer.setEventHandler(handler: { [weak self] in
            self?.eventHandler?()
        })
        return timer
    }()
    
    var eventHandler: (() -> Void)?
    
    private enum State {
        case suspended
        case resumed
    }
    
    private var state: State = .suspended
    
    deinit {
        debugPrint(#function, " called from RepeatingTimer")
        timer.setEventHandler {}
        timer.cancel()
        /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
        resume()
        eventHandler = nil
    }
    
    func resume() {
        debugPrint(#function, " called from ", self)
        if state == .resumed {
            return
        }
        state = .resumed
        timer.resume()
    }
    
    func suspend() {
        debugPrint(#function, " called from ", self)
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }
}
