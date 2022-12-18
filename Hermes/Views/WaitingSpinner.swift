//
//  WaitingSpinner.swift
//  Hermes
//
//  Created by David Cai on 12/16/22.
//

import Foundation
import SwiftUI

struct WaitingSpinner: View {
    @ObservedObject var project: Project
    
    private let sizes = Sizes()
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: sizes.buttonCornerRadius)
                .fill(Color.white)
            VStack (alignment: .center) {
                Spacer()
                
                Text("\(project.spinnerLabel != "" ? project.spinnerLabel: "Syncing")")
                    .font(.system(.title3).bold())
                    .foregroundColor(Color.black)
                    .padding()
                
                if project.workTotal != 0.0 && project.workProgress > 0.0 {
                    ProgressView(value: project.workProgress, total: project.workTotal)
                        .controlSize(ControlSize.large)
                        .padding()
                        
                } else {
                    ProgressView()
                        .controlSize(ControlSize.large)
                        .padding()
                        .colorInvert()
                }
                
                Spacer()
            }
        }
        .frame(width: 200, height: 200)
    }
}
