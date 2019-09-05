//
//  AppMaker.swift
//  AppSqueeze
//
//  Created by Ethan McTague on 2019-09-05.
//  Copyright © 2019 Ethan McTague. All rights reserved.
//

import Cocoa


// The AppMaker utility
class AppMaker {
    
    // PList structure generated for a given app
    struct AppPList:Codable {
        var CFBundleExecutable:String
        var CFBundleIconFile:String
        var CFBundleIdentifier:String
        var CFBundleName:String
        var CFBundleShortVersionString:String
    }
    
    // AppMaker error states
    public enum AppMakerError: LocalizedError {
        case missingValues
        case badImage
        
        public var errorDescription: String? {
            switch self {
            case .missingValues:
                return NSLocalizedString("Not all properties were given a value!", comment: "Missing Values")
            case .badImage:
                return NSLocalizedString("Unable to scale and save the icon!", comment: "Icon Creation Failed")
            }
        }
    }
    
    // Executes a command on the shell with the given command and argument strings
    static func execute(_ cmd: [String]) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = cmd
        task.launch()
        task.waitUntilExit()
    }
    
    static func createApp (_ appName: String, _ appVersion: String, _ appDeveloper: String, _ appIcon: NSImage?, _ exeSource: URL, _ appDir: URL) throws {
        // Ensure the user hasn't left anything blank
        if (appName.isEmpty || appVersion.isEmpty || appDeveloper.isEmpty || appIcon == nil) {
            throw AppMakerError.missingValues
        }
        
        let compactAppName = appName.replacingOccurrences(of: " ", with: "")
        let appDestination = appDir.appendingPathComponent(appName + ".app")
        let exeDestination = appDestination.appendingPathComponent(appName)
        let iconsetPath = appDestination.appendingPathComponent("icons.iconset")
        let iconPath = appDestination.appendingPathComponent("icon.icns")
        let plistPath = appDestination.appendingPathComponent("Info.plist")
        
        // Create the app path and iconset path
        try FileManager.default.createDirectory(at: iconsetPath, withIntermediateDirectories: true, attributes: nil)
        
        // Copy the executable and set its permissions
        try FileManager.default.copyItem(at: exeSource, to: exeDestination)
        try FileManager.default.setAttributes([ FileAttributeKey.posixPermissions: 775 ], ofItemAtPath: exeDestination.path)
        
        // Save the app icon at different sizes to various files
        for i in [32, 64, 256, 512, 1024] {
            let imgOut = iconsetPath.appendingPathComponent("icon_\(i)x\(i).png")
            let hidpiOut = iconsetPath.appendingPathComponent("icon_\(i/2)x\(i/2)@2.png")
            
            try appIcon!.writeToFile(file: imgOut,
                                     usingType: NSBitmapImageRep.FileType.png,
                                     size: NSSize(width: i, height: i))
            
            try FileManager.default.copyItem(at: imgOut, to: hidpiOut)
        }
        
        // Generate an icon using iconutil and then remove the original icons
        execute(["iconutil", "-c", "icns", "-o", iconPath.path, iconsetPath.path ])
        try FileManager.default.removeItem(at: iconsetPath)
        
        // Generate and write a PList file
        let prefs = AppPList(
            CFBundleExecutable: appName,
            CFBundleIconFile: "icon.icns",
            CFBundleIdentifier: "bundled-app-" + compactAppName,
            CFBundleName: appName,
            CFBundleShortVersionString: appVersion);
        
        let encoder = PropertyListEncoder()
        
        do {
            let data = try encoder.encode(prefs)
            try data.write(to: plistPath)
        } catch {
            return
        }
    }

    
}


extension NSImage {
    
    // This extension allows an NSImage to be saved to the disk at a given size
    func writeToFile(file: URL, usingType type: NSBitmapImageRep.FileType, size inSize: NSSize) throws {
        let properties = [NSBitmapImageRep.PropertyKey.compressionFactor: 1.0]
        
        // Generate a scaled image
        let newImage = NSImage(size: inSize)
        newImage.lockFocus()
        draw(in: NSRect(x: 0, y: 0, width: inSize.width, height: inSize.height),
             from: NSRect(x: 0, y: 0, width: size.width, height: size.height),
             operation: NSCompositingOperation.sourceOver,
             fraction: CGFloat(1))
        newImage.unlockFocus()
        newImage.size = inSize
        
        // Save the new image
        guard
            let imageData = newImage.tiffRepresentation,
            let imageRep = NSBitmapImageRep(data: imageData),
            let fileData = imageRep.representation(using: type, properties: properties) else {
                throw AppMaker.AppMakerError.badImage
        }
        
        try fileData.write(to: file)
    }
}
