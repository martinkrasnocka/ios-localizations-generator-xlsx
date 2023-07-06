//
//  LocsGenerator.swift
//  LocsUtil
//
//  Created by Martin Krasnocka on 20/09/2017.
//  Copyright © 2017 Martin Krasnocka. All rights reserved.
//

import Cocoa

typealias Csv = [[String]]
typealias XlsxFile = [[String: String]]

class LocsGenerator: NSObject {

//    var csvReader: CsvReader
    var xlsxReader: XlsxReader
    let langRowIndex = 0 // Language definitions - row index in XSLSX document
    let keyColumnId = "A" // Key definitions - column index in XSLSX document
    let version = "2.50"
    
    override init() {
//        csvReader = CsvReader()
        xlsxReader = XlsxReader()
    }
    
    func generate(args: AppArguments!) {
        print("LocsUtil version: \(version). Homepage: https://github.com/martinkrasnocka/LocsUtil\n")
        
        if args == nil {
            args.printNoArgumetsHelp()
            return
        }
        args.printArguments()
        
        let nowDate = Date()
        
        let xlsxContent = xlsxReader.loadXlsxFromFile(atPath: args.inputFile) as? XlsxFile
        guard let xlsx = xlsxContent else {
            print("unable to parse inputFile file")
            exit(1)
        }
        
        let langColumnsDict = xlsx[langRowIndex]
        
        // print("langColumnsDict \"\(langColumnsDict)\" ")
        
        let locKeys = readColumnWithId(keyColumnId, xlsx: xlsx, args: args)
        
        var config: NSDictionary? = nil
        if args.configFile != nil {
            config = NSDictionary(contentsOfFile: args.configFile)
        }
        
        for (columnId, lang) in langColumnsDict {
            if lang.count == 0 {
                // empty column
                continue
            }
            if columnId == "A" {
                continue
            }
            if columnId == keyColumnId {
                // column with translation keys
                continue
            }
            if !isLangFormatValid(lang) {
                print("Skipping \"\(columnId)\" column. \"\(lang)\" is not a valid language identifier.")
                continue
            }
            
            let langValues = readColumnWithId(columnId, xlsx: xlsx, args: args)
            let outputString = NSMutableString()
            
            var plistsOutputStrings = Dictionary<String, Any>()
            for plistName in config?.allKeys ?? [] {
                plistsOutputStrings[plistName as! String] = NSMutableString()
            }
            
            var pluralKeyValues = [String: String]()
            
            for keyIndex in 0..<locKeys.count {
                let keyString = locKeys[keyIndex]
                let valueString = langValues[keyIndex]
                
                // skip empty lines
                guard keyString.count > 0 || valueString.count > 0 else {
                    continue
                }
                
                if keyString.isPluralKey() && !valueString.isEmpty {
                    pluralKeyValues[keyString] = valueString
                }
                if (args.platform=="ios") {
                    appendLineToOutputiOS(keyString: keyString, valueString: valueString, defaultOutput: outputString, plistOutputs: plistsOutputStrings, config: config)
                } else {
                    appendLineToOutputAndroid(keyString: keyString, valueString: valueString, defaultOutput: outputString, plistOutputs: plistsOutputStrings, config: config)
                }
            }
            
            if (args.platform=="ios") {
                saveToLocalizableStringsFile(outputDir: args.outputDir, lang: lang, outputString: outputString as String)
                saveToInfoPlistFile(outputDir: args.outputDir, lang: lang, plistsOutputStrings: plistsOutputStrings)
                if let pluralsFile = generatePluralsFile(pluralKeyValues: pluralKeyValues) {
                    saveToLocalizableStringsDictFile(outputDir: args.outputDir, lang: lang, pluralsFile: pluralsFile)
                }
            } else {
                saveToAndroidStringsFile(outputDir: args.outputDir, lang: lang, outputString: outputString as String)
            }
                
        }
        print("Finished in " + String(format: "%.2f", -nowDate.timeIntervalSinceNow) + " seconds.")
    }
    
