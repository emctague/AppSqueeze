//
//  ViewController.swift
//  AppSqueeze
//
//  Created by Ethan McTague on 2019-09-03.
//  Copyright © 2019 Ethan McTague. All rights reserved.
//

import Cocoa

extension NSImage {
    func writeToFile(file: String, atomically: Bool, usingType type: NSBitmapImageRep.FileType) {
        let properties = [NSBitmapImageRep.PropertyKey.compressionFactor: 1.0]
        guard
            let imageData = tiffRepresentation,
            let imageRep = NSBitmapImageRep(data: imageData),
            let fileData = imageRep.representation(using: type, properties: properties) else {
                return
        }
        do {
            try fileData.write(to: URL(fileURLWithPath: file))
        } catch {
        }
    }
}

func execute(_ cmd: [String]) {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = cmd
    task.launch()
    task.waitUntilExit()
}

class ViewController: NSViewController {

    @IBOutlet weak var appIcon: NSImageView!
    @IBOutlet weak var appName: NSTextField!
    @IBOutlet weak var appDeveloper: NSTextField!
    @IBOutlet weak var appVersion: NSTextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }


    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func onClickCreate(_ sender: NSButton) {
        let realAppName = appName.stringValue.trimmingCharacters(in: .whitespaces)
        let realAppVersion = appVersion.stringValue.trimmingCharacters(in: .whitespaces)
        let realAppDeveloper = appDeveloper.stringValue.trimmingCharacters(in: .whitespaces)
        if (
            realAppName.isEmpty  ||
            realAppVersion.isEmpty ||
            realAppDeveloper.isEmpty ||
                appIcon.image == nil) {
            let alert = NSAlert()
            alert.messageText = "Missing Values!"
            alert.runModal()
            
            return
        }
        
        let dialog = NSOpenPanel()
        dialog.title = "Choose an Executable File"
        dialog.showsResizeIndicator = true
        dialog.canChooseDirectories = false
        dialog.canChooseFiles = true
        dialog.showsHiddenFiles = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowsOtherFileTypes = true
        
        if (dialog.runModal() != NSApplication.ModalResponse.OK) {
            return
        }
        
        let exeResult = dialog.url!
        let exePath = exeResult.path

        dialog.title = "Choose a Destination"
        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.canCreateDirectories = true
        
        if (dialog.runModal() != NSApplication.ModalResponse.OK) {
            return
        }
        
        let appResult = dialog.url!
        let appPath = appResult.path + "/" + realAppName + ".app"
        let destExePath = appPath + "/" + realAppName
        
        let nowsAppName = realAppName.replacingOccurrences(of: " ", with: "")
        
        let plistSource = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>\(realAppName)</string>
    <key>CFBundleIconFile</key>
    <string>icon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>bundled-app-\(nowsAppName)</string>
    <key>CFBundleName</key>
    <string>\(realAppName)</string>
    <key>CFBundleShortVersionString</key>
    <string>\(realAppVersion)</string>
</dict>
</plist>
"""
        
        let iconsetPath = appPath + "/icons.iconset"
        let iconMaster = iconsetPath + "/icon_master.png"
    
        do {
            let plistUrl = URL(fileURLWithPath: appPath + "/Info.plist")

            execute(["install", "-d", "-m775", exePath, destExePath])

            try plistSource.write(to: plistUrl, atomically: false, encoding: .utf8)
            
            execute(["mkdir", "-p", iconsetPath])
            
            appIcon.image!.writeToFile(file: iconsetPath + "/icon_master.png", atomically: true, usingType: NSBitmapImageRep.FileType.png)
            
            execute(["sips", "-z", "1024", "1024", iconMaster, "--out", iconsetPath + "/icon_1024x1024.png"])
            execute(["sips", "-z", "1024", "1024", iconMaster, "--out", iconsetPath + "/icon_512x512@2x.png"])
            execute(["sips", "-z", "512", "512", iconMaster, "--out", iconsetPath + "/icon_512x512.png"])
            execute(["sips", "-z", "512", "512", iconMaster, "--out", iconsetPath + "/icon_256x256@2x.png"])
            execute(["sips", "-z", "256", "256", iconMaster, "--out", iconsetPath + "/icon_256x256.png"])
            execute(["sips", "-z", "256", "256", iconMaster, "--out", iconsetPath + "/icon_128x128@2x.png"])
            execute(["sips", "-z", "64", "64", iconMaster, "--out", iconsetPath + "/icon_64x64.png"])
            execute(["sips", "-z", "64", "64", iconMaster, "--out", iconsetPath + "/icon_32x32@2x.png"])
            execute(["sips", "-z", "32", "32", iconMaster, "--out", iconsetPath + "/icon_32x32.png"])
            execute(["sips", "-z", "32", "32", iconMaster, "--out", iconsetPath + "/icon_16x16@2x.png"])
            execute(["rm", iconMaster])
            execute(["iconutil", "-c", "icns", "-o", appPath + "/icon.icns", iconsetPath ])
            execute(["rm", "-rf", iconsetPath])
            
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return
        }
        
    }
}
