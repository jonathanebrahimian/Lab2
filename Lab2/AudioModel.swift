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
    
    //time data
    var timeData:[Float]
   
    //fft data at the current moment
    var fftData:[Float]
    
    
    //Baseline calculations
    var rightMaxAvgBaseline:[Float]
    var leftMaxAvgBaseline:[Float]
    var peakAvg:[Float]
    var leftBaseline:Float;
    var rightBaseline:Float;
    let numBaselineFrames = 5;//num frames used to set baselines
    
    //thresholds for gesture detection
    var rightPercentage:Float;
    var leftPercentage:Float;
    
    //array (implemented as ring buffer) to store the past num number of maxes
    var rightMaxAvg:[Float]
    var leftMaxAvg:[Float]
    var insertMaxIndex:Int; //helps with ring buffer implementation
    let numDetectionFrames = 5;
    let windowSize = 6; //how many elements are we looking to the left and right
    
    //status variables
    var caputringBaselines:Bool;
    var startDetection:Bool;
    
    var maxIndex:Int;//index of max value in fft data
    
    var gesture:String;//gesture recognized
    
    //arrays to help debuging
    var statsLeft:[Float] = [];
    var statsRight:[Float] = [];
    
    
    
    
    
    
    //fft data in the previous time interval
   
    
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        
        //set all vars to step 0 values
        rightMaxAvgBaseline = Array()
        leftMaxAvgBaseline = Array()
        peakAvg = Array()
        rightMaxAvg =  Array.init(repeating: 0.0, count: numDetectionFrames)
        leftMaxAvg =  Array.init(repeating: 0.0, count: numDetectionFrames)
        rightBaseline = 0
        leftBaseline = 0
        caputringBaselines = true //start capturing baselines
        startDetection = false
        maxIndex = 0
        insertMaxIndex = 0
        rightPercentage = 0
        leftPercentage = 0
        gesture = "neutral"
        
        
    }
    
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
        sineFrequency = withFreq
        
        //get index of the peak in the fft (from equation)
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
    
    
    /* Get the average of the inputted float array.
     * This code was adapted from the stack overflow link below:
     * https://stackoverflow.com/questions/43703823/how-to-find-the-average-value-of-an-array-swift
     */
    func getAvg(arr: [Float]) -> Float{
        let sumArray = arr.reduce(0, +);
        return sumArray / Float(arr.count);
    }
    
    /* Get the max values to the left and right of the peak.
     * The range is = to window size.
     * We skiped the element dirrectly to the left and right of the peak for better results
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
    
    
    /* Params: Float
     *
     * This method updates the sine wave with the inputed float.
     * Also resets all calculation values to their base state.
     * This will make us recalculate baselines.
     */
    func changeFrequency(frequencyIn:Float) {
        //remove all old data
        rightMaxAvgBaseline.removeAll();
        leftMaxAvgBaseline.removeAll();
        peakAvg.removeAll()
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
    
    /* This method sets the baselines for the current frequency playing as well
     * as the threshold for motion detection.
     */
    func captureBaselines() {
        
        //get maxes
        let maxes = getMaxes();
        
        //store max for current frame
        rightMaxAvgBaseline.append(maxes.rightMax);
        leftMaxAvgBaseline.append(maxes.leftMax);
        
        
        //store peak
        peakAvg.append(fftData[maxIndex])

        //if numBaselineFrames captured, stop taking baselines
        
        if(rightMaxAvgBaseline.count == numBaselineFrames && leftMaxAvgBaseline.count == numBaselineFrames){
            //get average of the maxes over numBaselineFrames and store them in the respective baseline variables
            rightBaseline = getAvg(arr:rightMaxAvgBaseline);
            leftBaseline = getAvg(arr:leftMaxAvgBaseline);
            
            //get average peak over numBaselineFrames (used in threshold calculation)
            let peakBaseline = getAvg(arr: peakAvg)
            
            //stop capturing baselines (start detecting motion)
            self.caputringBaselines = false
            print("Right Baseline:")
            print(rightBaseline)
            print("Left Baseline:")
            print(leftBaseline)
            
            //set thresholds
            //from brute force testing we found good percentages for 20k
            //we then noticed that we needed to exponentioally decrease these percentages the lower the frequency
            //we decrease our "baseline percentage for 20k" by .00025 * (20000/sineFreqncy) ^ 2
            leftPercentage = (peakBaseline - leftBaseline) * (0.2003 - (0.00025 * pow((20000/sineFrequency),2)))
            rightPercentage = (peakBaseline - rightBaseline) * (0.2525 - (0.00025 * pow((20000/sineFrequency),2)))
            print("Left percentage:")
            print(leftPercentage)
            print("Right percentage:")
            print(rightPercentage)
        }
        
    }
    
    /* This method will detect motion.
     * We decided to take an average of the maxes over numDetectionFrames number of frames.
     * We wait numDetectionFrames till we have arrays full of maxes. Each time we get a new fft,
     * we overwrite the oldest max with the max from the current fft and take an average of the array.
     * we then compare our average to our baseline and if this difference exceeds the predetermined
     * threshold in a particular direction, we will update the gesture label.
     */
    func detectMotion() {
        //get maxes
        let maxes = getMaxes();
        
        //store max from current frame in insertMaxIndex location
        rightMaxAvg[insertMaxIndex] = maxes.rightMax;
        leftMaxAvg[insertMaxIndex] = maxes.leftMax;
        insertMaxIndex += 1 //go to next location
        
        //if our index has reached numDetectionFrames (it is out of bounds) reset it to 0 (this will start the overwriting process)
        if(insertMaxIndex == numDetectionFrames){
            insertMaxIndex = 0
            startDetection = true //start detection is initialzed as false so we will only start detecting once we have a full arr of maxes
        }
        
        if(startDetection){
            //detection algorithm
            
            //get the average of the maxes
            let rightAvg = getAvg(arr:rightMaxAvg);
            let leftAvg = getAvg(arr:leftMaxAvg);
            
//          used for debugging
//            statsLeft.append(leftAvg - leftBaseline);
//            statsRight.append(rightAvg - rightBaseline);
            
            //detect if the difference between our current avg and baseline exceeds threshold
            if(rightAvg - rightBaseline > rightPercentage){
                print("towards")
                gesture = "towards"
            }else if(leftAvg - leftBaseline > leftPercentage){
                print("away")
                gesture = "away"
            }else{
                gesture = "neutral"
            }
            
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
            
            //switch between capturing baselines and detecting motion
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

