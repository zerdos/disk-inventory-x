//
//  StartupPanelController.h
//  Disk Inventory X
//
//  Redesigned startup panel with drag-and-drop support and folder shortcuts.
//
//  Copyright (C) 2003-2024 Tjark Derlien.
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 3
//  of the License, or any later version.
//

#import <Cocoa/Cocoa.h>
#import "FolderDropView.h"

@interface StartupPanelController : NSObject <FolderDropViewDelegate>
{
    NSMutableArray *_volumes;
    NSMutableArray *_progressIndicators;

    IBOutlet NSWindow *_startupPanel;
    IBOutlet FolderDropView *_folderDropView;
    IBOutlet NSTableView *_volumesTableView;
    IBOutlet NSButton *_openVolumeButton;
    IBOutlet NSArrayController *_volumesController;

    // Shortcut buttons
    IBOutlet NSButton *_homeButton;
    IBOutlet NSButton *_downloadsButton;
    IBOutlet NSButton *_desktopButton;
    IBOutlet NSButton *_documentsButton;
    IBOutlet NSButton *_applicationsButton;

    unsigned long long _maxVolumeSize;
}

+ (StartupPanelController *) sharedController;

- (BOOL) panelIsVisible;
- (void) showPanel;
- (NSWindow *) panel;

- (NSArray *) volumes;

// Actions
- (IBAction) openVolume:(id)sender;
- (IBAction) browseForFolder:(id)sender;
- (IBAction) openHomeFolder:(id)sender;
- (IBAction) openDownloadsFolder:(id)sender;
- (IBAction) openDesktopFolder:(id)sender;
- (IBAction) openDocumentsFolder:(id)sender;
- (IBAction) openApplicationsFolder:(id)sender;

@end
