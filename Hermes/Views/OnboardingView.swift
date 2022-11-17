//
//  OnboardingVIew.swift
//  Hermes
//
//  Created by David Cai on 11/16/22.
//

import Foundation
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: ContentViewModel
    @State var inputName = ""
    
    var body: some View {
        VStack {
            Spacer()
            Text("Welcome to Hermes, a collaborative vlogging app.")
                .font(.largeTitle.bold())
            Text("Share your vlogs with friends to make memories together.")
                .font(.title2)
            Spacer()
            
            Text("One detail before we start: what's your name?")
                .font(.title2)
            
            TextField("Name", text: $inputName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    model.updateName(newName: inputName)
                    model.isOnboarding = false
                }
                .font(.title2)
                .padding()
            
            Spacer()
        }
    }
}
