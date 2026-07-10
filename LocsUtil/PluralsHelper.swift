//
//  PluralsHelper.swift
//  LocsUtil
//
//  Created by Martin Krasnocka on 31/03/2023.
//  Copyright © 2023 Martin Krasnocka. All rights reserved.
//

import Foundation

let pluralFormatPlaceholder = "plural"

func shouldEmitStandaloneAndroidString(key: String, disablePlurals: Bool) -> Bool {
    disablePlurals || !key.isPluralKey()
}

extension String {
    static let pluralSuffixes = ["_zero", "_one", "_two", "_few", "_many", "_other"]
    
    func isPluralKey() -> Bool {
        String.pluralSuffixes.contains { self.hasSuffix($0) }
    }
    
    func removePluralSuffix() -> String {
        var result = self
        for suffix in String.pluralSuffixes {
            if let range = result.range(of: suffix) {
                result = String(result.prefix(upTo: range.lowerBound))
            }
        }
        return result
    }
}

extension Array where Element == String {
    func computeFormatString() -> (String, [String])? {
        let allComponents = map { $0.components(separatedBy: " ") }
        
//        print("[\(map { "\"\($0)\"" }.joined(separator: ", "))],")
//        let hasSameNumberOfComponents = allComponents.allSatisfy({ components in
//            components.count == allComponents.first?.count ?? 0
//        })
//
//        if !hasSameNumberOfComponents {
//            print("!hasSameNumberOfComponents: [\(map { "\"\($0)\"" }.joined(separator: ", "))],")
//        }
        
        var distinctIndex: Int?
        let componentCount = allComponents.first?.count ?? 0
        for i in 0..<componentCount {
            var value = ""
            for (j, components) in allComponents.enumerated() {
                if j == 0 {
                    value = components[i]
                } else {
                    if components[i] != value {
                        // found distinct index
                        distinctIndex = i
                        break
                    }
                }
            }
            if distinctIndex != nil {
                break
            }
        }
        
        if let components = allComponents.first {
            if let distinctIndex = distinctIndex {
                var mutatedComponents = components
                
                let pluralWords = allComponents.map { components in
                    components[distinctIndex]
                }
                mutatedComponents[distinctIndex] = "%#@\(pluralFormatPlaceholder)@"
                return (mutatedComponents.joined(separator: " "), pluralWords)
            } else {
                // there's no distinctIndex - every form of the plural string is the same
                var emptyPlurals = [String]()
                for _ in 0..<allComponents.count {
                    emptyPlurals.append("")
                }
                return (components.joined(separator: " ") + "%#@\(pluralFormatPlaceholder)@", emptyPlurals)
            }
        } else {
            return nil
        }
    }
}

struct Plural {
    let key: String
    let formatString: String
    let pluralStringKey: String
    let zero: String?
    let one: String?
    let two: String?
    let few: String?
    let many: String?
    let other: String?
}

func computePlurals(pluralKeyValues: [String: String]) -> [Plural] {
    var pluralKeys = [String]()
    for key in pluralKeyValues.keys {
        let pluralKey = key.removePluralSuffix()
        if !pluralKeys.contains(pluralKey) {
            pluralKeys.append(pluralKey)
        }
    }
    var plurals = [Plural]()
    for pluralKey in pluralKeys {
        var allValueStringsForKey = [String]()
        for suffix in String.pluralSuffixes {
            if let value = pluralKeyValues[pluralKey + suffix] {
                allValueStringsForKey.append(value)
            }
        }
        if let formatStringInfo = allValueStringsForKey.computeFormatString(), formatStringInfo.1.count == 6 {
            plurals.append(Plural(key: pluralKey,
                                  formatString: formatStringInfo.0,
                                  pluralStringKey: pluralFormatPlaceholder,
                                  zero: formatStringInfo.1[0],
                                  one: formatStringInfo.1[1],
                                  two: formatStringInfo.1[2],
                                  few: formatStringInfo.1[3],
                                  many: formatStringInfo.1[4],
                                  other: formatStringInfo.1[5]))
            
        } else {
            print("Skipping plural for \(pluralKey) key")
        }
    }
    return plurals.sorted { pl1, pl2 in
        pl1.key < pl2.key
    }
}

