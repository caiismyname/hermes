//
//  ProjectSwitcher.swift
//  Hermes
//
//  Created by David Cai on 10/10/22.
//

import Foundation
import SwiftUI

struct SettingsModal: View {
    @ObservedObject var model: ContentViewModel
    @ObservedObject var recordingManager: RecordingManager
    private let sizes = Sizes()
    var dismissCallback: () -> ()
    
    // For creating a new project
    @State private var showingTitleAlert = false
    @State private var newProjectName = ""
    
    // Other settings
    @State var selectedRecordingButtonStyle: RecordingButtonStyle = .snapchat
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    
                    Button(action: { showingTitleAlert = !showingTitleAlert }) {
                        HStack {
                            Image(systemName: "plus.square")
                                .font(.system(size: sizes.secondaryButtonSize))
                            
                            Text("Create new")
                                .font(.system(.title3).bold())
                        }
                        .frame(maxWidth: .infinity, maxHeight: sizes.projectButtonHeight * 1.5)
                        .background(Color.blue)
                        .foregroundColor(Color.white)
                        .cornerRadius(sizes.buttonCornerRadius)
                        .alert("New Project Name", isPresented: $showingTitleAlert, actions: {
                            TextField(
                                "new project name",
                                text: $newProjectName,
                                prompt: Text(""))
                            .multilineTextAlignment(.leading)
                            
                            
                            Button("Cancel", action: {
                                self.showingTitleAlert = false
                            })
                            Button("Create", action: {
                                let newProject = model.createProject(name: newProjectName)
                                model.switchProjects(newProject: newProject)
                                dismissCallback()
                            })
                        })
                    }.padding()
//                        .border(.green)
                    
                    Spacer()
                    Text("My Projects")
                        .font(.system(.title).bold())
                        .padding([.leading])
//                        .border(.green)
                    
                    
                    List {
                        ForEach( model.allProjects.indices, id: \.self) { index in
                            HStack {
                                Text(model.allProjects[index].name)
                                    .font(model.project.id == model.allProjects[index].id ? .system(.body).bold() : .system(.body))
                                Spacer()
                            }
                            .foregroundColor(model.project.id == model.allProjects[index].id ? .blue : .white)
                            .contentShape(Rectangle())
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, alignment: .leading)
                            .onTapGesture {
                                model.switchProjects(newProject: model.allProjects[index])
                                dismissCallback()
                            }
                        }
                        .onDelete { idx in
                            model.deleteProject(toDelete: model.allProjects[idx.first!].id)
                        }
                    }
                    .frame(maxHeight: 250)
//                    .border(.green)

                    Text("Settings")
                        .font(.system(.title).bold())
                        .padding([.leading])
//                        .border(.green)

                    List {
                        VStack {
                            Text("Your name")
                            TextField("your name", text: $model.me.name)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    model.updateName(newName: model.me.name)
                                }   
                        }

                        VStack {
                            Text("Recording Button Style")
                            Spacer()
                            HStack {
                                VStack (alignment: .center) {
                                    Text("Snapchat")
                                    Circle()
                                        .strokeBorder(.white, lineWidth: sizes.recordButtonSize / 10)
                                        .frame(width: sizes.recordButtonOuterSize, height: sizes.recordButtonOuterSize)
                                    Text("Tap and hold to record, release to stop")
                                }
                                .padding()
                                .background(recordingManager.recordingButtonStyle == .snapchat ? .blue : .clear)
                                .cornerRadius(sizes.buttonCornerRadius)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    model.recordingManager.setRecordingButtonStyle(style: .snapchat)
                                }
                                Spacer()
                                VStack (alignment: .center) {
                                    Text("Camera")
                                    ZStack {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: sizes.recordButtonSize / 15)
                                            .frame(width: sizes.recordButtonOuterSize, height: sizes.recordButtonOuterSize)

                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: sizes.recordButtonSize, height: sizes.recordButtonSize)
                                    }
                                    Text("Tap to record, tap to stop")
                                }
                                .padding()
                                .background(recordingManager.recordingButtonStyle == .camera ? .blue : .clear)
                                .cornerRadius(sizes.buttonCornerRadius)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    model.recordingManager.setRecordingButtonStyle(style: .camera)
                                }
                            }
                        }
                    }
//                    .border(.green)
                }
                .frame(minHeight: (CGFloat(model.allProjects.count) * 60) + 700)
            }
            
            WaitingSpinner(model: model)
        }
    }
}

struct SettingsModal_Previews: PreviewProvider {
    static var previews: some View {
        let model = ContentViewModel()
        
        SettingsModal(
            model: model,
            recordingManager: model.recordingManager,
            dismissCallback: {}
        )
        .previewDevice("iPhone 13 Pro")
        .preferredColorScheme(.dark)
    }
}
