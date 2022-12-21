//
//  UpgradeManager.swift
//  Hermes
//
//  Created by David Cai on 12/18/22.
//

import Foundation

struct ProjectLevels {
    static let free = ProjectLevelInfo(memberLimit: 2, clipLimit: 10)
    static let upgrade1 = ProjectLevelInfo(memberLimit: 10, clipLimit: 100)
    
    static let privateMessage = "This project is currently private. \n\n Ask the owner to enable the invite link and try again."
    static let freeTierNoSpace = "This vlog has reached its member limit. \n\n Ask the owner to upgrade and try again."
    static let upgradeTierNoSpace = "This vlog has reached its member limit. \n\n We apologize and are working to expand our capacity."
    static let genericFailureMessage = "This project could not be downloaded because of an error. \n\n Ask the owner to re-sync and try again."
}

struct ProjectLevelInfo {
    let memberLimit: Int
    let clipLimit: Int
}

// Names of the levels are seperated from their content definitions so we can arbitrarily change the meaning of each level without a massive rebase
enum ProjectLevel: String, Codable {
    case free = "free"
    case upgrade1 = "upgrade1"
}
