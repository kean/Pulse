//
//  JSONCell.swift
//  JSONView
//
//  Created by Quentin Fasquel on 16/04/2020.
//

import SwiftUI

#if os(iOS) || os(visionOS)

struct JSONCell: View {
    private let key: String

    /// * note: According to [JSONSerialization](https://developer.apple.com/documentation/foundation/jsonserialization),
    /// acceptable values may be NSArray, NSDictionary, NSNumber, NSString or NSNull...
    private let rawValue: AnyHashable

    @State private var isOpen: Bool = false
    @State private var isRotate: Bool = false

    init(_ keyValue: (key: String, value: AnyHashable)) {
        self.init(key: keyValue.key, value: keyValue.value)
    }

    init(key: String, value: AnyHashable) {
        self.key = key
        self.rawValue = value
    }

    private func specificView() -> some View {
        switch rawValue {    
        case let array as [JSON]: // NSArray
            return AnyView(keyValueView(treeView: JSONTreeView(array, prefix: key)))
        case let dictionary as JSON: // NSDictionary
            return AnyView(keyValueView(treeView: JSONTreeView(dictionary, prefix: key)))
        case let anyPrimitivesArray as [AnyHashable]:
            return AnyView(keyValueView(treeView: JSONTreeView(anyPrimitivesArray)))
        case let number as NSNumber: // NSNumber
            if number === kCFBooleanTrue {
                return AnyView(leafView("true"))
            } else if number === kCFBooleanFalse {
                return AnyView(leafView("false"))
            } else {
                return AnyView(leafView(number.stringValue))
            }
        case let string as String: // NSString
            return AnyView(leafView(string))
        case is NSNull: // NSNull
            return AnyView(leafView("null"))
        default:
            fatalError()
        }
    }
    
    func copyValue() {
        switch rawValue {
        case let array as [JSON]:
            UIPasteboard.general.string = (array as JSONRepresentable).stringValue
        case let dictionary as JSON:
            UIPasteboard.general.string = (dictionary as JSONRepresentable).stringValue
        case let number as NSNumber:
            UIPasteboard.general.string = number.stringValue
        case let string as String:
            UIPasteboard.general.string = string
        default:
            UIPasteboard.general.string = nil
        }
    }
    
    var body: some View {
        specificView().padding(.leading, 10).contextMenu {
            Button(action: copyValue) {
                Text("Copy Value")
            }
        }
    }

    private func leafView(_ stringValue: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Text(key)
                Spacer()
            }

            Text(stringValue.prefix(60))
                .lineSpacing(0)
                .foregroundColor(Color.gray)
        }
            .padding(.vertical, 5)
            .padding(.trailing, 10)
    }

    private func toggle() {
        self.isOpen.toggle()
        withAnimation(.linear(duration: 0.1)) {
            self.isRotate.toggle()
        }
    }
    
    private func keyValueView(treeView valueView: JSONTreeView) -> some View {
        VStack(alignment: .leading) {
            Button(action: toggle) {
                HStack(alignment: .center) {
                    Image(systemName: "arrowtriangle.right.fill")
                        .resizable()
                        .frame(width: 10, height: 10, alignment: .center)
                        .foregroundColor(Color.gray)
                        .rotationEffect(Angle(degrees: isRotate ? 90 : 0))
                    
                    Text(key)
                    Spacer()
                }
            }

            if isOpen {
                Divider()
                valueView
            }
        }
    }
}

#endif