func computePluralsAndroid(pluralKeyValues: [String: String]) -> [Plural] {
    var pluralKeys = [String]()
    for key in pluralKeyValues.keys {
        let pluralKey = key.removePluralSuffix()
        if !pluralKeys.contains(pluralKey) {
            pluralKeys.append(pluralKey)
        }
    }
    var plurals = [Plural]()
    for pluralKey in pluralKeys {
        var allValueStringsForKey = [String]()
        for suffix in String.pluralSuffixes {
            if let value = pluralKeyValues[pluralKey + suffix] {
                allValueStringsForKey.append(value)
            }
        }
        
        if allValueStringsForKey.count == 6 {
            plurals.append(Plural(key: pluralKey,
                                  formatString: "",
                                  pluralStringKey: pluralFormatPlaceholder,
                                  zero: allValueStringsForKey[0],
                                  one: allValueStringsForKey[1],
                                  two: allValueStringsForKey[2],
                                  few: allValueStringsForKey[3],
                                  many: allValueStringsForKey[4],
                                  other: allValueStringsForKey[5]))
        } else {
            print("Skipping plural for \(pluralKey) key")
        }

    }
    return plurals.sorted { pl1, pl2 in
        pl1.key < pl2.key
    }
}

func generatePluralsFileiOS(pluralKeyValues: [String: String]) -> String? {
    let output = NSMutableString()
    output.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
    output.append("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n")
    output.append("<plist version=\"1.0\">\n")
    output.append("<dict>\n")
    
    let plurals = computePlurals(pluralKeyValues: pluralKeyValues)
    guard !plurals.isEmpty else {
        return nil
    }
    
    for plural in plurals {
        guard plural.zero != nil || plural.one != nil || plural.two != nil || plural.few != nil || plural.many != nil || plural.other != nil else {
            continue
        }
        output.append("\t<key>\(plural.key)</key>\n")
        output.append("\t<dict>\n")
        output.append("\t\t<key>NSStringLocalizedFormatKey</key>\n")
        output.append("\t\t<string>\(plural.formatString)</string>\n")
        output.append("\t\t<key>\(plural.pluralStringKey)</key>\n")
        output.append("\t\t<dict>\n")
        output.append("\t\t\t<key>NSStringFormatSpecTypeKey</key>\n")
        output.append("\t\t\t<string>NSStringPluralRuleType</string>\n")
        output.append("\t\t\t<key>NSStringFormatValueTypeKey</key>\n")
        output.append("\t\t\t<string>d</string>\n")
        
        if let value = plural.zero {
            output.append("\t\t\t<key>zero</key>\n")
            output.append("\t\t\t<string>\(value)</string>\n")
        }
        if let value = plural.one {
            output.append("\t\t\t<key>one</key>\n")
            output.append("\t\t\t<string>\(value)</string>\n")
        }
        if let value = plural.two {
            output.append("\t\t\t<key>two</key>\n")
            output.append("\t\t\t<string>\(value)</string>\n")
        }
        if let value = plural.few {
            output.append("\t\t\t<key>few</key>\n")
            output.append("\t\t\t<string>\(value)</string>\n")
        }
        if let value = plural.many {
            output.append("\t\t\t<key>many</key>\n")
            output.append("\t\t\t<string>\(value)</string>\n")
        }
        if let value = plural.other {
            output.append("\t\t\t<key>other</key>\n")
            output.append("\t\t\t<string>\(value)</string>\n")
        }
        output.append("\t\t</dict>\n")
        output.append("\t</dict>\n")
    }
    output.append("</dict>\n")
    output.append("</plist>\n")
    
    return output as String
}

func generatePluralsFileAndroid(pluralKeyValues: [String: String]) -> String? {
    let output = NSMutableString()
    
    let plurals = computePluralsAndroid(pluralKeyValues: pluralKeyValues)
    guard !plurals.isEmpty else {
        return nil
    }
    
    for plural in plurals {
        guard plural.zero != nil || plural.one != nil || plural.two != nil || plural.few != nil || plural.many != nil || plural.other != nil else {
            continue
        }
        output.append("<plurals name=\"\(plural.key)\">\n")
     
        if let value = plural.zero {
            output.append("\t<item quantity=\"zero\">\(value)</item>\n")
        }
        if let value = plural.one {
            output.append("\t<item quantity=\"one\">\(value)</item>\n")
        }
        if let value = plural.two {
            output.append("\t<item quantity=\"two\">\(value)</item>\n")
        }
        if let value = plural.few {
            output.append("\t<item quantity=\"few\">\(value)</item>\n")
        }
        if let value = plural.many {
            output.append("\t<item quantity=\"many\">\(value)</item>\n")
        }
        if let value = plural.other {
            output.append("\t<item quantity=\"other\">\(value)</item>\n")
        }
        output.append("</plurals>\n")
    }    
    
    return output as String
}
