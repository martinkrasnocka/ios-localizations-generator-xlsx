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
    let version = "2.56"
    
    override init() {
//        csvReader = CsvReader()
        xlsxReader = XlsxReader()
    }
    
    func generate(args: AppArguments!) {
        print("LocsUtil version: \(version). Homepage: https://github.com/martinkrasnocka/LocsUtil\n")
        
        if args == nil {
            AppArguments.printNoArgumetsHelp()
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
                    appendLineToOutputAndroid(keyString: keyString, valueString: valueString, defaultOutput: outputString, plistOutputs: plistsOutputStrings, config: config, disablePlurals: args.disablePlurals)
                }
            }
            
            if (args.platform=="ios") {
                saveToLocalizableStringsFile(outputDir: args.outputDir, lang: lang, outputString: outputString as String)
                saveToInfoPlistFile(outputDir: args.outputDir, lang: lang, plistsOutputStrings: plistsOutputStrings)
                if !args.disablePlurals {
                    if let pluralsFile = generatePluralsFileiOS(pluralKeyValues: pluralKeyValues) {
                        saveToLocalizableStringsDictFile(outputDir: args.outputDir, lang: lang, pluralsFile: pluralsFile)
                    }
                }
            } else {
                if !args.disablePlurals {
                    if let pluralsFile = generatePluralsFileAndroid(pluralKeyValues: pluralKeyValues) {
                        outputString.append(pluralsFile)
                    }
                }
                saveToAndroidStringsFile(outputDir: args.outputDir, lang: lang, outputString: outputString as String)
            }
                
        }
        print("Finished in " + String(format: "%.2f", -nowDate.timeIntervalSinceNow) + " seconds.")
    }
    
    private func appendLineToOutputAndroid(keyString: String, valueString: String, defaultOutput: NSMutableString, plistOutputs: Dictionary<String, Any>, config: NSDictionary?, disablePlurals: Bool) {
        guard shouldEmitStandaloneAndroidString(key: keyString, disablePlurals: disablePlurals) else {
            return
        }
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
        
        // General character esacping needed for Android
        output = output.replacingOccurrences(of: "&", with: "&amp;")
            
        // Remove escaped ones first...
        output = output.replacingOccurrences(of: "\\'", with: "'")
        // ... to then just be able to do all of them blindly and catch cases of ones that were missed off in the sheet
        output = output.replacingOccurrences(of: "'", with: "\\\'")
                
        // Replace "..." with single character "..." &#8230;
        output = output.replacingOccurrences(of: "...", with: "&#8230;")
        
        // Escape any trailing percentage symbol that is followed by a space with unicode character to avoid breaking based on following characters
        output = output.replacingOccurrences(of: "% ", with: "\\u0025 ")
        
        // Replace newlines with \n string
        output = output.replacingOccurrences(of: "\n", with: "\\n")
        
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
        
        // Numerate multiple strings
        while let range = output.range(of: "%@", options: .regularExpression) {
            output = output.replacingCharacters(in: range, with: String(format: "%%%d$s", i))
            i += 1
        }
        
        // Some generic conversions - these might not always be true in current strings...
        output = output.replacingOccurrences(of: "%1$@", with: "%1$s")
        output = output.replacingOccurrences(of: "%2$@", with: "%2$s")

        // To catch the individual plural strings that have some parameters in iOS format
        output = output.replacingOccurrences(of: "%1d", with: "%1$d")
        output = output.replacingOccurrences(of: "%2d", with: "%2$d")
        output = output.replacingOccurrences(of: "%1s", with: "%1$s")
        output = output.replacingOccurrences(of: "%2s", with: "%2$s")
        
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
        
        for i in 1..<10 {
            output = output.replacingOccurrences(of: String(format: "%%%ds", i), with: String(format: "%%%d$@", i))
        }
        for i in 1..<10 {
            output = output.replacingOccurrences(of: String(format: "%%%dd", i), with: String(format: "%%%d$d", i))
        }
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
