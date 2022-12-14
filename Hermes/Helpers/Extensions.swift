//
//  CGImageExtension.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import CoreGraphics
import VideoToolbox
import UIKit
import SwiftUI

extension CGImage {
  static func create(from cvPixelBuffer: CVPixelBuffer?) -> CGImage? {
    guard let pixelBuffer = cvPixelBuffer else {
      return nil
    }

    var image: CGImage?
    VTCreateCGImageFromCVPixelBuffer(
      pixelBuffer,
      options: nil,
      imageOut: &image)
    return image
  }
}

extension TimeInterval {
    var hours: Int {
        return Int(floor(self / 3600))
    }
    
    var minutes: Int {
        return Int(floor(Double((Int(self) % 3600)) / 60))
    }
    
    var seconds: Int {
        return Int(self) % 60
    }
    
    var miliseconds: Int {
        return Int((self*100).truncatingRemainder(dividingBy: 100))
    }
    
    var formattedTimeTwoMilliLeadingZero: String {
        let displayHours = self.hours == 0 ? "" : self.hours.withLeadingZero + ":"
        return String(
            displayHours + self.minutes.withLeadingZero + ":" + self.seconds.withLeadingZero + "." + self.miliseconds.withLeadingZero
        )
    }
    
    var formattedTimeOneMilliLeadingZero: String {
        let displayHours = self.hours == 0 ? "" : self.hours.withLeadingZero + ":"
        return String(
            displayHours + self.minutes.withLeadingZero + ":" + self.seconds.withLeadingZero + "." + String(self.miliseconds / 10)
        )
    }
    
    var formattedTimeNoMilliLeadingZero: String {
        let displayHours = self.hours == 0 ? "" : self.hours.withLeadingZero + ":"
        return String(
            displayHours + self.minutes.withLeadingZero + ":" + self.seconds.withLeadingZero
        )
    }
    
    var formattedTimeNoMilliNoLeadingZero: String {
        let displayHours = self.hours == 0 ? "" : String(self.hours) + ":"
        return displayHours + String(self.minutes.withLeadingZero) + ":" + self.seconds.withLeadingZero
    }
    
    var formattedTimeNoMilliNoLeadingZeroRoundUpOneSecond: String {
        let displayHours = self.hours == 0 ? "" : String(self.hours) + ":"
        return displayHours +
        String(self.seconds == 59 ? self.minutes + 1 : self.minutes)
        + ":" +
        (self.miliseconds == 0 ? self.seconds :
            self.seconds == 59 ? 0 : self.seconds + 1).withLeadingZero
    }
}

extension Date {
    var displayDayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE M/dd"
        
        return formatter.string(from: self)
    }
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "M/dd"
        
        return formatter.string(from: self)
    }
    
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mma"
        
        return formatter.string(from: self).lowercased()
    }
    
    func isSameDayAs(comp: Date) -> Bool {
        let selfDay = Calendar.current.dateComponents([.day], from: self)
        let compDay = Calendar.current.dateComponents([.day], from: comp)
        
        return selfDay == compDay
    }
}

extension Int {
    var withLeadingZero: String {
        return ((self < 10 ? "0" : "") + String(self))
    }
    
    var defaultTo1If0: Int {
        if self == 0 {
            return 1
        } else {
            return self
        }
    }
}

struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

// A View wrapper to make the modifier easier to use
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}


extension CGImage {
    func cropToCenter() -> CGImage {
        var xPos: CGFloat = 0.0
        var yPos: CGFloat = 0.0
        let size = UIImage(cgImage: self).size
        var width = size.width
        var height = size.height
        
        if size.width > size.height {
            xPos = (width - height) / 2
            width = size.height
        } else {
            yPos = (height - width) / 2
            height = size.width
        }
        
        let cropRect = CGRect(x: xPos, y: yPos, width: width, height: height)
        let croppedImage = self.cropping(to: cropRect)
        
        return croppedImage!
    }
}
