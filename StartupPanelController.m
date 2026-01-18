//
//  StartupPanelController.m
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

#import "StartupPanelController.h"
#import "FileSizeFormatter.h"
#import "VolumeNameTransformer.h"
#import "VolumeUsageTransformer.h"
#import "NSURL-Extensions.h"

@interface StartupPanelController(Private)

- (void) rebuildVolumesArray;
- (void) rebuildProgressIndicatorArray;
- (void) onVolumesChanged:(NSNotification *)notification;
- (void) openFolderAtPath:(NSString *)path;
- (void) openFolderAtSearchPath:(NSSearchPathDirectory)directory;
- (void) configureShortcutButtons;

@end


@implementation StartupPanelController

+ (StartupPanelController *) sharedController
{
    static StartupPanelController *controller = nil;

    if (controller == nil)
        controller = [[StartupPanelController alloc] init];

    return controller;
}

- (id) init
{
    self = [super init];
    if (self == nil)
        return nil;

    _maxVolumeSize = 0;

    // Register volume transformers (before Nib is loaded)
    [NSValueTransformer setValueTransformer:[VolumeNameTransformer transformer] forName:@"volumeNameTransformer"];
    [NSValueTransformer setValueTransformer:[VolumeUsageTransformer transformer] forName:@"volumeUsageTransformer"];

    // Register for volume mount/unmount notifications
    NSNotificationCenter *wsNotiCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
    [wsNotiCenter addObserver:self
                     selector:@selector(onVolumesChanged:)
                         name:NSWorkspaceDidMountNotification
                       object:nil];

    [wsNotiCenter addObserver:self
                     selector:@selector(onVolumesChanged:)
                         name:NSWorkspaceDidUnmountNotification
                       object:nil];

    [wsNotiCenter addObserver:self
                     selector:@selector(onVolumesChanged:)
                         name:NSWorkspaceDidRenameVolumeNotification
                       object:nil];

    [self rebuildVolumesArray];

    // Load Nib with startup panel
    if (![NSBundle loadNibNamed:@"StartupPanel" owner:self])
    {
        [self release];
        return nil;
    }

    // Configure table view
    [_volumesTableView setDoubleAction:@selector(openVolume:)];

    // Set FileSizeFormatter for size columns
    FileSizeFormatter *sizeFormatter = [[[FileSizeFormatter alloc] init] autorelease];
    [[[_volumesTableView tableColumnWithIdentifier:@"totalSize"] dataCell] setFormatter:sizeFormatter];
    [[[_volumesTableView tableColumnWithIdentifier:@"freeBytes"] dataCell] setFormatter:sizeFormatter];

    // Configure shortcut buttons
    [self configureShortcutButtons];

    // Set drop view delegate
    [_folderDropView setDelegate:self];

    [_startupPanel makeFirstResponder:_volumesTableView];

    return self;
}

- (void) dealloc
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

    [_volumes release];
    [_progressIndicators release];

    [super dealloc];
}

- (NSArray *) volumes
{
    return _volumes;
}

#pragma mark - Panel Management

- (BOOL) panelIsVisible
{
    return [[self panel] isVisible];
}

- (void) showPanel
{
    [[self panel] orderFront:nil];
}

- (NSWindow *) panel
{
    return _startupPanel;
}

#pragma mark - Actions

- (IBAction) openVolume:(id)sender
{
    NSIndexSet *selectedIndexes = [_volumesTableView selectedRowIndexes];
    NSUInteger index = [selectedIndexes firstIndex];

    while (index != NSNotFound)
    {
        NSURL *volume = [[_volumes objectAtIndex:index] objectForKey:@"volume"];
        if ([volume stillExists])
        {
            [self openFolderAtPath:[volume path]];
        }

        index = [selectedIndexes indexGreaterThanIndex:index];
    }
}

