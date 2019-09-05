//
//  ViewController.swift
//  AppSqueeze
//
//  Created by Ethan McTague on 2019-09-03.
//  Copyright © 2019 Ethan McTague. All rights reserved.
//

import Cocoa

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
                try AppMaker.createApp(realAppName, realAppVersion, realAppDeveloper, appIcon.image, exePath, appPath)
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
