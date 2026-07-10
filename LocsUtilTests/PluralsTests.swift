//
//  PluralsTests.swift
//  LocsUtilTests
//
//  Created by Martin Krasnocka on 31/08/2023.
//  Copyright © 2023 Martin Krasnocka. All rights reserved.
//

import XCTest

final class PluralsTests: XCTestCase {
    
    let inputPluralsSuite = [
        ["%d fejl og mangler", "%d defekt", "%d fejl og mangler", "%d fejl og mangler", "%d fejl og mangler", "%d fejl og mangler"],
        ["%d fejl fundet", "%d fejl fundet", "%d fejl fundet", "%d fejl fundet", "%d fejl fundet", "%d fejl fundet"],
        ["Klassificer %d rejser", "Klassificer %d rejse", "Klassificer %d rejser", "Klassificering af %d rejser", "Klassificering af %d rejser", "klassificere %d rejser"],
    ]
    
    let expactedPluralResults = [
        ("%d %#@plural@", ["fejl og mangler", "defekt", "fejl og mangler", "fejl og mangler", "fejl og mangler", "fejl og mangler"]),
        ("%d fejl fundet%#@plural@", ["", "", "", "", "", ""]),
        ("%#@plural@ %d rejser", ["Klassificer", "Klassificer", "Klassificer", "Klassificering", "Klassificering", "klassificere"])
    ]
    
    func testPlurals() throws {
        for i in 0..<inputPluralsSuite.count {
            if let computedPlurals = inputPluralsSuite[i].computeFormatString() {
                XCTAssertEqual(computedPlurals.0, expactedPluralResults[i].0)
                XCTAssertEqual(computedPlurals.1, expactedPluralResults[i].1)
                //                print("(\"\(computedPlurals.0)\", [\(computedPlurals.1.map { "\"\($0)\"" }.joined(separator: ", ") )]),")
            } else {
                XCTFail("Unable to compute plurals")
            }
        }
    }
    
    func testStandaloneAndroidStringEmissionForPluralKeysWhenPluralsEnabled() {
        XCTAssertFalse(shouldEmitStandaloneAndroidString(key: "assigned_jobs_one", disablePlurals: false))
        XCTAssertFalse(shouldEmitStandaloneAndroidString(key: "assigned_jobs_other", disablePlurals: false))
        XCTAssertTrue(shouldEmitStandaloneAndroidString(key: "assigned_jobs", disablePlurals: false))
    }
    
    func testStandaloneAndroidStringEmissionWhenPluralsDisabled() {
        XCTAssertTrue(shouldEmitStandaloneAndroidString(key: "assigned_jobs_one", disablePlurals: true))
        XCTAssertTrue(shouldEmitStandaloneAndroidString(key: "assigned_jobs", disablePlurals: true))
    }
}