- (IBAction) browseForFolder:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel setTreatsFilePackagesAsDirectories:YES];
    [openPanel setPrompt:NSLocalizedString(@"Analyze", @"")];
    [openPanel setMessage:NSLocalizedString(@"Select a folder to analyze", @"")];

    [openPanel beginSheetModalForWindow:_startupPanel completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK)
        {
            for (NSURL *url in [openPanel URLs])
            {
                [self openFolderAtPath:[url path]];
            }
        }
    }];
}

- (IBAction) openHomeFolder:(id)sender
{
    [self openFolderAtSearchPath:NSUserDirectory];
}

- (IBAction) openDownloadsFolder:(id)sender
{
    [self openFolderAtSearchPath:NSDownloadsDirectory];
}

- (IBAction) openDesktopFolder:(id)sender
{
    [self openFolderAtSearchPath:NSDesktopDirectory];
}

- (IBAction) openDocumentsFolder:(id)sender
{
    [self openFolderAtSearchPath:NSDocumentDirectory];
}

- (IBAction) openApplicationsFolder:(id)sender
{
    [self openFolderAtSearchPath:NSApplicationDirectory];
}

#pragma mark - FolderDropViewDelegate

- (void) folderDropView:(FolderDropView *)view didReceiveFolderURLs:(NSArray<NSURL *> *)urls
{
    for (NSURL *url in urls)
    {
        [self openFolderAtPath:[url path]];
    }
}

@end

#pragma mark - Private Methods

@implementation StartupPanelController(Private)

- (void) openFolderAtPath:(NSString *)path
{
    // Defer to next run loop cycle to let UI respond
    [[NSRunLoop currentRunLoop] performSelector:@selector(openDocumentWithContentsOfFile:)
                                         target:[NSDocumentController sharedDocumentController]
                                       argument:path
                                          order:1
                                          modes:@[NSDefaultRunLoopMode]];
}

- (void) openFolderAtSearchPath:(NSSearchPathDirectory)directory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES);
    if ([paths count] > 0)
    {
        NSString *path = [paths objectAtIndex:0];

        // Special case for home directory
        if (directory == NSUserDirectory)
            path = NSHomeDirectory();

        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            [self openFolderAtPath:path];
        }
    }
}

- (void) configureShortcutButtons
{
    // Set tooltips with actual paths
    NSString *homePath = NSHomeDirectory();
    NSArray *downloadsPaths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
    NSArray *desktopPaths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
    NSArray *documentsPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSArray *applicationsPaths = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES);

    if (_homeButton && homePath)
        [_homeButton setToolTip:homePath];

    if (_downloadsButton && [downloadsPaths count] > 0)
        [_downloadsButton setToolTip:[downloadsPaths objectAtIndex:0]];

    if (_desktopButton && [desktopPaths count] > 0)
        [_desktopButton setToolTip:[desktopPaths objectAtIndex:0]];

    if (_documentsButton && [documentsPaths count] > 0)
        [_documentsButton setToolTip:[documentsPaths objectAtIndex:0]];

    if (_applicationsButton && [applicationsPaths count] > 0)
        [_applicationsButton setToolTip:[applicationsPaths objectAtIndex:0]];
}

- (void) rebuildVolumesArray
{
    _maxVolumeSize = 0;

    NSArray *volProps = @[NSURLLocalizedNameKey,
                          NSURLVolumeTotalCapacityKey,
                          NSURLVolumeAvailableCapacityKey,
                          NSURLVolumeSupportsVolumeSizesKey,
                          NSURLVolumeLocalizedFormatDescriptionKey];

    NSArray<NSURL *> *vols = [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:volProps
                                                                                                     options:NSVolumeEnumerationSkipHiddenVolumes];

    [self willChangeValueForKey:@"volumes"];

    @try
    {
        [_volumes release];
        _volumes = [[NSMutableArray alloc] initWithCapacity:[vols count]];

        for (NSURL *volumeURL in vols)
        {
            [volumeURL cacheResourcesInArray:volProps];

            NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithObject:volumeURL forKey:@"volume"];

            NSImage *volImage = [volumeURL icon];
            [volImage setSize:NSMakeSize(32, 32)];

            [entry setObject:(volImage == nil ? (id)[NSNull null] : volImage)
                      forKey:@"image"];

            [_volumes addObject:entry];

            if ([[volumeURL volumeTotalCapacity] unsignedLongLongValue] > _maxVolumeSize)
                _maxVolumeSize = [[volumeURL volumeTotalCapacity] unsignedLongLongValue];
        }
    }
    @catch (NSException *exception)
    {
        // Ignore exceptions during volume enumeration
    }

    [self rebuildProgressIndicatorArray];

    [self didChangeValueForKey:@"volumes"];
}

