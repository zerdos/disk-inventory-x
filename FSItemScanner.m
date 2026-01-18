//
//  FSItemScanner.m
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

#import "FSItemScanner.h"
#import "NSURL-Extensions.h"

// Throttle progress updates to ~30fps
static const uint64_t kProgressUpdateInterval = 33 * NSEC_PER_MSEC;

@interface FSItemScanner(Private)

- (void) scanOnBackgroundQueue;
- (void) notifyProgress:(NSString *)path;
- (void) notifyCompletion:(FSItem *)rootItem;
- (void) notifyError:(NSError *)error;
- (void) notifyCancellation;

@end

@implementation FSItemScanner

@synthesize delegate = _delegate;
@synthesize usePhysicalSize = _usePhysicalSize;
@synthesize showPackageContents = _showPackageContents;
@synthesize ignoreCreatorCode = _ignoreCreatorCode;

- (id) initWithURL:(NSURL *)url
{
    self = [super init];
    if (self == nil)
        return nil;

    _url = [url retain];
    _cancelled = NO;
    _usePhysicalSize = NO;
    _showPackageContents = NO;
    _ignoreCreatorCode = NO;
    _fileCount = 0;
    _folderCount = 0;

    // Create a serial queue for scanning
    _scanQueue = dispatch_queue_create("com.derlien.DiskInventoryX.scanner", DISPATCH_QUEUE_SERIAL);

    return self;
}

- (void) dealloc
{
    [_url release];
    [_currentPath release];

    if (_scanQueue)
        dispatch_release(_scanQueue);

    if (_progressSource)
    {
        dispatch_source_cancel(_progressSource);
        dispatch_release(_progressSource);
    }

    [super dealloc];
}

- (BOOL) isCancelled
{
    return _cancelled;
}

- (void) startScanning
{
    if (_cancelled)
        return;

    // Query delegate for options before starting
    if ([_delegate respondsToSelector:@selector(scannerShouldUsePhysicalFileSize:)])
        _usePhysicalSize = [_delegate scannerShouldUsePhysicalFileSize:self];

    if ([_delegate respondsToSelector:@selector(scannerShouldLookIntoPackages:)])
        _showPackageContents = [_delegate scannerShouldLookIntoPackages:self];

    if ([_delegate respondsToSelector:@selector(scannerShouldIgnoreCreatorCode:)])
        _ignoreCreatorCode = [_delegate scannerShouldIgnoreCreatorCode:self];

    // Create a dispatch source for throttled progress updates
    _progressSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, dispatch_get_main_queue());

    dispatch_source_set_event_handler(_progressSource, ^{
        if ([_delegate respondsToSelector:@selector(scanner:didEnterFolder:)] && _currentPath)
        {
            [_delegate scanner:self didEnterFolder:_currentPath];
        }
    });

    dispatch_resume(_progressSource);

    // Start scanning on background queue
    dispatch_async(_scanQueue, ^{
        [self scanOnBackgroundQueue];
    });
}

- (void) cancel
{
    _cancelled = YES;
}

@end

@implementation FSItemScanner(Private)

- (void) scanOnBackgroundQueue
{
    @autoreleasepool
    {
        // Check if URL exists
        if (![_url stillExists])
        {
            NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                 code:NSFileReadNoSuchFileError
                                             userInfo:@{NSLocalizedDescriptionKey: @"The folder does not exist."}];
            [self notifyError:error];
            return;
        }

        @try
        {
            // Reset counters
            g_fileCount = 0;
            g_folderCount = 0;

            // Create root item
            FSItem *rootItem = [[FSItem alloc] initWithURL:_url];
            [rootItem setDelegate:self];

            // Perform the scan
            [rootItem loadChildren];

            if (_cancelled)
            {
                [rootItem release];
                [self notifyCancellation];
                return;
            }

            // Notify completion on main thread
            [self notifyCompletion:rootItem];
            [rootItem release];
        }
        @catch (NSException *exception)
        {
            if ([[exception name] isEqualToString:FSItemLoadingCanceledException])
            {
                [self notifyCancellation];
            }
            else
            {
                NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                     code:NSFileReadUnknownError
                                                 userInfo:@{NSLocalizedDescriptionKey: [exception reason] ?: @"Unknown error"}];
                [self notifyError:error];
            }
        }
    }
}

- (void) notifyProgress:(NSString *)path
{
    @synchronized(self)
    {
        [_currentPath release];
        _currentPath = [path retain];
    }

    // Signal the dispatch source (throttled)
    dispatch_source_merge_data(_progressSource, 1);
}

- (void) notifyCompletion:(FSItem *)rootItem
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([_delegate respondsToSelector:@selector(scanner:didFinishWithRootItem:)])
        {
            [_delegate scanner:self didFinishWithRootItem:rootItem];
        }
    });
}

- (void) notifyError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([_delegate respondsToSelector:@selector(scanner:didFailWithError:)])
        {
            [_delegate scanner:self didFailWithError:error];
        }
    });
}

- (void) notifyCancellation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([_delegate respondsToSelector:@selector(scannerDidCancel:)])
        {
            [_delegate scannerDidCancel:self];
        }
    });
}

#pragma mark - FSItem Delegate Methods

- (BOOL) fsItemEnteringFolder:(FSItem *)item
{
    if (_cancelled)
        return NO;

    // Notify progress (throttled)
    [self notifyProgress:[item displayPath]];

    return YES;
}

- (BOOL) fsItemExittingFolder:(FSItem *)item
{
    return !_cancelled;
}

- (BOOL) fsItemShouldIgnoreCreatorCode:(FSItem *)item
{
    return _ignoreCreatorCode;
}

- (BOOL) fsItemShouldLookIntoPackages:(FSItem *)item
{
    return _showPackageContents;
}

- (BOOL) fsItemShouldUsePhysicalFileSize:(FSItem *)item
{
    return _usePhysicalSize;
}

@end
