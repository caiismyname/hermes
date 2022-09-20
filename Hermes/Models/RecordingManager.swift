//
//  RecordingManager.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import AVFoundation
import UIKit

class RecordingManager: NSObject, AVCaptureFileOutputRecordingDelegate {
    
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    private let sessionQueue = DispatchQueue(label: "com.caiismyname.SessionQ")
    var session: AVCaptureSession?
    var projectManager = ProjectManager()
    
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
        
        sessionQueue.async {
            if !movieFileOutput.isRecording {
                let movieFileOutputConnection = movieFileOutput.connection(with: .video)
                // TODO match orientations
                
                if movieFileOutput.availableVideoCodecTypes.contains(.hevc) {
                    movieFileOutput.setOutputSettings(
                        [AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection!)
                }
                
                if let clip = self.projectManager.startClip() {
                    movieFileOutput.startRecording(to: clip.temporaryURL, recordingDelegate: self)
                    print("start recording")
                }
            } else {
                movieFileOutput.stopRecording()
                print("stop recording")
            }
        }
    }
    
    /// - Tag: DidStartRecording
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Enable the Record button to let the user stop recording.
        DispatchQueue.main.async {
            // TODO set proper control status here
            print("recording started (delegate)")
        }
    }
    
    /// - Tag: DidFinishRecording
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        print(outputFileURL)
        self.projectManager.endClip()
        
//        func cleanup() {
//
//
//            // TODO Background recording clean
//        }
//
//        var success = true // this seems roundabout
//
//        if error != nil {
//            print("Movie file finishing error: \(String(describing: error))")
//            success = false // idk they had a whole complex unwrapping thing here
//        }
//
//        if success {
//            print("video saved correctly (delegate): \(outputFileURL)")
//        }
    }
}
