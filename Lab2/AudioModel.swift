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
    private var BUFFER_SIZE: Int
    var timeData: [Float]
    var fftData: [Float]

    var firstPeak: Float = -1
    {
        didSet {
            print(firstPeak)
        }
    }
    
    // data focused on peak for module b
    var peakData: [Float]

    // MARK: Public Methods
    init(buffer_size: Int) {
        BUFFER_SIZE = buffer_size

        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE / 2)
        peakData = Array.init(repeating: 0.0, count: BUFFER_SIZE / 10)
    }

    func startProcessingSinewaveForPlayback(withFreq: Float = 330.0) {
        sineFrequency = withFreq
        self.audioManager?.setOutputBlockToPlaySineWave(sineFrequency) // c for loop
    }

    func play(forModule: String) {
        if let manager = self.audioManager {
            startMicrophoneProcessing(withFps: 10)

            if forModule.lowercased() == "a"
            {
                // do things for module a

            } else if forModule.lowercased() == "b"
            {
                startProcessingSinewaveForPlayback(withFreq: 1000)
            }

            manager.play()
        }
    }

    func pause() {
        if let manager = self.audioManager {
            manager.pause()
            manager.outputBlock = nil
            manager.inputBlock = nil
        }
    }

    //==========================================
    // MARK: Private Properties
    private lazy var audioManager: Novocaine? = {
        return Novocaine.audioManager()
    }()

    func startMicrophoneProcessing(withFps: Double) {

        // setup the microphone to copy to circular buffer
        if let manager = self.audioManager {
            manager.inputBlock = self.handleMicrophone

            // repeat this fps times per second using the timer class every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(timeInterval: 1.0 / withFps, target: self,
                                 selector: #selector(self.runEveryInterval),
                                 userInfo: nil,
                                 repeats: true)
        }
    }

    private lazy var fftHelper: FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()

    private lazy var inputBuffer: CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()

    @objc
    private func runEveryInterval() {
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
            // the user can now use these variables however they like

            var peaks: [Float] = []
            var peakIndexes: [Int] = []

            for i in 0...fftData.count - 6
            {
                if fftData[i + 3] > -1 && fftData[i...(i + 5)].max() == fftData[i + 3]
                {
                    peaks.append(fftData[i + 3])
                    peakIndexes.append(i + 3)
                }
            }

            if peakIndexes.count > 0, let audioManager = audioManager {
                let peakIndex: Int = peakIndexes.max() ?? 0
                let peakHz: Double = Double(peakIndex) * (audioManager.samplingRate / Double(fftData.count))

                let change: Float = Float(audioManager.samplingRate / Double(fftData.count)) / 2
                let top: Float = fftData[peakIndex - 1] - fftData[peakIndex + 1]
                let bottom: Float = fftData[peakIndex - 1] - (2 * fftData[peakIndex]) + fftData[peakIndex + 1]

                firstPeak = Float(peakHz) + (top / bottom) * change
            } else {
                firstPeak = -1
            }

            // here we find the single peak for mod B
            let stride = vDSP_Stride(1)
            let n = vDSP_Length(fftData.count)
            var c: Float = .nan
            var i: vDSP_Length = 0
            vDSP_maxvi(fftData,
                       stride,
                           &c,
                           &i,
                       n)

//            print("max", c, "index", i)
//            c is the max element and i is the index
//            here we find the starting point of peak data
//            within fft data
//            our goal is to find the peak and equal amount of data to the left and right

//            var startarr = Int(i) - peakData.count/2
//            var endarr = Int(i) + peakData.count*2
//            var startdiff = 0
//            var enddiff = 0
//            if(startarr < 0){
//                startdiff = abs(startarr)
//                startarr = 0
//            }
//            if(endarr > peakData.count){
//                enddiff = abs(enddiff)
//                endarr = peakData.count
//            }
//            peakData = Array(fftData[startarr...endarr])

            var leftcounter = Int(i)
            var rightcounter = Int(i)
            let peakMid = peakData.count / 2
            peakData[peakMid] = c
            var peakleftcounter = peakMid - 1
            var peakrightcounter = peakMid + 1

            while(leftcounter >= 0 && peakleftcounter >= 0) {
                peakData[peakleftcounter] = fftData[leftcounter]
                leftcounter = leftcounter - 1
                peakleftcounter = peakleftcounter - 1
            }
            while(peakleftcounter >= 0 && leftcounter == 0) {
                peakData[peakleftcounter] = fftData[0]
                peakleftcounter = peakleftcounter - 1
            }

            while(rightcounter < fftData.count && peakrightcounter < peakData.count) {
                peakData[peakrightcounter] = fftData[rightcounter]
                peakrightcounter = peakrightcounter + 1
                rightcounter = rightcounter + 1
            }

            while(rightcounter >= fftData.count && peakrightcounter < peakData.count) {
                peakData[peakrightcounter] = fftData[fftData.count - 1]
                peakrightcounter = peakrightcounter + 1
            }
        }
    }

    private func handleMicrophone (data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
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
    var sineFrequency: Float = 0.0 { // frequency in Hz (changeable by user)
        didSet {
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
    private var phase: Float = 0.0
    private var phaseIncrement: Float = 0.0
    private var sineWaveRepeatMax: Float = Float(2 * Double.pi)

    private func handleSpeakerQueryWithSinusoid(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        // while pretty fast, this loop is still not quite as fast as
        // writing the code in c, so I placed a function in Novocaine to do it for you
        // use setOutputBlockToPlaySineWave() in Novocaine
        if let arrayData = data {
            var i = 0
            while i < numFrames {
                arrayData[i] = sin(phase)
                phase += phaseIncrement
                if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                i += 1
            }
        }
    }
}

