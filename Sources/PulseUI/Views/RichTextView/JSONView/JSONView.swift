//
//  JSONView.swift
//  JSONView
//
//  Created by Quentin Fasquel on 16/04/2020.
//

import SwiftUI

#if os(iOS) || os(visionOS)

typealias JSON = [String: AnyHashable]

// MARK: -

struct JSONView: View {
    private let rootArray: [JSON]?
    private let rootDictionary: JSON

    init(_ array: [JSON]) {
        self.rootArray = array
        self.rootDictionary = JSON()
    }

    init(_ dictionary: JSON) {
        self.rootArray = nil
        self.rootDictionary = dictionary
    }

    init(data: Data) {
        do {
            let jsonData = try JSONSerialization.jsonObject(with: data, options: [])
            self.rootArray = jsonData as? [JSON]
            self.rootDictionary = jsonData as? JSON ?? JSON()
        } catch {
            self.rootArray = nil
            self.rootDictionary = JSON()
            print("JSONView error: \(error.localizedDescription)")
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            JSONTreeView(rootArray ?? rootDictionary)
        }
    }
}

#endif
