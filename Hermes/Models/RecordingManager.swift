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
    @Published var recordingButtonStyle: RecordingButtonStyle
    @Published var isRecording = false
    
    // For the duration UI
    var recordingStartTime = Date() // temp value to start
    @Published var recordingDuration = TimeInterval(0)
    var timer = Timer()
    let snapchatFullTime = TimeInterval(10.0)
    
    init(project: Project) {
        self.project = project
        self.recordingButtonStyle = UserDefaults.standard.integer(forKey: "recordingButtonStyle") == 1 ? .snapchat : .camera
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
    
    func setRecordingButtonStyle(style: RecordingButtonStyle) {
        self.recordingButtonStyle = style
        UserDefaults.standard.set(self.recordingButtonStyle == .camera ? 0 : 1, forKey: "recordingButtonStyle")
    }
    
    func toggleRecording() {
        // Not sure what this is guarding against
        guard let movieFileOutput = self.movieFileOutput else {
            return
        }
        
        self.isRecording = true
        sessionQueue.async {
            if !movieFileOutput.isRecording {
                if let movieFileOutputConnection = movieFileOutput.connection(with: .video) {
                    let orientation = AVCaptureVideoOrientation(rawValue:  UIDevice.current.orientation.rawValue)!
                    movieFileOutputConnection.videoOrientation = orientation
                    
                    if movieFileOutput.availableVideoCodecTypes.contains(.hevc) {
                        movieFileOutput.setOutputSettings(
                            [AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection)
                    }
                    
                    if let clip = self.project.startClip() {
                        movieFileOutput.startRecording(to: clip.temporaryURL!, recordingDelegate: self)
                        clip.orientation = orientation
                        print("Start recording")
                    }
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
            timeInterval: TimeInterval(0.02),
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
        if isRecording && recordingButtonStyle == .snapchat && recordingDuration > snapchatFullTime {
            toggleRecording() // stops the recording
        }
    }
    
    var snapchatStyleProgress: Double {
        return (snapchatFullTime - recordingDuration) / snapchatFullTime
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

enum RecordingButtonStyle: Codable {
    case camera // 0
    case snapchat // 1
}
