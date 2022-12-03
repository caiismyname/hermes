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
    @State var step = 1
    private let sizes = Sizes()
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            if step == 1 {
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
                        step = 2
                    }
                    .font(.title2)
            } else if step == 2 {
                Text("We'll need camera and mic permissions to record videos")
                    .font(.largeTitle.bold())
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(height:100)
                Button(action: {
                    model.setupCamera()
                    model.isOnboarding = false
                }) {
                    HStack {
                        Text("Yup, sounds good")
                            .font(.system(.title3).bold())
                    }
                    .frame(maxWidth: .infinity, maxHeight: sizes.projectButtonHeight * 1.5)
                    .background(Color.blue)
                    .foregroundColor(Color.white)
                    .cornerRadius(sizes.buttonCornerRadius)
                }
            }
            Spacer()
            Spacer()
        }
        .padding([.leading, .trailing], 20)
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
