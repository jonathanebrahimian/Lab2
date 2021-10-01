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
    @IBOutlet weak var frequencySlider: UISlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // start up the audio model here, querying microphone
        audio.startMicrophoneProcessing(withFps: 10)
        audio.startProcessingSinewaveForPlayback(withFreq: 20000)
        audio.play()
        frequencySlider.value = 20000
        
        
        
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        graph?.addGraph(withName: "fft",
                        shouldNormalize: true,
                        numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
        
        graph?.addGraph(withName: "time",
            shouldNormalize: false,
            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
        

        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
        //the above function update graphs
        //the below function detect gesture movements

       
       
    }
//
    override func viewWillDisappear(_ animated: Bool) {
        //pause the audio upon dismissing the view
        super.viewWillDisappear(animated)
        audio.pause()
        
    
    }
    
    
   
 
    @IBOutlet weak var freqLabel: UILabel!
    

    @IBOutlet weak var gestureType: UILabel!
    
    
    @IBAction func changeFrequency(_ sender: UISlider) {
        //change frequency
        self.audio.changeFrequency(frequencyIn: sender.value)
        freqLabel.text = "Frequency: \(sender.value)"
    }
    
    func updateGestureLabel(status: String){
        //update label for gesturing
        DispatchQueue.main.async { [weak self] in
            self!.gestureType.text = status
        }
    }
    

    
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "fft"
        )
        
        self.graph?.updateGraph(
            data: self.audio.timeData,
            forKey: "time"
        )
        
        DispatchQueue.main.async {
            self.gestureType.text = self.audio.gesture
        }
   
    }
    
}
