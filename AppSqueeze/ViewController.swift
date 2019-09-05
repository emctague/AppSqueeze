//
//  ViewController.swift
//  AppSqueeze
//
//  Created by Ethan McTague on 2019-09-03.
//  Copyright © 2019 Ethan McTague. All rights reserved.
//

import Cocoa

public enum AppMakerError: Error {
    case missingValues
    case badImage
}

extension AppMakerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingValues:
            return NSLocalizedString("Not all properties were given a value!", comment: "Missing Values")
        case .badImage:
            return NSLocalizedString("Unable to scale and save the icon!", comment: "Icon Creation Failed")
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
                throw AppMakerError.badImage
        }
        
        try fileData.write(to: file)
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
        if let iconPath = doOpen("Choose an Icon File", ["png", "jpg", "ico", "icns", "bmp"], false) {
            let image = NSImage.init(byReferencing: iconPath)
            
            if (!image.isValid) {
                let alert = NSAlert()
                alert.messageText = "That file can't be used as an icon."
                alert.runModal()
                return
            }
            
            appIcon.image = image
        }
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
        
        if
            let exePath = doOpen("Choose an Executable File", nil, false),
            let appPath = doOpen("Choose a Destination", nil, true) {
            do {
                try createApp(realAppName, realAppVersion, realAppDeveloper, appIcon.image, exePath, appPath)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
                return
            }
            
            let alert = NSAlert()
            alert.informativeText = "Done!"
            alert.messageText = "The app has been created!"
            alert.runModal()
        }
    }
    
    func createApp (_ appName: String, _ appVersion: String, _ appDeveloper: String, _ appIcon: NSImage?, _ exeSource: URL, _ appDir: URL) throws {
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
    
    // Launch a file-opening dialog with the given title, file extensions (or any extension if nil),
    // and optionally for selecting directories instead of files.
    func doOpen(_ title: String, _ extensions: [String]?, _ chooseDirectory: Bool) -> URL?
    {
        let dialog = NSOpenPanel()
        dialog.title = title
        dialog.showsResizeIndicator = true
        dialog.canChooseDirectories = chooseDirectory
        dialog.canChooseFiles = !chooseDirectory
        dialog.showsHiddenFiles = false
        dialog.canCreateDirectories = true
        dialog.allowsMultipleSelection = false
        dialog.allowsOtherFileTypes = (extensions == nil)
        
        if (extensions != nil) {
            dialog.allowedFileTypes = extensions!;
        }
        
        if (dialog.runModal() != NSApplication.ModalResponse.OK) {
            return nil
        }
        
        return dialog.url
    }

}
