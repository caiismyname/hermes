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
    var dismissCallback: () -> ()
    
    // For creating a new project
//    @State private var showingTitleAlert = false
//    @State private var newProjectName = ""
    
    // Other settings
//    @State var selectedRecordingButtonStyle: RecordingButtonStyle = .snapchat
    
    @State var screenShown = 0
    
    var body: some View {
        ZStack {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: Sizes.buttonCornerRadius)
                        .stroke(Color.blue, lineWidth: 2)
                    HStack(spacing: 0.0) {
                        Button(action: {screenShown = 0}) {
                            Text("Projects")
                                .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight)
                        }
                        .background(screenShown == 0 ? Color.blue : Color.black)
                        
                        Button(action: {screenShown = 1}) {
                            Text("Settings")
                                .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight)
                        }
                        .background(screenShown == 1 ? Color.blue : Color.black)
                    }
                    .mask {
                        RoundedRectangle(cornerRadius: Sizes.buttonCornerRadius)
                            .frame(height: Sizes.projectButtonHeight)
                    }
                }
                .frame(height: Sizes.projectButtonHeight)
                .font(.system(.body).bold())
                .foregroundColor(Color.white)
                .padding()
                
                if screenShown == 0 {
                    ProjectsListDisplay(model: model, dismissCallback: dismissCallback)
                } else if screenShown == 1 {
                    AppSettingsDisplay(model: model, recordingManager: recordingManager)
                }
            }
            
//            .frame(minHeight: (CGFloat(model.allProjects.count) * 60) + 700)
            
            if model.isWorking > 0 {
                WaitingSpinner(project: model.project)
            }
        }
    }
}

struct AppSettingsDisplay: View {
    @ObservedObject var model: ContentViewModel
    @ObservedObject var recordingManager: RecordingManager
    @State var selectedRecordingButtonStyle: RecordingButtonStyle = .snapchat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(.system(.title).bold())
                .padding([.leading])
            
            HStack() {
                Text("Name")
                    .font(.system(.body).bold())
                TextField("your name", text: $model.me.name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        model.updateName(newName: model.me.name)
                    }
            }
                .padding()
        
            Group {
                Text("Recording Button Style")
                    .font(.system(.body).bold())
                HStack() {
                    VStack (alignment: .center) {
                        Text("Snapchat")
                        Circle()
                            .strokeBorder(.white, lineWidth: Sizes.recordButtonSize / 10)
                            .frame(width: Sizes.recordButtonOuterSize, height: Sizes.recordButtonOuterSize)
                        Text("Tap and hold to record, release to stop")
                    }
                        .padding()
                        .background(recordingManager.recordingButtonStyle == .snapchat ? .blue : .black)
                        .cornerRadius(Sizes.buttonCornerRadius)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.recordingManager.setRecordingButtonStyle(style: .snapchat)
                        }
                    Spacer()
                    VStack (alignment: .center) {
                        Text("Camera")
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: Sizes.recordButtonSize / 15)
                                .frame(width: Sizes.recordButtonOuterSize, height: Sizes.recordButtonOuterSize)
                            
                            Circle()
                                .fill(Color.red)
                                .frame(width: Sizes.recordButtonSize, height: Sizes.recordButtonSize)
                        }
                        Text("Tap to record, tap to stop\n")
                    }
                        .padding()
                        .background(recordingManager.recordingButtonStyle == .camera ? .blue : .black)
                        .cornerRadius(Sizes.buttonCornerRadius)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.recordingManager.setRecordingButtonStyle(style: .camera)
                        }
                }
            }
                .padding()
            
            Spacer()
        }
    }
}

struct ProjectsListDisplay: View {
    @ObservedObject var model: ContentViewModel
    var dismissCallback: () -> ()
    
    @State private var showingTitleAlert = false
    @State private var newProjectName = ""
    @State private var showDeleteAlert = false
    @State private var toDeleteIdx: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("My Projects")
                .font(.system(.title).bold())
                .padding([.leading])
            
            BigButton(
                action: { self.showingTitleAlert = !self.showingTitleAlert },
                text: "Create new",
                imageName: "plus.square"
            )
            .alert("New Project Name", isPresented: $showingTitleAlert, actions: {
                TextField(
                    "new project name",
                    text: $newProjectName,
                    prompt: Text("")
                )
                .multilineTextAlignment(.leading)
                .foregroundColor(Color.blue)
                
                Button("Cancel", action: { self.showingTitleAlert = false })
                Button("Create", action: {
                    let newProject = model.createProject(name: newProjectName)
                    model.switchProjects(newProject: newProject)
                    dismissCallback()
                })
            }).padding()
            
            List {
                ForEach( model.allProjects.indices, id: \.self) { index in
                    ProjectListEntry(model: model, index: index) // This separate view exists so deletions don't cause IndexOOB errors
                        .contentShape(Rectangle())
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, alignment: .leading)
                        .onTapGesture {
                            model.switchProjects(newProject: model.allProjects[index])
                            dismissCallback()
                        }
                }
                .onDelete { idx in
                    toDeleteIdx = idx.first!
                    showDeleteAlert = true
                }
                .alert(isPresented: $showDeleteAlert) {
                    Alert(
                        title: Text("Are you sure you want to delete this project?"),
                        primaryButton: .destructive(Text("Delete")) {
                            if toDeleteIdx != nil {
                                model.deleteProject(toDelete: model.allProjects[toDeleteIdx!].id)
                            }
                        },
                        secondaryButton: .cancel(Text("Cancel")) {
                            showDeleteAlert = false
                        }
                    )
                }
            }
//            .frame(maxHeight: 250)
            .alert(isPresented: $model.couldNotLoadProject) {
                Alert(
                    title: Text("Could not join project"),
                    message: Text(model.couldNotLoadProjectReason),
                    dismissButton: .default(Text("Okay"))
                )
            }
        }
    }
}

struct ProjectListEntry: View {
    @ObservedObject var model: ContentViewModel
    let index: Int
    
    var body: some View {
        if index < model.allProjects.count { // Otherwise we get an indexOutOfBounds on deletions
            HStack {
                Text(model.allProjects[index].name)
                    .font(model.project.id == model.allProjects[index].id ? .system(.body).bold() : .system(.body))
                Spacer()
            }
            .foregroundColor(model.project.id == model.allProjects[index].id ? .blue : .white)
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
        .preferredColorScheme(.dark)
    }
}
