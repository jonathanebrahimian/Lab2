//
//  ModuleBViewController.swift
//  Lab2
//
//  Created by Jonathan Ebrahimian on 9/24/21.
//

import UIKit
import Metal

class ModuleBViewController: UIViewController {
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*4
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.view)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        audio.play(forModule: "b")
        
        graph?.addGraph(withName: "fft",
                        shouldNormalize: true,
                        numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)

//        graph?.addGraph(withName: "time",
//            shouldNormalize: false,
//            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
        
        graph?.addGraph(withName: "peak",
            shouldNormalize: true,
            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/10)

        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)

    }
//
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audio.pause()
    }
    
    @IBOutlet weak var freqLabel: UILabel!
    

    @IBAction func changeFrequency(_ sender: UISlider) {
        self.audio.sineFrequency = sender.value
        freqLabel.text = "Frequency: \(sender.value)"
    }
    
    
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "fft"
        )
        
//        self.graph?.updateGraph(
//            data: self.audio.timeData,
//            forKey: "time"
//        )
        
        self.graph?.updateGraph(
            data: self.audio.peakData,
            forKey: "peak"
        )
        
        
        
        
        
    }
    
}
