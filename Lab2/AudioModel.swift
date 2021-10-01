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

    // first & second largest peaks
    var firstPeak: Float = -1
    var secondPeak: Float = -1

    // for updating labels within MVC paradigm
    var updateLabels: ((Float, Float) -> Void)? = nil

    // gets set when setting mic up
    var deltaFreq: Float = 0

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
            deltaFreq = Float(manager.samplingRate) / Float(BUFFER_SIZE)

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

            var peaks: [Float] = [] //  magnitudes of peak in fft
            var peakIndexes: [Int] = [] // indexes of peak in fft

            // find peaks using sliding window of size 5
            for i in 1...fftData.count - 6
            {
                // if peak is in center & > -1
                if fftData[i + 3] > 5 && fftData[i...(i + 5)].max() == fftData[i + 3]
                {
                    peaks.append(fftData[i + 3])
                    peakIndexes.append(i + 3)
                }
            }

            // calculates frequency from index, with interpolation
            func getFrequency(peakIndex: Int) -> Float
            {
                let peakFreq = deltaFreq * Float(peakIndex)
                let quadApprox = (fftData[peakIndex - 1] - fftData[peakIndex + 1]) / (fftData[peakIndex + 1] - 2 * fftData[peakIndex] + fftData[peakIndex - 1])

                return Float(peakFreq + quadApprox * deltaFreq * 0.5)
            }

            // if only 1 peak meets requirement
            if peakIndexes.count == 1 {
                firstPeak = getFrequency(peakIndex: peakIndexes[0])
                secondPeak = -1
            }
            // if we have multiple valid peaks
            else if peakIndexes.count > 1 {
                
                // for finding largest 2
                var largestA: Float = -MAXFLOAT
                var largestAIndex: Int = -1
                var largestB: Float = -MAXFLOAT
                var largestBIndex: Int = -1

                // largestA is 1st largest, largestB is 2nd largest
                for i in 0...peaks.count - 1 {
                    if peaks[i] > largestA {
                        largestB = largestA
                        largestBIndex = largestAIndex

                        largestA = peaks[i]
                        largestAIndex = i
                    } else if peaks[i] > largestB {
                        largestB = peaks[i]
                        largestBIndex = i
                    }
                }

                // set peaks
                firstPeak = getFrequency(peakIndex: peakIndexes[largestAIndex])
                secondPeak = getFrequency(peakIndex: peakIndexes[largestBIndex])
            }
            // if no peaks
            else {
                firstPeak = -1
                secondPeak = -1
            }

            updateLabels!(firstPeak, secondPeak)
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

