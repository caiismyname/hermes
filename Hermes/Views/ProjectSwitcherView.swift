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
    
    var body: some View {
        VStack {
            Spacer()
            
            Button(action: { model.createProject() }) {
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