    private func appendLineToOutputAndroid(keyString: String, valueString: String, defaultOutput: NSMutableString, plistOutputs: Dictionary<String, Any>, config: NSDictionary?) {
        if valueString.count > 0 {
            let line = String(format:"<string name=\"%@\">%@</string>\n", keyString, valueString)
            defaultOutput.append(line)
        }
    }
    
    private func appendLineToOutputiOS(keyString: String, valueString: String, defaultOutput: NSMutableString, plistOutputs: Dictionary<String, Any>, config: NSDictionary?) {
        var addedToPlist = false
        for plistName in config?.allKeys ?? [] {
            let plistConfig = config!.object(forKey: plistName) as! NSDictionary
            for key in plistConfig.allKeys {
                if (key as! String) == keyString {
                    let line = String(format:"\"%@\" = \"%@\";\n\n", plistConfig.object(forKey: key) as! String, valueString)
                    (plistOutputs[(plistName as! String)] as! NSMutableString).append(line)
                    addedToPlist = true
                }
            }
        }
        if !addedToPlist {
            if valueString.count > 0 {
                let line = String(format:"\"%@\" = \"%@\";\n\n", keyString, valueString)
                defaultOutput.append(line)
            }
        }
    }
    
    func readColumnWithId(_ columnId: String, xlsx: XlsxFile, args: AppArguments!) -> [String] {
        var result = [String]()
        for (index, row) in xlsx.enumerated() {
            if index == 0 {
                continue
            }
            // print("readColumnWithId \"\(index)\" row \"\(row)\" ... ")
            let value = row[columnId] ?? ""
            if (args.platform=="ios") {
                result.append(cleanValueiOS(input: value))
            } else {
                result.append(cleanValueAndroid(input: value))
            }
        }
        return result
    }

    private func cleanValueAndroid(input: String) -> String {
        var output = input
        output = output.replacingOccurrences(of: "\"", with: "\\\"")

        var i = 1 // i will be the increasing parameter number throughout the string

        // Convert bare %s string value
        while let range = output.range(of: "%s", options: .regularExpression) {
            output = output.replacingCharacters(in: range, with: String(format: "%%%d$s", i))
            i += 1
        }

        // Convert bare %d decimal value
        while let range = output.range(of: "%d", options: .regularExpression) {
            output = output.replacingCharacters(in: range, with: String(format: "%%%d$d", i))
            i += 1
        }

        // Some generic conversions - these might not always be true in current strings...
        output = output.replacingOccurrences(of: "%1$@", with: "%1$s")
        output = output.replacingOccurrences(of: "%2$@", with: "%2$s")
        
        output = output.replacingOccurrences(of: "%@", with: "%1$s")
        
        
        // Convert bare %@ floating point with formatted xx.x%
//        while let range = output.range(of: "%@", options: .regularExpression) {
//            output = output.replacingCharacters(in: range, with: String(format: "%.1f%", i))
//            i += 1
//        }
//        output = output.replacingOccurrences(of: "%@", with: "%.1f%%")
                
        
        return output
    }
    
    private func cleanValueiOS(input: String) -> String {
        var output = input
        output = output.replacingOccurrences(of: "\"", with: "\\\"")

        var i = 1
        while let range = output.range(of: "%s", options: .regularExpression) {
            output = output.replacingCharacters(in: range, with: String(format: "%%%d$@", i))
            i += 1
        }
        
        for i in 1..<10 {
            output = output.replacingOccurrences(of: String(format: "%%%d$s", i), with: String(format: "%%%d$@", i))
        }
        
        output = output.replacingOccurrences(of: "(%.1f%)%", with: "%@")
        output = output.replacingOccurrences(of: "%.1f %", with: "%@")
        
        return output
    }
    
    private func isLangFormatValid(_ lang: String?) -> Bool {
        guard let lang else {
            return false
        }
        // print("isLangFormatValid :\"\(lang)\" ")
        if lang.count == 2 {
            return true
        }
        if lang.count == 5 {
            let components = lang.components(separatedBy: "-")
            return components.count == 2 && components[0].count == 2 && components[1].count == 2
        }
        return false
    }
}
