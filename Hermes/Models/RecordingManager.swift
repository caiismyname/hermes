//
//  RecordingManager.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import AVFoundation
import SwiftUI
import Foundation
import CoreMotion

class RecordingManager: NSObject, AVCaptureFileOutputRecordingDelegate, ObservableObject {
    
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    private let sessionQueue = DispatchQueue(label: "com.caiismyname.SessionQ")
    var session: AVCaptureSession?
    var project: Project
    @Published var recordingButtonStyle: RecordingButtonStyle
    @Published var isRecording = false
    @Published var orientation = UIDeviceOrientation(rawValue: 1)
    private var motionManager = CMMotionManager() // For detecting orientation of the movie. Separate from DeviceOrientation so it works even when portrait lock is enabled
    
    // For the duration UI
    var recordingStartTime = Date() // temp value to start
    @Published var recordingDuration = TimeInterval(0)
    var timer = Timer()
    let snapchatFullTime = TimeInterval(10.0)
    let snapchatMaxConsecutiveClips = 1.0
    
    init(project: Project) {
        self.project = project
        self.recordingButtonStyle = UserDefaults.standard.integer(forKey: "recordingButtonStyle") == 1 ? .camera : .snapchat
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
        
        self.initCoreMotion() // For some reason I can't put this in init
    }
    
    func setRecordingButtonStyle(style: RecordingButtonStyle) {
        self.recordingButtonStyle = style
        UserDefaults.standard.set(self.recordingButtonStyle == .camera ? 1 : 0, forKey: "recordingButtonStyle")
    }
    
    private func initCoreMotion() {
        let splitAngle:Double = 0.75
        let updateTimer:TimeInterval = 0.5

        motionManager.gyroUpdateInterval = updateTimer
        motionManager.accelerometerUpdateInterval = updateTimer

        var orientationLast = UIDeviceOrientation(rawValue: 0)!

        motionManager.startAccelerometerUpdates(to: (OperationQueue.current)!, withHandler: { (acceleroMeterData, error) -> Void in
            if error == nil {

                let acceleration = (acceleroMeterData?.acceleration)!
                var orientationNew = UIDeviceOrientation(rawValue: 0)!

                if acceleration.x >= splitAngle {
                    orientationNew = .landscapeRight
                }
                else if acceleration.x <= -(splitAngle) {
                    orientationNew = .landscapeLeft
                }
                else if acceleration.y <= -(splitAngle) {
                    orientationNew = .portrait
                }
                else if acceleration.y >= splitAngle {
                    orientationNew = .portraitUpsideDown
                }

                if orientationNew != orientationLast && orientationNew != .unknown{
                    orientationLast = orientationNew
                    self.deviceOrientationChanged(orientation: orientationNew)
                }
            }
            else {
                print("CoreMotion init error: \(error!)")
            }
        })
    }
    
    func deviceOrientationChanged(orientation: UIDeviceOrientation) {
        self.orientation = orientation
    }
    
    func toggleRecording() {
        guard let movieFileOutput = self.movieFileOutput else {
            print("Recording Manager not set up properly, recording cannot start")
            return
        }
        
        // Perform status update not in the sessionqueue
        self.isRecording = !movieFileOutput.isRecording
        
        sessionQueue.async {
            if !movieFileOutput.isRecording {
                if let movieFileOutputConnection = movieFileOutput.connection(with: .video) {
                    movieFileOutputConnection.videoOrientation = AVCaptureVideoOrientation(rawValue: self.orientation?.rawValue ?? 1)!
                    
                    if movieFileOutput.availableVideoCodecTypes.contains(.hevc) {
                        movieFileOutput.setOutputSettings(
                            [AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection)
                    }
                    
                    if let clip = self.project.startClip() {
                        movieFileOutput.startRecording(to: clip.temporaryURL!, recordingDelegate: self)
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
        self.recordingDuration = self.recordingButtonStyle == .snapchat ? snapchatFullTime : TimeInterval(0)
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
        if self.recordingButtonStyle == .snapchat {
            recordingDuration = snapchatFullTime - now.timeIntervalSince(recordingStartTime)
        } else {
            recordingDuration = now.timeIntervalSince(recordingStartTime)
        }
        if isRecording && recordingButtonStyle == .snapchat && recordingDuration <= 0.0 {
            self.timer.invalidate()
            toggleRecording() // stops the recording
//            guard !isRecording else {
//                print("IT DIDN'T STOP")
//                return
//            } // Ensure recording did stop
//            print("STARTING A NEW ONE")
//            toggleRecording() // restart the recording
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
    case snapchat // 0
    case camera // 1
}
