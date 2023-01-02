//
//  ProjectSettingsView.swift
//  Hermes
//
//  Created by David Cai on 12/17/22.
//

import Foundation
import SwiftUI

struct ProjectSettings: View {
    @ObservedObject var project: Project
    @ObservedObject var exporter: Exporter
    @State var showingRenameModal = false
    @State var showingUpgradeModal = false
    @State var upgradeInterstitalTitle = "Upgrading's a good choice 😉"
    
    init(project: Project) {
        self.project = project
        self.exporter = Exporter(project: project)
    }

    var body: some View {
        ZStack {
            VStack {
                VStack {
                    HStack {
                        Text("\(project.name)")
                            .font(.system(.title).bold())
                        
                        Button(action: {showingRenameModal = true}) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(Color.white)
                                .font(.system(.title3).bold())
                        }
                        .alert("Rename Project", isPresented: $showingRenameModal, actions: {
                            TextField("Name", text: $project.name)
                                .foregroundColor(Color.blue)
                                .onSubmit {
                                    print("New name \(project.name)")
                                    Task {
                                        await project.setProjectNameInFB(newName: project.name)
                                    }
                                }
                        })
                    }
                }
                .padding([.top, .bottom])
                
                HStack {
                    Button(action: {
                        Task {
                            project.startWork()
                            exporter.project = project
                            await exporter.export()
                            project.stopWork()
                        }
                    }) {
                        Text("Export")
                            .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight)
                    }
                    .background(Color.orange)
                    .cornerRadius(Sizes.buttonCornerRadius)
                    
                    if project.shareInitiated {
                        Button(action: {
                            project.startWork()
                            Task {
                                await project.networkAwareProjectDownload(shouldDownloadVideo: false)
                                await project.networkAwareProjectUpload(shouldUploadVideo: true)
                                self.project.stopWork()
                            }
                        }) {
                            Text("Sync")
                                .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight)
                        }
                        .background(Color.green)
                        .cornerRadius(Sizes.buttonCornerRadius)
                        
                        Button(action: {
                            project.startWork()
                            Task {
                                await project.downloadAllVideos()
                                self.project.stopWork()
                            }
                        }) {
                            Text("Download all")
                                .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight)
                        }
                        .background(Color.indigo)
                        .cornerRadius(Sizes.buttonCornerRadius)
                    }
                }
                    .foregroundColor(Color.white)
                    .font(.system(.body))
                    .padding([.bottom])
                
                UpgradeModule(
                    project: project,
                    upgradeCallback: {self.showingUpgradeModal = true}
                )
                
                Divider()
                    .frame(height: 0.6)
                    .overlay(Color.gray)
                    .padding([.top, .bottom])
                
                InviteButton(
                    project: project,
                    upgradeCallback: {title in
                        self.upgradeInterstitalTitle = title
                        self.showingUpgradeModal = true
                    }
                )
                
                if project.shareInitiated {
                    CreatorsList(
                        project: project
                    )
                } else {
                    Spacer()
                }
            }
            
            if project.isWorking > 0 {
                WaitingSpinner(project: project)
            }
            
            if showingUpgradeModal {
                UpgradeInterstitial(
                    dismissCallback: {showingUpgradeModal = false},
                    upgradeCallback: {
                        Task {
                            let success = await project.upgradeProject(upgradeLevel: ProjectLevel.upgrade1)
                            if success {
                                self.showingUpgradeModal = false
                            }
                        }
                    },
                    isOwner: project.isOwner(),
                    title: upgradeInterstitalTitle
                )
            }
        }
        .padding()
    }
}

struct InviteButton: View {
    @ObservedObject var project: Project
    var upgradeCallback: (String) -> ()
    
    var body: some View {
        VStack {
            if project.isOwner() {
                Toggle(
                    project.shareInitiated
                        ? "Enable Invite Link \n    (\(ProjectLevels.getLeveByName(levelName: project.projectLevel).memberLimit - project.creators.count) of \(ProjectLevels.getLeveByName(levelName: project.projectLevel).memberLimit) remaining)"
                        : "Enable Invite Link",
                    isOn: $project.inviteEnabled
                )
                    .font(.system(.title3))
                    .onChange(of: project.inviteEnabled) { newVal in
                        Task {
                            if !project.isUnderTierLimits && !project.shareInitiated {
                                upgradeCallback("You have \(project.allClips.count - ProjectLevels.free.clipLimit) too many clips")
                                project.inviteEnabled = false // Unset the change since the Toggle itself updates the value locally
                            } else {
                                let success = await project.setInviteSetting(isEnabled: newVal)
                            }
                        }
                    }
                    .padding([.bottom])
            }
            
            if project.inviteEnabled {
                if #available(iOS 16.0, *) {
                    ShareLink("Invite", item: project.generateURL())
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight * 1.5)
                        .foregroundColor(Color.white)
                        .background(Color.blue)
                        .cornerRadius(Sizes.buttonCornerRadius)
                        .font(.system(.title2).bold())
                        .padding([.bottom])
                } else {
                    BigButton(action: {}, text: "Invite", imageName: "plus.square")
                        .padding([.bottom])
                }
            }
        }
    }
}

