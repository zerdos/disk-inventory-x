//
//  FolderDropView.h
//  Disk Inventory X
//
//  Custom view supporting drag-and-drop of folders for analysis.
//
//  Copyright (C) 2003-2024 Tjark Derlien.
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 3
//  of the License, or any later version.
//

#import <Cocoa/Cocoa.h>

@protocol FolderDropViewDelegate;

@interface FolderDropView : NSView
{
    BOOL _isDragHighlighted;
    id<FolderDropViewDelegate> _delegate;
}

@property (assign) IBOutlet id<FolderDropViewDelegate> delegate;

@end

@protocol FolderDropViewDelegate <NSObject>

- (void) folderDropView:(FolderDropView *)view didReceiveFolderURLs:(NSArray<NSURL *> *)urls;

@end
