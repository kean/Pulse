//
//  JSONTreeView.swift
//  Example
//
//  Created by Quentin Fasquel on 16/04/2020.
//

import SwiftUI

#if os(iOS) || os(visionOS)

struct JSONTreeView: View {
    private let keyValues: [(key: String, value: AnyHashable)]
    
    init(_ dictionary: JSON) {
        self.keyValues = dictionary.sorted { $0.key < $1.key }
    }
    
    init(_ array: [AnyHashable]) {
        self.keyValues = array.enumerated().map({($0.offset.description, $0.element)})
    }
    
    init(_ array: [JSON], prefix key: String = "") {
        self.keyValues = array.enumerated().map {
            (key: "\(key)[\($0.offset)]", value: $0.element)
        }
    }

    init(_ source: [(key: String, value: AnyHashable)]) {
        self.keyValues = source
    }
    
    var body: some View {
        ForEach(keyValues.indices, id: \.self) { index in
            VStack(alignment: .leading) {
                if index > 0 {
                    Divider()
                }

                JSONCell(self.keyValues[index])
            }
        }.frame(minWidth: 0, maxWidth: .infinity)
    }
}

// MARK: -

protocol JSONRepresentable {
    var stringValue: String? { get }
}

extension JSONRepresentable {
    var stringValue: String? {
        do {
            let data = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

extension Array: JSONRepresentable where Element: JSONRepresentable {
}

extension JSON: JSONRepresentable {
}

extension JSONTreeView {
    init(_ json: JSONRepresentable, prefix key: String = "") {
        switch json {
        case let array as [JSON]:
            self.init(array, prefix: key)
        case let dictionary as JSON:
            self.init(dictionary)
        default:
            self.init(JSON())
        }
    }
}

#endif
