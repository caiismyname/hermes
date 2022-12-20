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

    var body: some View {
        VStack {
            Text("\(project.name)")
                .font(.system(.title).bold())
            
            InviteButton(project: project)
            
            Spacer()
            
            CreatorsList(
                project: project,
                inviteEnabled: project.inviteEnabled
            )
        }
        .padding()
    }
}

struct InviteButton: View {
    @ObservedObject var project: Project
    
    var body: some View {
        if #available(iOS 16.0, *) {
            ShareLink("Invite", item: project.generateURL())
                .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight * 1.5)
                .foregroundColor(Color.white)
                .background(Color.blue)
                .cornerRadius(Sizes.buttonCornerRadius)
                .font(.system(.title2).bold())
        } else {
            BigButton(action: {}, text: "Invite", imageName: "plus.square")
        }
    }
}

struct CreatorsList: View {
    @ObservedObject var project: Project
    @State var inviteEnabled: Bool
 
    var body: some View {
        VStack(alignment: .leading) {
            Text("Members")
                .font(.system(.title2).bold())
            if project.isOwner() {
                Toggle("Enable Invite Link", isOn: $inviteEnabled)
                    .font(.system(.title3))
                    .onChange(of: inviteEnabled) { newVal in
                        Task {
                            let success = await project.setInviteSetting(isEnabled: newVal)
                        }
                    }
            }
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

struct UpgradeInterstitial: View {
    var dismissCallback: () -> ()
    var upgradeCallback: () -> ()
    var isOwner: Bool
    
    var body: some View {
        GeometryReader() { geo in
            ZStack {
                Rectangle()
                    .fill(Color.white)
                Rectangle()
                    .fill(Color.gray.opacity(0.25))
                VStack(alignment: .leading, spacing: 20) {
                    Spacer()
                    Text("You've hit the limit")
                        .font(.largeTitle.weight(Font.Weight.heavy))
                    Text("Free vlogs are limited to 2 members + 10 videos.")
                    Text("Upgrade for 10 members + 100 videos.")
                        .font(.system(.title3).bold())
                    VStack(alignment: .center) {
                        if isOwner {
                            BigButton(action: upgradeCallback, text: "Upgrade for 99¢", imageName: "creditcard")
                            Button(action: dismissCallback) {
                                Text("No thanks")
                            }
                        } else {
                            Text("Ask owner to upgrade the vlog")
                                .font(.largeTitle.weight(Font.Weight.heavy))
                            Button(action: dismissCallback) {
                                Text("Close")
                            }
                        }
                        Spacer()
                    }
                }
                .frame(width: (12 * geo.size.width) / 14, height: geo.size.height / 2)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }
}


struct ProjectSettings_Previews: PreviewProvider {
    static var previews: some View {
        let project = Project(owner: "")
        
        ProjectSettings(project: project)
        .previewDevice("iPhone 8")
        .preferredColorScheme(.dark)
    }
}

//struct UpgradeInterstitial_Previews: PreviewProvider {
//    static var previews: some View {
//        UpgradeInterstitial(
//            dismissCallback: {},
//            isOwner: false
//        )
//        .previewDevice("iPhone 8")
////        .preferredColorScheme(.dark)
//    }
//}
