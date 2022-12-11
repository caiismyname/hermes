//
//  Exporter.swift
//  Hermes
//
//  Created by David Cai on 12/9/22.
//

import Foundation
import AVFoundation
import Photos
import UIKit
import SwiftUI

class Exporter: ObservableObject {
    var project: Project
    private var progressTimer: Timer?
    private var exporter: AVAssetExportSession?
    
    init(project: Project) {
        self.project = project
    }
    
    private func photosPermissionsCheck() -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .notDetermined:
            var res = false
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { authorized in
                res = self.photosPermissionsCheck()
            }
            return res
        case .restricted, .denied, .limited:
            return false
        case .authorized:
            return true
        @unknown default:
            return false
        }
    }
    
    private func saveToPhotoLibrary(movieURL: URL) async {
        guard photosPermissionsCheck() else { return } // Double checking but we should already have it from the beginning of the func
        print("    Saving full movie to photo library for project \(self.project.id.uuidString))")
        
        PHPhotoLibrary.shared().performChanges({
            let assetCollection = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "Hermes Vlogs")
            let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: movieURL)
            assetCollection.addAssets([creationRequest?.placeholderForCreatedAsset] as NSFastEnumeration)
        }) {success, error in
            if !success {
                print(error?.localizedDescription)
            } else {
                print("    Movie finished saving to photo library")
            }
        }
    }
    
    func export() async {
        guard photosPermissionsCheck() else { return }
        
        print("Starting movie export")
        project.prepareWorkProgress(label:"Exporting", total: 1.0)
        
        let fullMovie = AVMutableComposition()
        let fullInstructions = AVMutableVideoCompositionInstruction()
        fullInstructions.layerInstructions = [AVMutableVideoCompositionLayerInstruction]()
        
        var startCumulative = CMTime.zero
        
        do {
            for clip in project.allClips {
                guard clip.finalURL != nil else { return }
                
                let clipContent = AVURLAsset(url: clip.finalURL!)
                let clipDuration = try await clipContent.load(.duration)
                let clipVideo = try await clipContent.loadTracks(withMediaType: .video)[0]
                let clipAudio = try await clipContent.loadTracks(withMediaType: .audio)[0]
                var clipTransform = try await clipVideo.load(.preferredTransform)
                let clipTimerange = CMTimeRange(start: CMTime.zero, duration: clipDuration)
                print("original \(clipTransform)")
                
                if clipTransform.a == 1.0 {
                    clipTransform = clipTransform.translatedBy(x: 0, y: (1920.0 / 2.0)  - ((1080.0 * (1080.0/1920.0)) / 2.0))
                    clipTransform = clipTransform.scaledBy(x: 1080.0 / 1920.0, y: 1080.0 / 1920.0)
                } else if clipTransform.a == -1.0 {
                    clipTransform = clipTransform.scaledBy(x: 1080.0 / 1920.0, y: 1080.0 / 1920.0)
                    clipTransform = clipTransform.translatedBy(x: (1920.0 - 1080.0) / 0.5625, y: -183.75 / 0.5625)
                }
                
                let videoTrack = fullMovie.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                let audioTrack = fullMovie.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                
                try videoTrack?.insertTimeRange(clipTimerange, of: clipVideo, at: startCumulative)
                try audioTrack?.insertTimeRange(clipTimerange, of: clipAudio, at: startCumulative)
                
                let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack!)
                instruction.setTransform(clipTransform, at: startCumulative)
                instruction.setOpacity(0.0, at: CMTimeAdd(startCumulative, clipDuration)) // This hides the clip after its done, otherwise the video is stuck on the first clip the whole time
                fullInstructions.layerInstructions.append(instruction)

                
                startCumulative = CMTimeAdd(startCumulative, clipDuration)
                
                print("    Processed clip \(clip.id.uuidString)")
                print("transform \(clipTransform)")
            }
        } catch {
            print(error)
        }
        
        fullInstructions.timeRange = CMTimeRange(start: .zero, duration: startCumulative)
        
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [fullInstructions]
        mainComposition.frameDuration = CMTime(value: 1, timescale: 30)
        mainComposition.renderSize = CGSize(width: 1080, height: 1920)
        
        self.exporter = AVAssetExportSession(asset: fullMovie, presetName: AVAssetExportPresetHighestQuality)
        guard self.exporter != nil else {
            print("    Exporter initialization error")
            return
        }
        
        let url = URL(
            fileURLWithPath:
                (NSTemporaryDirectory() as NSString).appendingPathComponent(
                    (UUID().uuidString as NSString).appendingPathExtension("mov")!
                )
        )
        
        exporter?.outputURL = url
        exporter?.outputFileType = .mov
        exporter?.videoComposition = mainComposition
        
        DispatchQueue.main.async {
            self.progressTimer = Timer.scheduledTimer(
                timeInterval: TimeInterval(0.3),
                target: self,
                selector: (#selector(self.updateProgress)),
                userInfo: nil,
                repeats: true
            )
            RunLoop.main.add(self.progressTimer!, forMode: .common)
        }

        await exporter?.export()
        print("    Exported to \(url)")
        await self.saveToPhotoLibrary(movieURL: url)
        self.project.resetWorkProgress()
    }
    
    @objc func updateProgress() {
        let progress = exporter?.progress
        guard progress != nil else {return}
        self.project.workProgress = Double(progress!)
        if progress! > 0.95 && self.progressTimer != nil {
            self.progressTimer!.invalidate()
        }
    }
}


