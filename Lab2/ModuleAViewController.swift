//
//  ModuleAViewController.swift
//  Lab2
//
//  Created by Jonathan Ebrahimian on 9/24/21.
//

import UIKit

class ModuleAViewController: UIViewController {

    // set up audio
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 8196
    }
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)

    // UI elements
    @IBOutlet weak var tone1Label: UILabel!
    @IBOutlet weak var tone2Label: UILabel!
    @IBOutlet weak var lockInButton: UIButton!

    var didLock: Bool = false
    var useLock: Bool = false

    // play
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        audio.play(forModule: "a")

        audio.updateLabels = {
            (freq1: Float, freq2: Float) -> Void in

            func setText() {
                self.tone1Label.text = freq1 < 0 ? "" : String(format: "%.2f Hz", freq1)
                self.tone2Label.text = freq2 < 0 ? "" : String(format: "%.2f Hz", freq2)
            }

            if self.useLock {
                // ensure valid frequency & haven't locked in yet
                if (freq1 > 0 || freq2 > 0) && !self.didLock
                {
                    self.didLock = true
                    setText()
                }
            }
            else
            {
                self.didLock = false
                setText()
            }
        }
    }

    // pause
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        audio.pause()
    }

    @IBAction func lockInClicked(_ sender: Any) {
        useLock.toggle()

        lockInButton.setTitle(useLock ? "Unlock" : "Lock in", for: .normal)
    }
}
