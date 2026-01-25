//
//  FolderDropView.m
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

#import "FolderDropView.h"

@implementation FolderDropView

@synthesize delegate = _delegate;

- (void) awakeFromNib
{
    [super awakeFromNib];

    // Register for file URL drag types
    [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
}

- (void) dealloc
{
    [self unregisterDraggedTypes];
    [super dealloc];
}

#pragma mark - Drawing

- (void) drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    NSRect bounds = [self bounds];
    CGFloat cornerRadius = 12.0;
    CGFloat inset = 8.0;
    NSRect innerRect = NSInsetRect(bounds, inset, inset);

    // Draw rounded rect background
    NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRoundedRect:innerRect
                                                               xRadius:cornerRadius
                                                               yRadius:cornerRadius];

    if (_isDragHighlighted)
    {
        // Highlight color when dragging over
        [[NSColor colorWithSRGBRed:0.2 green:0.5 blue:0.9 alpha:0.2] setFill];
        [roundedPath fill];

        [[NSColor colorWithSRGBRed:0.2 green:0.5 blue:0.9 alpha:0.8] setStroke];
    }
    else
    {
        // Normal state - light background
        [[NSColor colorWithGenericGamma22White:0.95 alpha:1.0] setFill];
        [roundedPath fill];

        [[NSColor colorWithGenericGamma22White:0.7 alpha:1.0] setStroke];
    }

    // Draw dashed border
    CGFloat dashPattern[] = {8.0, 4.0};
    [roundedPath setLineDash:dashPattern count:2 phase:0.0];
    [roundedPath setLineWidth:2.0];
    [roundedPath stroke];

    // Draw centered text
    NSString *dropText = NSLocalizedString(@"Drop folders here to analyze", @"");
    NSDictionary *textAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:14.0 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: _isDragHighlighted ?
            [NSColor colorWithSRGBRed:0.2 green:0.5 blue:0.9 alpha:1.0] :
            [NSColor colorWithGenericGamma22White:0.5 alpha:1.0]
    };

    NSSize textSize = [dropText sizeWithAttributes:textAttrs];
    NSPoint textPoint = NSMakePoint(
        NSMidX(innerRect) - textSize.width / 2.0,
        NSMidY(innerRect) - textSize.height / 2.0
    );

    [dropText drawAtPoint:textPoint withAttributes:textAttrs];

    // Draw folder icon above text
    NSImage *folderIcon = [NSImage imageNamed:NSImageNameFolder];
    if (folderIcon)
    {
        NSSize iconSize = NSMakeSize(48, 48);
        NSPoint iconPoint = NSMakePoint(
            NSMidX(innerRect) - iconSize.width / 2.0,
            textPoint.y + textSize.height + 16.0
        );
        [folderIcon drawInRect:NSMakeRect(iconPoint.x, iconPoint.y, iconSize.width, iconSize.height)
                      fromRect:NSZeroRect
                     operation:NSCompositeSourceOver
                      fraction:_isDragHighlighted ? 1.0 : 0.5];
    }
}

#pragma mark - Drag and Drop

- (NSDragOperation) draggingEntered:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];

    // Check if we have file URLs
    NSArray<NSURL *> *fileURLs = [pboard readObjectsForClasses:@[[NSURL class]]
                                                       options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];

    if ([fileURLs count] > 0)
    {
        // Check if any of the files is a directory
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSURL *url in fileURLs)
        {
            BOOL isDir = NO;
            if ([fm fileExistsAtPath:[url path] isDirectory:&isDir] && isDir)
            {
                _isDragHighlighted = YES;
                [self setNeedsDisplay:YES];
                return NSDragOperationCopy;
            }
        }
    }

    return NSDragOperationNone;
}

- (NSDragOperation) draggingUpdated:(id<NSDraggingInfo>)sender
{
    return _isDragHighlighted ? NSDragOperationCopy : NSDragOperationNone;
}

- (void) draggingExited:(id<NSDraggingInfo>)sender
{
    _isDragHighlighted = NO;
    [self setNeedsDisplay:YES];
}

- (BOOL) prepareForDragOperation:(id<NSDraggingInfo>)sender
{
    return _isDragHighlighted;
}

- (BOOL) performDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];

    NSArray<NSURL *> *fileURLs = [pboard readObjectsForClasses:@[[NSURL class]]
                                                       options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];

    if ([fileURLs count] > 0)
    {
        NSMutableArray<NSURL *> *folderURLs = [NSMutableArray array];

        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSURL *url in fileURLs)
        {
            BOOL isDir = NO;
            if ([fm fileExistsAtPath:[url path] isDirectory:&isDir] && isDir)
            {
                [folderURLs addObject:url];
            }
        }

        if ([folderURLs count] > 0 && [_delegate respondsToSelector:@selector(folderDropView:didReceiveFolderURLs:)])
        {
            [_delegate folderDropView:self didReceiveFolderURLs:folderURLs];
            return YES;
        }
    }

    return NO;
}

- (void) concludeDragOperation:(id<NSDraggingInfo>)sender
{
    _isDragHighlighted = NO;
    [self setNeedsDisplay:YES];
}

@end
