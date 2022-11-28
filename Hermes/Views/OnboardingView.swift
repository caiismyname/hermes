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
        VStack(alignment: .leading) {
            Spacer()
            Text("Welcome to Hermes, a collaborative vlogging app.")
                .font(.largeTitle.bold())
            Rectangle()
                .foregroundColor(.clear)
                .frame(height:10)
            Text("Record videos with friends to make shared memories together.")
                .font(.title2)
            
            Rectangle()
                .foregroundColor(.clear)
                .frame(height:40)
            
            Text("Before we start, what's your name?")
                .font(.title2)
            TextField("Name", text: $inputName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    model.updateName(newName: inputName)
                    model.isOnboarding = false
                }
                .font(.title2)
            
            Spacer()
            Spacer()
        }
        .padding([.leading, .trailing], 40)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
//        let model = ContentViewModel()
        
        OnboardingView(model: ContentViewModel())
        .previewDevice("iPhone 13 Pro")
        .preferredColorScheme(.dark)
    }
}
