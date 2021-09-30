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
    var baseline:[Float]
    //fft data in the previous time interval
    
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        baseline = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
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
        //here is where we start detecting movment
        //let me explain how this work
        //first we calculate the max index by the equation
        //current freq * n(buffer size) / Fs(sampling rate)
        //take the int floor of this
        //then we take the average left and right of upto 5 elements next to the max
        //in both baseline and fftdata
        //then we find the percent left change and right change by
        //average left/right change fft - average left/right change baseline
        //we compare these changes to a threshold,
        //according to larson in class left threshold will be slightly lower than
        //right threshold due to noises and decreasing frequency 
        
        var maxIndex:Int = Int(sineFrequency) * BUFFER_SIZE / 2 / Int(Novocaine.audioManager().samplingRate);
        //calculate max index by k = Freq * n / Fs
        print("MAX INDEX")
        print(maxIndex)
        
        //these are the variables for counting the average freq at the left and right of the max index
        var leftcounter = maxIndex - 1
        var rightcounter = maxIndex + 1
        var averageLeftFFT:Float = 0
        var averageRightFFT:Float = 0
        var loopcounter = 1
        
        //the code below calculates the average of upto 5 elements left/right to the max in fft data to compare it with baseline data
        
        while(leftcounter >= 0){
            averageLeftFFT = averageLeftFFT + fftData[leftcounter]
            loopcounter += 1
            leftcounter -= 1
            if(loopcounter > 5){
                break
            }
        }
        
        averageLeftFFT = averageLeftFFT / Float(loopcounter)
        //take the average
        
        loopcounter = 1
        
        //calculate the average in the right  5 element of fft max
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
        //same logic with fft except different data
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
        var percentLeftChange: Float = averageLeftFFT - averageLeftBaseline
        
        var percentRightChange: Float = averageRightFFT - averageRightBaseline
        

     
        if(percentLeftChange < 0){
            percentLeftChange = percentLeftChange * -1
        }
        if(percentRightChange < 0){
            percentRightChange = percentRightChange * -1
        }
        
        print("percentage increase in baseline left")
        print(percentLeftChange)
        print("percentage increase in baseline right")
        print(percentRightChange)
        
        //here we define a threshold to see whether they are gestuing toward or away 
        //left threshold will be slightly lower because of noises
        if(percentLeftChange > 8 && percentRightChange < 6){
            return "Away"
        }
        else if (percentRightChange > 9 && percentLeftChange < 6){
            return "Toward"
        }
        
        return "Neutral"
        
        
        
        
    }
    
    @objc
    private func runEveryInterval(){
        if inputBuffer != nil {
            baseline = fftData
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

