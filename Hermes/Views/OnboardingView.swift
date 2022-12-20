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
    
    var body: some View {
        GeometryReader() { geo in
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                VStack(alignment: .leading) {
                    Spacer()
                    if step == 1 {
                        Text("Welcome to Hermes, a collaborative vlogging app.")
                            .font(.largeTitle.weight(Font.Weight.heavy))
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
                            model.setupCamera(callback: { self.step = 3 })
                        }) {
                            HStack {
                                Text("Yup, sounds good")
                                    .font(.system(.title3).bold())
                            }
                            .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight * 1.5)
                            .background(Color.blue)
                            .foregroundColor(Color.white)
                            .cornerRadius(Sizes.buttonCornerRadius)
                        }
                    } else if step == 3 {
                        Text("And finally, notifications to send update reminders")
                            .font(.largeTitle.bold())
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(height:10)
                        Text("Feel free to opt out if you'll remember to update your vlog yourself")
                            .font(.title2)
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(height:100)
                        Button(action: {
                            model.setupNotifications()
                            model.isOnboarding = false
                        }) {
                            Text("Yes, remind me").font(.system(.title3).bold())
                        }
                        .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight * 1.5)
                        .background(Color.blue)
                        .foregroundColor(Color.white)
                        .cornerRadius(Sizes.buttonCornerRadius)
                        Button(action: {
                            model.isOnboarding = false
                        }) {
                            Text("No thanks")
                                .font(.system(.subheadline))
                        }
                        .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight)
                        .background(Color.red)
                        .foregroundColor(Color.white)
                        .cornerRadius(Sizes.buttonCornerRadius)
                    }
                    Spacer()
                }
                .padding([.leading, .trailing], geo.size.width / 14)
            }
        }
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
