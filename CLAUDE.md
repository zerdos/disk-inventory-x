# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Disk Inventory X is a macOS disk usage visualization app that displays a treemap view of file sizes. It's an Objective-C Cocoa application, originally created in 2003, updated for modern macOS (10.11+, 64-bit Intel).

## Build Commands

```bash
# Build release
./BuildRelease.sh

# Or directly with xcodebuild
xcodebuild -project "Disk Inventory X.xcodeproj" -configuration Release

# Debug build
xcodebuild -project "Disk Inventory X.xcodeproj" -configuration Debug
```

## Architecture

### Core Data Model

- **FSItem** (`FSItem.h/.m`): Tree node representing files/folders. Loads children lazily via `loadChildren`. Supports three types: `FileFolderItem`, `OtherSpaceItem`, `FreeSpaceItem`. Uses delegate pattern (`FSItemDelegate`) for callbacks during folder traversal.

- **FileSystemDoc** (`FileSystemDoc.h/.m`): NSDocument subclass. Owns the root FSItem tree, maintains zoom stack for navigation, and tracks FileKindStatistic objects (aggregated file type stats). Posts notifications: `GlobalSelectionChangedNotification`, `ZoomedItemChangedNotification`, `FSItemsChangedNotification`.

- **FileKindStatistic**: Tracks count and total size of files grouped by kind (e.g., "MP3 files").

### UI Controllers

- **MainWindowController**: Manages main window with split view (outline + treemap), toolbar, and drawers. Inherits from OAToolbarWindowControllerEx.

- **TreeMapViewController**: Bridges FileSystemDoc to TreeMapView framework for visualization.

- **FilesOutlineViewController**: Manages the file list outline view.

- **SelectionListController/FileKindsTableController**: Handle drawer views for file statistics.

### External Frameworks (pre-built, expected relative to project)

- **TreeMapView.framework**: Custom treemap rendering (separate project at `../../../../TreeMapView/`)
- **OmniAppKit/OmniBase/OmniFoundation**: OmniGroup frameworks from `../../../../OmniFrameworks_2018-09-22/`

### Key Directories

- `CocoaTech-Depreciated/`: Legacy NT* classes for info panel rendering
- `Foundation Extensions/`: NSFileManager category extensions
- `en.lproj/, de.lproj/, fr.lproj/, es.lproj/`: Localizations with NIB files

### Preferences System

Preferences defined in `Preferences.h` and registered via `OFRegistrations` in Info.plist. Key settings: `ShowPackageContents`, `ShowPhysicalFileSize`, `ShowFreeSpace`, `AnimatedZooming`.

## macOS Privacy

The app requests extensive file system access permissions (documented in Info.plist's `NS*UsageDescription` keys) since it scans disk contents. It only reads file metadata, not content.
