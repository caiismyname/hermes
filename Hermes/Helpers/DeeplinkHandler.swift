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
        guard url.scheme == URLSchema.schema, url.host == URLSchema.host else {
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
    // EXAMPLE URL: https://rompvlog.com/invite?projectId=123
    static let schema = "https"
    static let host = "rompvlog.com"
    static let page = "invite"
    static let projectIdParam = "projectId"
    
    static var baseURL =  schema + "://" + host + "/" + page + "?" + projectIdParam + "="
}
