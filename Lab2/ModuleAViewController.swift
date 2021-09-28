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
        static let AUDIO_BUFFER_SIZE = 8000
    }
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)

    // UI elements
    @IBOutlet weak var tone1Label: UILabel!
    @IBOutlet weak var tone2Label: UILabel!
    @IBOutlet weak var lockInButton: UIButton!

    // play
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        audio.play(forModule: "a")
    }

    // pause
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        audio.pause()
    }

    @IBAction func lockInClicked(_ sender: Any) {
    }
}
