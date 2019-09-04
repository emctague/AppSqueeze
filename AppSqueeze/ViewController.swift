//
//  ViewController.swift
//  AppSqueeze
//
//  Created by Ethan McTague on 2019-09-03.
//  Copyright © 2019 Ethan McTague. All rights reserved.
//

import Cocoa


extension NSImage {
    
    // This extension allows an NSImage to be saved to the disk
    // This is slightly modernized from the version found here:
    // https://gist.github.com/westerlund/e1b99e21615bb18bc380
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


// Executes a command on the shell with the given command and argument strings
func execute(_ cmd: [String]) {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = cmd
    task.launch()
    task.waitUntilExit()
}


// PList structure generated for a given app
struct AppPList:Codable {
    var CFBundleExecutable:String
    var CFBundleIconFile:String
    var CFBundleIdentifier:String
    var CFBundleName:String
    var CFBundleShortVersionString:String
}


class ViewController: NSViewController {
    @IBOutlet weak var appIcon: NSImageView!
    @IBOutlet weak var appName: NSTextField!
    @IBOutlet weak var appDeveloper: NSTextField!
    @IBOutlet weak var appVersion: NSTextField!
    @IBOutlet weak var roundedView: NSVisualEffectView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // When the icon is clicked, the user should be able to choose a new one
    @IBAction func onIconClick(_ sender: NSClickGestureRecognizer) {
        let dialog = NSOpenPanel()
        dialog.title = "Choose an Icon File"
        dialog.showsResizeIndicator = true
        dialog.canChooseDirectories = false
        dialog.canChooseFiles = true
        dialog.showsHiddenFiles = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["png", "jpg", "ico", "icns", "bmp"];
        
        if (dialog.runModal() != NSApplication.ModalResponse.OK) {
            return
        }
        
        let image = NSImage.init(byReferencingFile: dialog.url!.path)
        
        if (image == nil) {
            let alert = NSAlert()
            alert.messageText = "That file can't be used as an icon."
            alert.runModal()
            return
        }
        
        appIcon.image = image
    }
    
    override func viewWillAppear() {
        // This is all trying to make the icon view rounded.
        // None of it works!
        roundedView.wantsLayer = true
        roundedView.layer!.cornerRadius = 20.0
        roundedView.layer!.masksToBounds = true
        roundedView.layer!.maskedCorners = CACornerMask.init([CACornerMask.layerMaxXMaxYCorner, CACornerMask.layerMaxXMinYCorner, CACornerMask.layerMinXMaxYCorner, CACornerMask.layerMinXMinYCorner])
    }


    override var representedObject: Any? {
        didSet {
        }
    }

    // Handles the clicking of the 'create' button, creating the app.
    @IBAction func onClickCreate(_ sender: NSButton) {
        // Process the provided input by trimming whitespace
        let realAppName = appName.stringValue.trimmingCharacters(in: .whitespaces)
        let realAppVersion = appVersion.stringValue.trimmingCharacters(in: .whitespaces)
        let realAppDeveloper = appDeveloper.stringValue.trimmingCharacters(in: .whitespaces)
        let compactAppName = realAppName.replacingOccurrences(of: " ", with: "")

        
        // Ensure the user hasn't left anything blank
        if (realAppName.isEmpty || realAppVersion.isEmpty || realAppDeveloper.isEmpty || appIcon.image == nil) {
            let alert = NSAlert()
            alert.messageText = "Missing Values! Make sure you didn't leave any fields blank."
            alert.runModal()
            return
        }
        
        
        // Prompt the user to choose the executable for the app
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
        
        // Get the path of the selected executable
        let exePath = dialog.url!.path

        
        // Prompt the user for a folder to put the app in
        dialog.title = "Choose a Destination"
        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.canCreateDirectories = true
        
        if (dialog.runModal() != NSApplication.ModalResponse.OK) {
            return
        }
        
        // Build the path of the app, and other derivative paths
        let appPath = dialog.url!.path + "/" + realAppName + ".app"
        let destExePath = appPath + "/" + realAppName
        let iconsetPath = appPath + "/icons.iconset"
        let iconMaster = iconsetPath + "/icon_master.png"
        
        
        // Create the app path, icon set path, etc.
        execute(["mkdir", "-p", iconsetPath])
    
        
        // Copy the executable into the app directory
        execute(["install", "-m775", exePath, destExePath])
        
        
        // Save the app icon to a file
        appIcon.image!.writeToFile(file: iconsetPath + "/icon_master.png", atomically: true, usingType: NSBitmapImageRep.FileType.png)
        
        
        // Use SIPS to generate resized images, and then iconutil to generate an ICNS icon file
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
        
        
        // Generate and write a PList file
        let prefs = AppPList(
            CFBundleExecutable: realAppName,
            CFBundleIconFile: "icon.icns",
            CFBundleIdentifier: "bundled-app-" + compactAppName,
            CFBundleName: realAppName,
            CFBundleShortVersionString: realAppVersion);
        
        let plistUrl = URL(fileURLWithPath: appPath + "/Info.plist")
        let encoder = PropertyListEncoder()
        
        do {
            let data = try encoder.encode(prefs)
            try data.write(to: plistUrl)
        } catch {
            return
        }
        
    }
}