- (void) rebuildProgressIndicatorArray
{
    if (_progressIndicators == nil)
        _progressIndicators = [[NSMutableArray alloc] initWithCapacity:[_volumes count]];

    unsigned i;
    for (i = 0; i < [_volumes count]; i++)
    {
        NSProgressIndicator *progrInd = nil;
        if (i >= [_progressIndicators count])
        {
            progrInd = [[[NSProgressIndicator alloc] init] autorelease];
            [progrInd setStyle:NSProgressIndicatorBarStyle];
            [progrInd setIndeterminate:NO];

            [_progressIndicators addObject:progrInd];
        }
        else
        {
            progrInd = [_progressIndicators objectAtIndex:i];
        }

        NSURL *vol = [[_volumes objectAtIndex:i] objectForKey:@"volume"];

        if ([vol getCachedBoolValue:NSURLVolumeSupportsVolumeSizesKey])
        {
            double totalBytes = [[vol volumeTotalCapacity] doubleValue];
            double freeBytes = [[vol volumeAvailableCapacity] doubleValue];

            [progrInd setMinValue:0];
            [progrInd setMaxValue:totalBytes];
            [progrInd setDoubleValue:(totalBytes - freeBytes)];
        }
        else
        {
            [progrInd setMinValue:0];
            [progrInd setMaxValue:0];
            [progrInd setDoubleValue:0];
        }
    }

    while ([_progressIndicators count] > [_volumes count])
    {
        [[_progressIndicators lastObject] removeFromSuperviewWithoutNeedingDisplay];
        [_progressIndicators removeLastObject];
    }
}

- (void) onVolumesChanged:(NSNotification *)notification
{
    [self rebuildVolumesArray];
}

#pragma mark - NSTableView Delegates

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
    // Enable/disable open button based on selection
}

- (void) tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    if ([[tableColumn identifier] isEqualToString:@"usagePercent"])
    {
        NSProgressIndicator *progrInd = [_progressIndicators objectAtIndex:row];

        if ([progrInd superview] != tableView)
            [tableView addSubview:progrInd];

        int colIndex = [tableView columnWithIdentifier:[tableColumn identifier]];
        NSRect cellRect = [tableView frameOfCellAtColumn:colIndex row:row];

        const float progrIndThickness = NSProgressIndicatorPreferredLargeThickness;
        const float extraSpace = 16;

        NSAssert(NSHeight(cellRect) > progrIndThickness, @"rows need to be higher than progress indicator thickness");
        cellRect.origin.y += (NSHeight(cellRect) - progrIndThickness) / 2;
        cellRect.size.height = progrIndThickness;

        cellRect.origin.x += extraSpace;
        cellRect.size.width -= 2 * extraSpace;

        NSURL *volURL = [[_volumes objectAtIndex:row] objectForKey:@"volume"];
        if ([volURL getCachedBoolValue:NSURLVolumeSupportsVolumeSizesKey])
        {
            double fraction = [[volURL cachedVolumeTotalCapacity] doubleValue] / (double)_maxVolumeSize;
            cellRect.size.width *= fmax(fraction, 0.2);
        }
        else
        {
            cellRect.size.width = 0;
        }

        [progrInd setFrame:cellRect];
        [progrInd stopAnimation:nil];
    }
}

@end
