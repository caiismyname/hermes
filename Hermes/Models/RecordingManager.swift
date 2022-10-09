//
//  RecordingManager.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import AVFoundation
import SwiftUI
import Foundation

class RecordingManager: NSObject, AVCaptureFileOutputRecordingDelegate, ObservableObject {
    
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    private let sessionQueue = DispatchQueue(label: "com.caiismyname.SessionQ")
    var session: AVCaptureSession?
    var project: Project
    @Published var isRecording = false
    var recordingStartTime = Date() // temp value to start
    @Published var recordingDuration = TimeInterval(0)
    var timer = Timer()
    
    init(project: Project) {
        self.project = project
    }
    
    func configureCaptureSession(session: AVCaptureSession) {
        self.session = session
        self.movieFileOutput = AVCaptureMovieFileOutput()
        
        guard self.session != nil else {
            return
        }
        
        if self.session!.canAddOutput(movieFileOutput!) {
            self.session!.beginConfiguration()
            self.session!.addOutput(movieFileOutput!)
            self.session!.sessionPreset = .high
        }
        
        if let connection = movieFileOutput?.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }
        
        self.session!.commitConfiguration()
    }
    
    func toggleRecording() {
        // Not sure what this is guarding against
        guard let movieFileOutput = self.movieFileOutput else {
            return
        }
        
        self.isRecording = true
        sessionQueue.async {
            if !movieFileOutput.isRecording {
                let movieFileOutputConnection = movieFileOutput.connection(with: .video)
                // TODO match orientations
                
                if movieFileOutput.availableVideoCodecTypes.contains(.hevc) {
                    movieFileOutput.setOutputSettings(
                        [AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection!)
                }
                
                if let clip = self.project.startClip() {
                    movieFileOutput.startRecording(to: clip.temporaryURL!, recordingDelegate: self)
                    print("Start recording")
                }
            } else {
                movieFileOutput.stopRecording()
                print("Stop recording")
            }
        }
    }
    
    func startTimer() {
        self.recordingDuration = TimeInterval(0)
        self.recordingStartTime = Date()
        self.timer = Timer.scheduledTimer(
            timeInterval: TimeInterval(0.01),
            target: self,
            selector: (#selector(updateDuration)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
    }
    
    @objc func updateDuration() {
        let now = Date()
        recordingDuration = now.timeIntervalSince(recordingStartTime)
    }
    
    /// - Tag: DidStartRecording
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Enable the Record button to let the user stop recording.
        self.startTimer()
        
        DispatchQueue.main.async {
            // TODO set proper control status here
        }
    }
    
    /// - Tag: DidFinishRecording
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        self.project.endClip()
        self.isRecording = false
        self.timer.invalidate()
        self.recordingDuration = TimeInterval(0)
    }
}
