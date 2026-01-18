//
//  FSItemScanner.h
//  Disk Inventory X
//
//  Background scanner using GCD for non-blocking folder scanning.
//
//  Copyright (C) 2003-2024 Tjark Derlien.
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 3
//  of the License, or any later version.
//

#import <Foundation/Foundation.h>
#import "FSItem.h"

@protocol FSItemScannerDelegate;

@interface FSItemScanner : NSObject
{
    NSURL *_url;
    dispatch_queue_t _scanQueue;
    dispatch_source_t _progressSource;
    id<FSItemScannerDelegate> _delegate;
    BOOL _cancelled;
    BOOL _usePhysicalSize;
    BOOL _showPackageContents;
    BOOL _ignoreCreatorCode;

    // Progress tracking
    NSString *_currentPath;
    unsigned _fileCount;
    unsigned _folderCount;
}

@property (assign) id<FSItemScannerDelegate> delegate;
@property (assign) BOOL usePhysicalSize;
@property (assign) BOOL showPackageContents;
@property (assign) BOOL ignoreCreatorCode;
@property (readonly) BOOL isCancelled;

- (id) initWithURL:(NSURL *)url;
- (void) dealloc;

// Starts async scanning - results delivered via delegate
- (void) startScanning;

// Cancels the scan operation
- (void) cancel;

@end

@protocol FSItemScannerDelegate <NSObject>

@required
// Called when scanning completes successfully (on main thread)
- (void) scanner:(FSItemScanner *)scanner didFinishWithRootItem:(FSItem *)rootItem;

// Called when scanning fails (on main thread)
- (void) scanner:(FSItemScanner *)scanner didFailWithError:(NSError *)error;

@optional
// Called when entering a folder - throttled to ~30fps (on main thread)
- (void) scanner:(FSItemScanner *)scanner didEnterFolder:(NSString *)path;

// Called when scanning is cancelled (on main thread)
- (void) scannerDidCancel:(FSItemScanner *)scanner;

// Query methods for scan options
- (BOOL) scannerShouldUsePhysicalFileSize:(FSItemScanner *)scanner;
- (BOOL) scannerShouldLookIntoPackages:(FSItemScanner *)scanner;
- (BOOL) scannerShouldIgnoreCreatorCode:(FSItemScanner *)scanner;

@end
