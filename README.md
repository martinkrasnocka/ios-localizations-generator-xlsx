# LocsUtil

LocsUtil is a simple utility for generating string resources for iOS projects. It uses XLSX document as an input, so it makes it very flexible to distribute it to managers, agencies, etc.

## Features

- MacOS command line application
- Generates string resource files for iOS project and Android strings.xml resources
- Supports localising permissions plist
- Uses XLSX document as an input
- Works with Google spreadsheets when exported (or synced) as an excel document
- MIT license

## Prerequisites
- Supports MacOS 10.9 or higher
- Needs xcodebuild to be installed (XCode command line tools)

## Installation and Setup

1. Run ./build.sh located in the root directory. Compiled executable will be placed under bin/locsutil.
```
<cd into project root directory>
./build.sh
```
2. Copy bin/locsutil to /usr/bin/locsutil.
```
sudo cp bin/locsutil /usr/local/bin/locsutil
```
3. Make it executable.
```
chmod +x /usr/local/bin/locsutil
```

## Usage & Examples

### Running
```
locsutil <platform> <inputXslxFile> <outputDir> <configPlist>

Parameters:
    platform - ios or android platform
    inputXslxFile - path to XLSX document
    outputDir - path to output dir
    configPlist - path to configuration plist file (optional)
```
See example.sh

### XLSX document format
- LocsUtil expects to find resources in the first sheet.
- Language identifiers are expected to be on the first line. A1 cell is skipped, as this column serves for keys. From B1, lanugages should be speficied, like "EN", "FR", etc.
- Translation keys are specified in the A column.

If you want to change this configuration, alter these lines in LocsGenerator.swift and rebuild.
```
let langRowIndex = 0 // Language definitions - row index in XSLSX document
let keyColumnId = "A" // Key definitions - column index in XSLSX document
```
Example XSLX document can be found at LocsUtil/input/localizations.xlsx

### Config plist (optional)
Use .plist file to generate additional string resource files, for example for localising Info.plist strings.

Example:
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>InfoPlist</key>
    <dict>
        <key>track_journey_permission_location</key>
        <string>NSLocationAlwaysAndWhenInUseUsageDescription</string>
        <key>permission_location_services_explanation</key>
        <string>NSLocationWhenInUseUsageDescription</string>
        <key>permission_camera_explanation</key>
        <string>NSCameraUsageDescription</string>
        <key>permission_photo_library_explanation</key>
        <string>NSPhotoLibraryUsageDescription</string>
        <key>permission_add_photo_to_library</key>
        <string>NSPhotoLibraryAddUsageDescription</string>
    </dict>
</dict>
</plist>
```
Keys specified here will be put into "InfoPlist.plist" file. For example, "permission_location_services_explanation" will result into:
```
"NSLocationWhenInUseUsageDescription" = "Some translation";
```
Example config can be found in LocsUtil/input/config.plist

## Plurals
Plurals plist files (Localizable.stringsdict) will be generated automatically if you follow these rules:

- You must provide six variants of the same translation with these suffixes:
```
"_zero", "_one", "_two", "_few", "_many", "_other"
```
Example:
```
assigned_jobs_zero = 'You have %d new assigned jobs'
assigned_jobs_one = 'You have %d new assigned job'
assigned_jobs_two = 'You have %d new assigned jobs'
assigned_jobs_few = 'You have %d new assigned jobs'
assigned_jobs_many = 'You have %d new assigned jobs'
assigned_jobs_other = 'You have %d new assigned jobs'
```
Usage in code:
```
let localisedStringFormat = NSLocalizedString("assigned_jobs", tableName: nil, bundle: Bundle.main, value: "", comment: "")
let pluralString = String.localizedStringWithFormat(localisedStringFormat, assignedJobCount, assignedJobCount))
```
Note:
The first 'assignedJobCount' applies to the first %d format string and the second to the plural word itself.

## Pro tip
Set the output directory directly to your project. Then it is easy to see changes from the XLXS in your version control tool.

## Removal
```
rm /usr/local/bin/locsutil
```

## Xcode 14.3 archiving issue
If you are having this issue during the build process:
```
ld: file not found: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/arc/libarclite_macosx.a
```
follow these steps:
```
cd /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib
git clone https://github.com/kamyarelyasi/Libarclite-Files.git
sudo chmod +x *
ln -s Libarclite-Files arc
```

## Third-Party Libraries

|Project|License|Comments|
|-|-|-|
|[ZipArchive](https://code.google.com/archive/p/ziparchive/)|[MIT](http://www.opensource.org/licenses/mit-license.php)|ZipArchive is an Objective-C class to compress or uncompress zip files, which is base on open source code "MiniZip".|
[TouchXML](https://github.com/TouchCode/TouchXML)|[FreeBSD License](https://www.freebsd.org/copyright/freebsd-license.html)|TouchXML is a lightweight replacement for Cocoa's NSXML* cluster of classes. It is based on the commonly available Open Source libxml2 library.|

## License

[LocsUtil](https://github.com/martinkrasnocka/LocsUtil) is protected under the [MIT license](http://www.opensource.org/licenses/mit-license.php)

Copyright 2023 Martin Krasnočka

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

