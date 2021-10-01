//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    var timeData:[Float]
    //time data
    var fftData:[Float]
    //fft data at the current moment
    var rightMaxAvgBaseline:[Float]
    var leftMaxAvgBaseline:[Float]
    var rightMaxAvg:[Float]
    var leftMaxAvg:[Float]
    var leftBaseline:Float;
    var rightBaseline:Float;
    var caputringBaselines:Bool;
    var maxIndex:Int;
    let windowSize = 5;
    var insertMaxIndex:Int;
    let numDetectionFrames = 5;
    let numBaselineFrames = 5;
    let percentIncrease:Float = 0.2;
    var startDetection:Bool;
    var statsLeft:[Float] = [];
    var statsRight:[Float] = [];
    var rightPercentage:Float;
    var leftPercentage:Float;
    var gesture:String;
    
    
    
    //fft data in the previous time interval
   
    
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        rightMaxAvgBaseline = Array()
        leftMaxAvgBaseline = Array()
        rightMaxAvg =  Array.init(repeating: 0.0, count: numDetectionFrames)
        leftMaxAvg =  Array.init(repeating: 0.0, count: numDetectionFrames)
        rightBaseline = 0
        leftBaseline = 0
        caputringBaselines = true
        startDetection = false
        maxIndex = 0
        insertMaxIndex = 0
        rightPercentage = 0
        leftPercentage = 0
        gesture = "neutral"
        
        
    }
    
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
        sineFrequency = withFreq
        
        maxIndex = Int((Float(sineFrequency) * Float(BUFFER_SIZE ) / Float(Novocaine.audioManager().samplingRate)).rounded());
        // Two examples are given that use either objective c or that use swift
        //   the swift code for loop is slightly slower thatn doing this in c,
        //   but the implementations are very similar
        //self.audioManager?.outputBlock = self.handleSpeakerQueryWithSinusoid // swift for loop
        self.audioManager?.setOutputBlockToPlaySineWave(sineFrequency) // c for loop
    }
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
            
        }
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    
    
    func startMicrophoneProcessing(withFps:Double){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            manager.inputBlock = self.handleMicrophone
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                                 selector: #selector(self.runEveryInterval),
                                 userInfo: nil,
                                 repeats: true)
         
        }
    }
    
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    func getAvg(arr: [Float]) -> Float{
        let sumArray = arr.reduce(0, +);
        return sumArray / Float(arr.count);
    }
    
    /* Get the max values to the left and right of the peak.
     * The range is = to window size
     */
    func getMaxes() -> (leftMax: Float,rightMax: Float) {
        //checking for index out of bounds
        let leftBottom = max(maxIndex-windowSize-2,0);
        let leftTop = max(maxIndex-2,0);
        let rightTop = min(maxIndex+windowSize+2,fftData.count-1);
        let rightBottom = min(maxIndex+2,fftData.count-1);
        

        //get max to left and right
        let leftMax = fftData[leftBottom...leftTop].max();
        let rightMax = fftData[rightBottom...rightTop].max();
        return (leftMax!, rightMax!);
    }
    
    
    func changeFrequency(frequencyIn:Float) {
        //remove all old data
        rightMaxAvgBaseline.removeAll();
        leftMaxAvgBaseline.removeAll();
        rightMaxAvg =  Array.init(repeating: 0.0, count: numDetectionFrames)
        leftMaxAvg =  Array.init(repeating: 0.0, count: numDetectionFrames)
        rightBaseline = 0
        leftBaseline = 0
        caputringBaselines = true
        startDetection = false
        insertMaxIndex = 0
        rightPercentage = 0
        leftPercentage = 0
        gesture = "neutral"
        
        //set new frequency
        sineFrequency = frequencyIn
        
        //compute new peak index
        maxIndex = Int((Float(sineFrequency) * Float(BUFFER_SIZE ) / Float(Novocaine.audioManager().samplingRate)).rounded());
        
        
    }
    
    func captureBaselines() {
        
        let maxes = getMaxes();
        
        //store max for current frame
        rightMaxAvgBaseline.append(maxes.rightMax);
        leftMaxAvgBaseline.append(maxes.leftMax);

        //if 5 frames captured stop taking baselines
        
        if(rightMaxAvgBaseline.count == numBaselineFrames && leftMaxAvgBaseline.count == numBaselineFrames){
            rightBaseline = getAvg(arr:rightMaxAvgBaseline);
            leftBaseline = getAvg(arr:leftMaxAvgBaseline);
            
            self.caputringBaselines = false
            print("Right Baseline:")
            print(rightBaseline)
            print("Left Baseline:")
            print(leftBaseline)
            leftPercentage = (fftData[maxIndex] - leftBaseline) * 0.18
            rightPercentage = (fftData[maxIndex] - rightBaseline) * 0.23
            print("Left percentage:")
            print(leftPercentage)
            print("Right percentage:")
            print(rightPercentage)
        }
        
    }
    
    func detectMotion() {
        let maxes = getMaxes();
        
        //store max from current frame
        rightMaxAvg[insertMaxIndex] = maxes.rightMax;
        leftMaxAvg[insertMaxIndex] = maxes.leftMax;
        insertMaxIndex += 1
        
        if(insertMaxIndex == 5){
            insertMaxIndex = 0
            startDetection = true
        }
        
        if(startDetection){
            //write algorithm for detection
            let rightAvg = getAvg(arr:rightMaxAvg);
            let leftAvg = getAvg(arr:leftMaxAvg);
            
//            print("Right Max Avg:")
//            print(rightAvg)
//            print("Left Max Avg:")
//            print(leftAvg)
            
            //((leftAvg/fftData[maxIndex])-(leftBaseline/fftData[maxIndex])).magnitude
            
            
//            (leftBaseline.magnitude-leftAvg.magnitude)/(leftBaseline.magnitude-fftData[maxIndex].magnitude)
//            (rightBaseline.magnitude-rightAvg.magnitude)/(rightBaseline.magnitude-fftData[maxIndex].magnitude)
            statsLeft.append(leftAvg - leftBaseline);
            statsRight.append(rightAvg - rightBaseline);
            
            if(rightAvg - rightBaseline > rightPercentage){
                print("towards")
                gesture = "towards"
            }else if(leftAvg - leftBaseline > leftPercentage){
                print("away")
                gesture = "away"
            }else{
                print("neutral")
                gesture = "neutral"
            }
            //get diff of right max avg and baseline
            //check to see how much difference when there is no movement
            //check to see how much difference when there is movement
            //hopefully there is A SIGNIFICANT difference when there is movement
            
        }
        
        

        
        
    }
    

    @objc
    private func runEveryInterval(){
        if inputBuffer != nil {
           
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
         
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            //   baseline: the fft in previous interval
            // the user can now use these variables however they like
            
            if(caputringBaselines){
                captureBaselines()
            }else{
                detectMotion()
            }
            
        }
    }
    
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    func pause() {
        if let manager = self.audioManager {
            manager.pause()
            manager.outputBlock = nil
            manager.inputBlock = nil
        }
    }
    
    //==========================================
    // MARK: Private Methods
    
    
    //==========================================
    // MARK: Model Callback Methods
   
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    
    //    _     _     _     _     _     _     _     _     _     _
    //   / \   / \   / \   / \   / \   / \   / \   / \   / \   /
    //  /   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/
    var sineFrequency:Float = 0.0 { // frequency in Hz (changeable by user)
        didSet{
            // if using swift for generating the sine wave: when changed, we need to update our increment
            //phaseIncrement = Float(2*Double.pi*sineFrequency/audioManager!.samplingRate)
            
            // if using objective c: this changes the frequency in the novocaine block
            if let manager = self.audioManager {
                manager.sineFrequency = sineFrequency
            }
        }
    }
    
    // SWIFT SINE WAVE
    // everything below here is for the swift implementation
    // this can be deleted when using the objective c implementation
    private var phase:Float = 0.0
    private var phaseIncrement:Float = 0.0
    private var sineWaveRepeatMax:Float = Float(2*Double.pi)
    
    private func handleSpeakerQueryWithSinusoid(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        // while pretty fast, this loop is still not quite as fast as
        // writing the code in c, so I placed a function in Novocaine to do it for you
        // use setOutputBlockToPlaySineWave() in Novocaine
        if let arrayData = data{
            var i = 0
            while i<numFrames{
                arrayData[i] = sin(phase)
                phase += phaseIncrement
                if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                i+=1
            }
        }
    }
}

