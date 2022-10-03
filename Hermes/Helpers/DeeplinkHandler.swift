//
//  DeeplinkHandler.swift
//  Hermes
//
//  Created by David Cai on 10/3/22.
//

import Foundation



class DeeplinkHandler {
    static func getProjectIdFromDeeplink(url: URL) -> UUID? {
        print("Parsing deeplink: \(url)")
        guard url.scheme == URLSchema.schema, url.host == URLSchema.identifier else {
            return nil
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let params = components?.queryItems?.reduce(into: [String:String](), { partialResult, q in
            partialResult[q.name] = q.value
        })
        
        return(UUID(uuidString: params![URLSchema.projectIdParam]!))
    }
}

class URLSchema {
    // EXAMPLE URL: hermesProject://com.caiismyname.hermes/?projectId=123
    static let schema = "hermesProject"
    static let identifier = "com.caiismyname.hermes"
    static let projectIdParam = "projectId"
}
