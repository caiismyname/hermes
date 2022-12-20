//
//  LoadingView.swift
//  Hermes
//
//  Created by David Cai on 12/19/22.
//

import Foundation
import SwiftUI

struct LoadingView: View {
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                
                Circle()
                    .strokeBorder(.gray, lineWidth: Sizes.recordButtonSize / 10)
                    .frame(width: Sizes.recordButtonOuterSize, height: Sizes.recordButtonOuterSize)
                    .position(
                        x: geometry.size.width * 0.5,
                        y: geometry.size.height - Sizes.bottomOffset
                    )
            }
        }
    }
}
