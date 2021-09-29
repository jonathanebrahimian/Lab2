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
    var fftData:[Float]
    var baseline:[Float]
    var begin:Bool
    
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        baseline = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        begin = true
    }
    
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
        sineFrequency = withFreq
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
    
    func setBaseline(){
        baseline = fftData
    }
    
    func detectMovement()-> String{
        var max:Float = -9999.99
        var maxIndex:Int = 0
        for (index, element) in fftData.enumerated(){
            if(element > max){
                max = element;
                maxIndex = index;
            }
            //we get the index and value of max in fft
        }
        
        var leftcounter = maxIndex - 1
        var rightcounter = maxIndex + 1
        var averageLeftFFT:Float = 0
        var averageRightFFT:Float = 0
        var loopcounter = 1
        
        //the code below calculates the average of upto 5 elements next to the max in fft data to compare it with baseline data
        
        while(leftcounter >= 0){
            averageLeftFFT = averageLeftFFT + fftData[leftcounter]
            loopcounter += 1
            leftcounter -= 1
            if(loopcounter > 5){
                break
            }
        }
        
        averageLeftFFT = averageLeftFFT / Float(loopcounter)
        
        loopcounter = 1
        
        while(rightcounter < fftData.count){
            averageRightFFT = averageRightFFT + fftData[rightcounter]
            loopcounter += 1
            rightcounter += 1
            if(loopcounter > 5){
                break
            }
        }
        
        averageRightFFT = averageRightFFT / Float(loopcounter)
        
        //now we calculate the left and right average in baseline
        leftcounter = maxIndex - 1
        rightcounter = maxIndex + 1
        var averageLeftBaseline:Float = 0
        var averageRightBaseline:Float = 0
        loopcounter = 1
        
        while(leftcounter >= 0){
            averageLeftBaseline += baseline[leftcounter]
            loopcounter += 1
            leftcounter -= 1
            if(loopcounter > 5){
                break
            }
        }
        
        averageLeftBaseline = averageLeftBaseline / Float(loopcounter)
        
        loopcounter = 1
        while(rightcounter < baseline.count){
            averageRightBaseline = averageRightBaseline + baseline[rightcounter]
            loopcounter += 1
            rightcounter += 1
            if(loopcounter > 5){
                break
            }
        }
        
        averageRightBaseline = averageRightBaseline / Float(loopcounter)
        
        // here we calculate the percent change in both left and right
        var percentLeftChange: Float = (averageLeftFFT - averageLeftBaseline) / averageLeftBaseline
        
        var percentRightChange: Float = (averageRightFFT - averageRightBaseline) / averageRightBaseline
        
        if(percentLeftChange > percentRightChange){
            return "Gesture Away"
        }
        else if (percentLeftChange < percentRightChange){
            return "Gesture Toward"
        }
        
        return "Neutral"
        
        
        
        
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
            if(begin){
                baseline = fftData
                begin = false
            }
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
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

