//
//  UpgradeManager.swift
//  Hermes
//
//  Created by David Cai on 12/18/22.
//

import Foundation

struct ProjectLevels {
    static let free = ProjectLevelInfo(memberLimit: 2, clipLimit: 2)
    static let upgrade1 = ProjectLevelInfo(memberLimit: 10, clipLimit: 100)
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
