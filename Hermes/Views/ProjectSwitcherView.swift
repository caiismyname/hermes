//
//  ProjectSwitcher.swift
//  Hermes
//
//  Created by David Cai on 10/10/22.
//

import Foundation
import SwiftUI

struct SwitchProjectsModal: View {
    @ObservedObject var model: ContentViewModel
    private let sizes = Sizes()
    var dismissCallback: () -> ()
    
    // For creating a new project
    @State private var showingTitleAlert = false
    @State private var newProjectName = ""
    
    var body: some View {
        VStack {
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
                    TextField("new project name", text: $newProjectName, prompt: Text(""))
                        .foregroundColor(Color.black)
                    Button("Create", action: {
                        let newProject = model.createProject(name: newProjectName)
                        model.switchProjects(newProject: newProject)
                        dismissCallback()
                    })
                })
            }.padding()
        
            Spacer()
            Text("Existing Projects")
                .font(.system(.title).bold())
                .padding()
            
            List(model.allProjects.indices, id: \.self) { index in
                HStack {
                    Text(model.allProjects[index].name)
                    Spacer()
                }
                    .contentShape(Rectangle())
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, alignment: .leading)
                    .onTapGesture {
                        model.switchProjects(newProject: model.allProjects[index])
                        dismissCallback()
                    }
            }
        }
    }
}
