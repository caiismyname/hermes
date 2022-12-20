//
//  Helpers.swift
//  Hermes
//
//  Created by David Cai on 12/18/22.
//

import Foundation
import SwiftUI

struct BigButton: View {
    var action: () -> ()
    var text: String
    var imageName: String
    
    var body: some View {
        Button(action: {action()}) {
            HStack {
                if imageName != "" {
                    Image(systemName: imageName)
                        .font(.system(size: Sizes.secondaryButtonSize))
                }
                
                Text(text)
                    .font(.system(.title3).bold())
            }
            .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight * 1.5)
            .background(Color.blue)
            .foregroundColor(Color.white)
            .cornerRadius(Sizes.buttonCornerRadius)
        }
    }
}