struct CreatorsList: View {
    @ObservedObject var project: Project
 
    var body: some View {
        if project.shareInitiated {
            VStack(alignment: .leading) {
                Text("Members")
                    .font(.system(.title2).bold())
                
                List {
                    ForEach(Array(project.creators.keys), id: \.self) { uuid in
                        Text(project.creators[uuid] ?? "")
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, alignment: .leading)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct UpgradeModule: View {
    @ObservedObject var project: Project
    var upgradeCallback: () -> ()
    
    var body: some View {
        if project.shareInitiated {
            ZStack {
                RoundedRectangle(cornerRadius: Sizes.buttonCornerRadius)
                    .stroke(Color.white, lineWidth: 2)
                VStack {
                    if project.projectLevel == .free && project.isOwner() {
                        HStack {
                            Button(action: upgradeCallback) {
                                Text("Free tier. Tap to upgrade")
                            }
                        }
                    } else if project.projectLevel == .upgrade1 {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("Upgraded")
                            Image(systemName: "star.fill")
                        }
                    }
                    
                    Divider()
                        .frame(height: 0.6)
                        .overlay(Color.gray)
                    
                    Text("Clip count: \(project.allClips.count) out of \(ProjectLevels.getLeveByName(levelName: project.projectLevel).clipLimit)")
                        .foregroundColor(
                            project.isUnderTierLimits ? Color.white : Color.red
                        )
                    ProgressView(value: Float(project.allClips.count), total: Float(ProjectLevels.getLeveByName(levelName: project.projectLevel).clipLimit))
                }
                .padding()
            }
            .frame(height: 125)
        }
    }
}

struct UpgradeInterstitial: View {
    var dismissCallback: () -> ()
    var upgradeCallback: () -> ()
    var isOwner: Bool
    @State var title: String
    
    var body: some View {
        GeometryReader() { geo in
            ZStack {
                Rectangle()
                    .fill(Color.white)
                Rectangle()
                    .fill(Color.gray.opacity(0.25))
                VStack(spacing: 20) {
                    Spacer()
                    Text(title)
                        .font(.largeTitle.weight(Font.Weight.heavy))
                    HStack {
                        Spacer()
                        VStack(alignment: .leading) {
                            Spacer()
                            Text("Free").font(.system(.title2).bold())
                            Spacer()
                            Text("- \(ProjectLevels.free.memberLimit) members")
                            Text("- \(ProjectLevels.free.clipLimit) videos")
                            Text(" \n ") // spacing
                            Spacer()
                        }
                        .frame(width: 0.42 * geo.size.width, height: 0.3 * geo.size.height)
                        .overlay(
                            RoundedRectangle(cornerRadius: Sizes.buttonCornerRadius)
                                .stroke(Color.black, lineWidth: 2)
                        )
                        
                        VStack(alignment: .leading) {
                            Spacer()
                            Text("Upgraded 🌟").font(.system(.title2).bold())
                            Spacer()
                            Text("- \(ProjectLevels.upgrade1.memberLimit) members")
                            Text("- \(ProjectLevels.upgrade1.clipLimit) videos")
                            Text("- Support\n  development 👨‍💻")
                            Spacer()
                        }
                        .frame(width: 0.42 * geo.size.width, height: 0.3 * geo.size.height)
                        .overlay(
                            RoundedRectangle(cornerRadius: Sizes.buttonCornerRadius)
                                .stroke(Color.blue, lineWidth: 4)
                        )
                        
                        Spacer()
                    }
                    .frame(width: geo.size.width)
                    .padding()
                
                    VStack(alignment: .center) {
                        if isOwner {
                            BigButton(action: upgradeCallback, text: "Upgrade (free while in beta!)", imageName: "creditcard")
                                .padding([.bottom])
                            Button(action: dismissCallback) {
                                Text("No thanks")
                            }
                        } else {
                            Text("Ask owner to upgrade")
                                .font(.system(.title).bold())
                                .padding([.bottom])
                            Button(action: dismissCallback) {
                                Text("Close")
                            }
                        }
                    }
                    
                    Spacer()
                }
                .foregroundColor(Color.black)
                .frame(width: (12 * geo.size.width) / 14)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }
}


struct ProjectSettings_Previews: PreviewProvider {
    static var previews: some View {
        let project = Project(owner: "")

        ProjectSettings(project: project)
        .preferredColorScheme(.dark)
    }
}

//struct UpgradeInterstitial_Previews: PreviewProvider {
//    static var previews: some View {
//        UpgradeInterstitial(
//            dismissCallback: {},
//            upgradeCallback: {},
//            isOwner: false
//        )
//        .previewDevice("iPhone 8")
////        .preferredColorScheme(.dark)
//    }
//}
