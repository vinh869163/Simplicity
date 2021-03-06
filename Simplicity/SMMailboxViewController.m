//
//  SMMailboxViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/21/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMPreferencesController.h"
#import "SMUserAccount.h"
#import "SMMailbox.h"
#import "SMFolder.h"
#import "SMFolderCellView.h"
#import "SMUserAccount.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMAccountSearchController.h"
#import "SMNotificationsController.h"
#import "SMColorCircle.h"
#import "SMAccountMailboxController.h"
#import "SMMailboxViewController.h"
#import "SMMailboxMainFolderView.h"
#import "SMMailboxLabelView.h"
#import "SMFolderColorController.h"
#import "SMPreferencesController.h"
#import "SMFolderLabel.h"
#import "SMMailboxRowView.h"

@interface SMMailboxViewController()
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTableView *folderListView;
@end

@implementation SMMailboxViewController {
    NSInteger _rowWithMenu;
    NSString *_labelToRename;
    BOOL _favoriteFolderSelected;
    NSBox *_hightlightBox;
    BOOL _doHightlightRow;
    NSMutableArray<NSNumber*> *_favoriteFolders;
    NSMutableArray<NSNumber*> *_visibleFolders;
    SMFolder *_prevFolder;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if(self) {
        _rowWithMenu = -1;
        _favoriteFolders = [NSMutableArray array];
        _visibleFolders = [NSMutableArray array];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [_folderListView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
    [_folderListView registerForDraggedTypes:[NSArray arrayWithObject:NSStringPboardType]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageHeadersSyncFinished:) name:@"MessageHeadersSyncFinished" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageFlagsUpdated:) name:@"MessageFlagsUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messagesUpdated:) name:@"MessagesUpdated" object:nil];

    [_progressIndicator startAnimation:self];
    [_progressIndicator setHidden:NO];
}

- (void)messageHeadersSyncFinished:(NSNotification *)notification {
    SMLocalFolder *localFolder;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageHeadersSyncFinishedParams:notification localFolder:&localFolder updateNow:nil hasUpdates:nil account:&account];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(appDelegate.currentAccountIsUnified || account == appDelegate.currentAccount) {
        [self updateFolders:localFolder];
    }
}

- (void)messageFlagsUpdated:(NSNotification *)notification {
    SMLocalFolder *localFolder;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageFlagsUpdatedParams:notification localFolder:&localFolder account:&account];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(appDelegate.currentAccountIsUnified || account == appDelegate.currentAccount) {
        [self updateFolders:localFolder];
    }
}

- (void)messagesUpdated:(NSNotification *)notification {
    SMLocalFolder *localFolder;
    SMUserAccount *account;
    
    [SMNotificationsController getMessagesUpdatedParams:notification localFolder:&localFolder account:&account];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(appDelegate.currentAccountIsUnified || account == appDelegate.currentAccount) {
        // This is happening very, very often
        // TODO: Fix!!! Issue #104.
        [self updateFolders:localFolder];
    }
}

- (void)updateFolders:(SMLocalFolder*)localFolder {
    (void)localFolder;
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMFolder *selectedFolder = [appDelegate.currentMailboxController selectedFolder];
    
    if(selectedFolder != nil) {
        NSInteger selectedRow = -1;

        selectedRow = [self getFolderRow:selectedFolder];

        [ _folderListView reloadData ];
        
        if(selectedRow >= 0) {
            [ _folderListView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO ];
        } else {
            [ _folderListView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO ];
        }
    }
    else {
        [ _folderListView reloadData ];
    }
}

- (void)updateFolderListView {
    NSInteger selectedRow = -1;

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    [_favoriteFolders removeAllObjects];
    [_visibleFolders removeAllObjects];
    
    if(appDelegate.currentAccount != nil && !appDelegate.currentAccountIsUnified) {
        NSDictionary<NSString*, SMFolderLabel*> *labels = [[appDelegate preferencesController] labels:appDelegate.currentAccountIdx];
        id<SMMailbox> mailbox = appDelegate.currentMailbox;
        
        for(NSUInteger i = 0, n = mailbox.folders.count; i < n; i++) {
            SMFolder *folder = mailbox.folders[i];
            SMFolderLabel *label = [labels objectForKey:folder.fullName];
            
            if((label != nil && label.visible) || label == nil) {
                [_visibleFolders addObject:[NSNumber numberWithUnsignedInteger:i]];
            }
            
            if((label != nil && label.favorite) || label == nil) {
                [_favoriteFolders addObject:[NSNumber numberWithUnsignedInteger:i]];
            }
        }
    }
    
    SMFolder *selectedFolder = [appDelegate.currentMailboxController selectedFolder];
    if(selectedFolder != nil) {
        selectedRow = [self getFolderRow:selectedFolder];
    }
    
    [ _folderListView reloadData ];

    if(selectedRow >= 0) {
        [ _folderListView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO ];
    } else {
        [ _folderListView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO ];
    }
    
    if([appDelegate.currentMailbox foldersLoaded]) {
        if(!_progressIndicator.hidden) {
            [_progressIndicator stopAnimation:self];
            [_progressIndicator setHidden:YES];
        }
    }
    else {
        if(_progressIndicator.hidden) {
            [_progressIndicator startAnimation:self];
            [_progressIndicator setHidden:NO];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = [_folderListView selectedRow];
    if(selectedRow < 0 || selectedRow >= [self totalFolderRowsCount])
        return;

    SMFolder *folder = [self selectedFolder:selectedRow favoriteFolderSelected:&_favoriteFolderSelected];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMFolder *selectedFolder = [appDelegate.currentMailboxController selectedFolder];
    
    if(folder == nil || [folder.fullName isEqualToString:selectedFolder.fullName])
        return;
    
    SM_LOG_DEBUG(@"selected row %lu, folder full name '%@'", selectedRow, folder.fullName);

    [self changeFolder:folder];
}

- (void)changeFolder:(SMFolder*)folder {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];

    [[appDelegate.currentAccount searchController] stopLatestSearch];
    [[appDelegate.currentAccount messageListController] changeFolder:(folder != nil? folder.fullName : nil) clearSearch:YES];
    
    _prevFolder = [appDelegate.currentMailboxController selectedFolder];;

    [appDelegate.currentMailboxController changeFolder:folder];
    
    [self updateFolderListView];
}

- (void)changeToPrevFolder {
    if(_prevFolder != nil) {
        [self changeFolder:_prevFolder];
        _prevFolder = nil;
    }
}

- (void)clearSelection {
    [_folderListView deselectAll:self];

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMFolder *selectedFolder = [appDelegate.currentMailboxController selectedFolder];
    
    if(selectedFolder != nil) {
        _prevFolder = selectedFolder;

        [appDelegate.currentMailboxController changeFolder:nil];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self totalFolderRowsCount];
}

- (NSInteger)mainFoldersGroupOffset {
    return 0;
}

- (NSInteger)favoriteFoldersGroupOffset {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    id<SMMailbox> mailbox = appDelegate.currentMailbox;

    return 1 + mailbox.mainFolders.count;
}

- (NSInteger)allFoldersGroupOffset {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    id<SMMailbox> mailbox = appDelegate.currentMailbox;
    
    return 1 + mailbox.mainFolders.count + 1 + _favoriteFolders.count;
}

- (NSInteger)totalFolderRowsCount {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(appDelegate.accounts.count == 0) {
        return 0;
    }

    id<SMMailbox> mailbox = appDelegate.currentMailbox;
    
    return 1 + mailbox.mainFolders.count + 1 + _favoriteFolders.count + 1 + _visibleFolders.count;
}

- (SMFolder*)selectedFolder:(NSInteger)row {
    return [self selectedFolder:row favoriteFolderSelected:nil];
}

- (SMFolder*)selectedFolder:(NSInteger)row favoriteFolderSelected:(BOOL*)favoriteFolderSelected {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    id<SMMailbox> mailbox = appDelegate.currentMailbox;
    
    const NSInteger mainFoldersGroupOffset = [self mainFoldersGroupOffset];
    const NSInteger favoriteFoldersGroupOffset = [self favoriteFoldersGroupOffset];
    const NSInteger allFoldersGroupOffset = [self allFoldersGroupOffset];
    
    if(row > mainFoldersGroupOffset && row < favoriteFoldersGroupOffset) {
        if(favoriteFolderSelected != nil) {
            *favoriteFolderSelected = NO;
        }
        
        return mailbox.mainFolders[row - mainFoldersGroupOffset - 1];
    } else if(row > favoriteFoldersGroupOffset && row < allFoldersGroupOffset) {
        if(favoriteFolderSelected != nil) {
            *favoriteFolderSelected = YES;
        }
        
        NSUInteger idx = [_favoriteFolders[row - favoriteFoldersGroupOffset - 1] unsignedIntegerValue];
        return mailbox.folders[idx];
    } else if(row > allFoldersGroupOffset) {
        if(favoriteFolderSelected != nil) {
            *favoriteFolderSelected = NO;
        }
        
        NSUInteger idx = [_visibleFolders[row - allFoldersGroupOffset - 1] unsignedIntegerValue];
        return mailbox.folders[idx];
    } else {
        return nil;
    }
}

- (NSInteger)getFolderRow:(SMFolder*)folder {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    id<SMMailbox> mailbox = appDelegate.currentMailbox;
    
    const NSInteger mainFoldersGroupOffset = [self mainFoldersGroupOffset];
    const NSInteger favoriteFoldersGroupOffset = [self favoriteFoldersGroupOffset];
    const NSInteger allFoldersGroupOffset = [self allFoldersGroupOffset];
    
    if(_favoriteFolderSelected) {
        for(NSUInteger i = 0; i < _favoriteFolders.count; i++) {
            NSUInteger idx = [_favoriteFolders[i] unsignedIntegerValue];

            if(mailbox.folders[idx] == folder) {
                return i + favoriteFoldersGroupOffset + 1;
            }
        }
    } else {
        for(NSUInteger i = 0; i < mailbox.mainFolders.count; i++) {
            if(mailbox.mainFolders[i] == folder)
                return i + mainFoldersGroupOffset + 1;
        }

        for(NSUInteger i = 0; i < _visibleFolders.count; i++) {
            NSUInteger idx = [_visibleFolders[i] unsignedIntegerValue];
            
            if(mailbox.folders[idx] == folder) {
                return i + allFoldersGroupOffset + 1;
            }
        }
    }
    
    return -1;
}

- (NSImage*)mainFolderImage:(SMFolder*)folder {
    switch(folder.kind) {
        case SMFolderKindInbox:
            return [NSImage imageNamed:@"inbox-white.png"];
        case SMFolderKindImportant:
            return [NSImage imageNamed:@"important-white.png"];
        case SMFolderKindSent:
            return [NSImage imageNamed:@"sent-white.png"];
        case SMFolderKindSpam:
            return [NSImage imageNamed:@"spam-white.png"];
        case SMFolderKindOutbox:
            return [NSImage imageNamed:@"outbox-white.png"];
        case SMFolderKindStarred:
            return [NSImage imageNamed:@"star-white.png"];
        case SMFolderKindDrafts:
            return [NSImage imageNamed:@"draft-white.png"];
        case SMFolderKindTrash:
            return [NSImage imageNamed:@"trash-white.png"];
        case SMFolderKindAllMail:
            return [NSImage imageNamed:@"archive-white.png"];
        default:
            return nil;
    }
}

typedef enum {
    kMainFoldersGroupHeader,
    kFavoriteFoldersGroupHeader,
    kAllFoldersGroupHeader,
    kMainFoldersGroupItem,
    kFavoriteFoldersGroupItem,
    kAllFoldersGroupItem
} FolderListItemKind;

- (FolderListItemKind)getRowKind:(NSInteger)row {
    NSInteger totalRowCount = [self totalFolderRowsCount];
    NSAssert(row >= 0 && row < totalRowCount, @"row %ld is beyond folders array size %lu", row, totalRowCount);
    
    const NSInteger mainFoldersGroupOffset = [self mainFoldersGroupOffset];
    const NSInteger favoriteFoldersGroupOffset = [self favoriteFoldersGroupOffset];
    const NSInteger allFoldersGroupOffset = [self allFoldersGroupOffset];

    if(row == mainFoldersGroupOffset) {
        return kMainFoldersGroupHeader;
    } else if(row == favoriteFoldersGroupOffset) {
        return kFavoriteFoldersGroupHeader;
    } else if(row == allFoldersGroupOffset) {
        return kAllFoldersGroupHeader;
    } else if(row < favoriteFoldersGroupOffset) {
        return kMainFoldersGroupItem;
    } else if(row < allFoldersGroupOffset) {
        return kFavoriteFoldersGroupItem;
    } else {
        return kAllFoldersGroupItem;
    }
}

- (NSIndexSet *)tableView:(NSTableView*)tableView selectionIndexesForProposedSelection:(NSIndexSet*)proposedSelectionIndexes {
    NSMutableIndexSet *newSelection = [[NSMutableIndexSet alloc] initWithIndexSet:proposedSelectionIndexes];

    // Scan the proposed selection and exclude folder section headers.
    for(NSUInteger row = proposedSelectionIndexes.firstIndex; row != NSNotFound; row = [proposedSelectionIndexes indexGreaterThanIndex:row]) {
        FolderListItemKind kind = [self getRowKind:row];
        
        if(kind == kMainFoldersGroupHeader || kind == kFavoriteFoldersGroupHeader || kind == kAllFoldersGroupHeader) {
            [newSelection removeIndex:row];
        }
    }
    
    return newSelection.count > 0? newSelection : tableView.selectedRowIndexes;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSInteger totalRowCount = [self totalFolderRowsCount];
    NSAssert(row >= 0 && row < totalRowCount, @"row %ld is beyond folders array size %lu", row, totalRowCount);

    const NSInteger mainFoldersGroupOffset = [self mainFoldersGroupOffset];
    const NSInteger favoriteFoldersGroupOffset = [self favoriteFoldersGroupOffset];
    const NSInteger allFoldersGroupOffset = [self allFoldersGroupOffset];

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    NSTableCellView *result = nil;
    BOOL adjustFont = YES;

    FolderListItemKind itemKind = [self getRowKind:row];
    switch(itemKind) {
        case kMainFoldersGroupItem: {
            result = [tableView makeViewWithIdentifier:@"MainFolderCellView" owner:self];
            NSAssert([result isKindOfClass:[SMMailboxMainFolderView class]], @"bad result class");
            
            SMFolder *folder = [self selectedFolder:row];
            NSAssert(folder != nil, @"bad selected folder");
            
            [result.textField setStringValue:folder.displayName];
            [result.imageView setImage:[self mainFolderImage:folder]];

            [self displayUnseenCount:[(SMMailboxMainFolderView*)result unreadCount] folderName:folder selected:(_folderListView.selectedRow == row)];
            
            break;
        }
            
        case kFavoriteFoldersGroupItem:
        case kAllFoldersGroupItem: {
            result = [tableView makeViewWithIdentifier:@"FolderCellView" owner:self];
            NSAssert([result isKindOfClass:[SMMailboxLabelView class]], @"bad result class");
            
            SMFolder *folder = [self selectedFolder:row];
            NSAssert(folder != nil, @"bad selected folder");
            
            [result.textField setStringValue:folder.displayName];

            [self displayUnseenCount:[(SMMailboxLabelView*)result unreadCount] folderName:folder selected:(_folderListView.selectedRow == row)];
            
            NSAssert([result.imageView isKindOfClass:[SMColorCircle class]], @"bad type of folder cell image");;
            
            SMColorCircle *colorMark = (SMColorCircle *)result.imageView;
            
            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];            
            colorMark.color = [[appDelegate.currentAccount folderColorController] colorForFolder:folder.fullName];

            if(row == _rowWithMenu) {
                if(_doHightlightRow) {
                    if(_hightlightBox == nil) {
                        _hightlightBox = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
                        
                        _hightlightBox.translatesAutoresizingMaskIntoConstraints = NO;
                        [_hightlightBox setBoxType:NSBoxCustom];
                        [_hightlightBox setBorderColor:[NSColor lightGrayColor]];
                        [_hightlightBox setBorderWidth:1];
                        [_hightlightBox setBorderType:NSBezelBorder];
                        [_hightlightBox setCornerRadius:5];
                        [_hightlightBox setTitlePosition:NSNoTitle];
                    }

                    [result addSubview:_hightlightBox];
                    
                    [result addConstraint:[NSLayoutConstraint constraintWithItem:result attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_hightlightBox attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
                    
                    [result addConstraint:[NSLayoutConstraint constraintWithItem:result attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_hightlightBox attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];
                    
                    [result addConstraint:[NSLayoutConstraint constraintWithItem:result attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_hightlightBox attribute:NSLayoutAttributeTop multiplier:1.0 constant:-1]];
                    
                    [result addConstraint:[NSLayoutConstraint constraintWithItem:result attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_hightlightBox attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
                } else {
                    [_hightlightBox removeFromSuperview];
                }
            }

            break;
        }
            
        default: {
            result = [tableView makeViewWithIdentifier:@"FolderGroupCellView" owner:self];
            
            const NSUInteger fontSize = 12;
            [result.textField setFont:[NSFont boldSystemFontOfSize:fontSize]];
            
            if(row == mainFoldersGroupOffset) {
                [result.textField setStringValue:@"Mailbox"];
            } else if(row == favoriteFoldersGroupOffset) {
                [result.textField setStringValue:@"Favorite"];
            } else if(row == allFoldersGroupOffset) {
                [result.textField setStringValue:@"Labels"];
            }
            
            adjustFont = NO;
            
            break;
        }
    }
    
    NSAssert(result != nil, @"cannot make folder cell view");

    if(_folderListView.selectedRow != row) {
        if(adjustFont) {
            static NSFont *thinFont = nil;
            if(thinFont == nil) {
                NSFont *existingFont = [result.textField font];
                thinFont = [[NSFontManager sharedFontManager] fontWithFamily:existingFont.familyName traits:0 weight:0 size:existingFont.pointSize];
            }

            static NSFont *thickFont = nil;
            if(thickFont == nil) {
                NSFont *existingFont = [result.textField font];
                thickFont = [[NSFontManager sharedFontManager] fontWithFamily:existingFont.familyName traits:0 weight:5 size:existingFont.pointSize];
            }

            switch(preferencesController.mailboxTheme) {
                case SMMailboxTheme_Light:
                case SMMailboxTheme_MediumLight:
                    [result.textField setFont:thickFont];
                    break;
                    
                case SMMailboxTheme_MediumDark:
                case SMMailboxTheme_Dark:
                    [result.textField setFont:thinFont];
                    break;
            }
        }

        switch(preferencesController.mailboxTheme) {
            case SMMailboxTheme_Light:
                [result.textField setTextColor:[NSColor blackColor]];
                break;
                
            case SMMailboxTheme_MediumLight:
                [result.textField setTextColor:[NSColor blackColor]];
                break;
                
            case SMMailboxTheme_MediumDark:
                [result.textField setTextColor:[NSColor whiteColor]];
                break;
                
            case SMMailboxTheme_Dark:
                [result.textField setTextColor:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0]];
                break;
        }
    }
    else {
        NSFont *existingFont = [result.textField font];

        [result.textField setTextColor:[NSColor whiteColor]];
        [result.textField setFont:[[NSFontManager sharedFontManager] fontWithFamily:existingFont.familyName traits:0 weight:0 size:existingFont.pointSize]];
    }
    
    return result;
}

- (void)displayUnseenCount:(NSTextField*)textField folderName:(SMFolder*)folder selected:(BOOL)selected {
    // TODO: this is called too often (Issue #99)
    SM_LOG_DEBUG(@"folderName: %@", folder.fullName);
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSUInteger unseenCount = [appDelegate.currentMailboxController unseenMessagesCount:folder];
    
    if(unseenCount != 0) {
        textField.stringValue = [NSString stringWithFormat:@"%lu", unseenCount];
        textField.hidden = NO;
    }
    else {
        textField.stringValue = @"0";
        textField.hidden = YES;
    }
    
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    if(!selected) {
        switch(preferencesController.mailboxTheme) {
            case SMMailboxTheme_Light:
            case SMMailboxTheme_MediumLight:
                [textField setTextColor:[NSColor blackColor]];
                break;
                
            case SMMailboxTheme_MediumDark:
            case SMMailboxTheme_Dark:
                [textField setTextColor:[NSColor whiteColor]];
                break;
        }
    }
    else {
        [textField setTextColor:[NSColor whiteColor]];
    }
}

#pragma mark Messages drag and drop support

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard {
    // do not permit dragging folders

    return NO;
}

- (NSDragOperation)tableView:(NSTableView*)tv
                validateDrop:(id)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)op
{
    // permit drop only at folders, not between them

    if(op == NSTableViewDropOn) {
        SMFolder *targetFolder = [self selectedFolder:row];

        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        if(targetFolder != nil && ![targetFolder.fullName isEqualToString:[[appDelegate.currentMailboxController selectedFolder] fullName]])
            return NSDragOperationMove;
    }
    
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv
       acceptDrop:(id)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)op
{
    SMFolder *targetFolder = [self selectedFolder:row];

    if(targetFolder == nil) {
        SM_LOG_INFO(@"No target folder");
        return NO;
    }
    
    if(targetFolder.kind == SMFolderKindOutbox) {
        SM_LOG_INFO(@"Cannot move messages to the Outbox folder");
        return NO;
    }

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMFolder *currentFolder = [appDelegate.currentMailboxController selectedFolder];

    if(currentFolder.kind == SMFolderKindOutbox && targetFolder.kind != SMFolderKindTrash) {
        SM_LOG_INFO(@"Cannot move messages from the Outbox folder to anything but Trash");
        return NO;
    }

    [[[appDelegate appController] messageListViewController] moveSelectedMessageThreadsToFolder:targetFolder];
    
    SM_LOG_INFO(@"Moving messages from %@ to %@", currentFolder.fullName, targetFolder.fullName);
    return YES;
}

#pragma mark Context menu creation

- (NSMenu*)menuForRow:(NSInteger)row {
    _rowWithMenu = row;

    if(row < 0 || row >= _folderListView.numberOfRows) {
        NSMenu *menu = [[NSMenu alloc] init];
        
        [menu addItemWithTitle:@"New label" action:@selector(newLabel) keyEquivalent:@""];
        [menu setDelegate:self];

        return menu;
    }

    _doHightlightRow = YES;

    [_folderListView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];

    NSMenu *menu = nil;

    FolderListItemKind itemKind = [self getRowKind:row];
    switch(itemKind) {
        case kMainFoldersGroupItem: {
            break;
        }
    
        case kFavoriteFoldersGroupItem: {
            menu = [[NSMenu alloc] init];
            
            [menu addItemWithTitle:@"Delete label" action:@selector(deleteLabel) keyEquivalent:@""];
            [menu addItemWithTitle:@"Remove label from favorites" action:@selector(removeLabelFromFavorites) keyEquivalent:@""];
            
            [menu setDelegate:self];

            break;
        }

        case kAllFoldersGroupItem: {
            menu = [[NSMenu alloc] init];

            [menu addItemWithTitle:@"New label" action:@selector(newLabel) keyEquivalent:@""];
            [menu addItemWithTitle:@"Delete label" action:@selector(deleteLabel) keyEquivalent:@""];
            [menu addItemWithTitle:@"Hide label" action:@selector(hideLabel) keyEquivalent:@""];
            [menu addItemWithTitle:@"Make label favorite" action:@selector(makeLabelFavorite) keyEquivalent:@""];
            
            [menu setDelegate:self];

            break;
        }

        default: {
            break;
        }
    }
    
    return menu;
}

- (void)menuDidClose:(NSMenu *)menu {
    SM_LOG_DEBUG(@"???");

    _doHightlightRow = NO;
    
    [_folderListView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:_rowWithMenu] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)newLabel {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];

    if(_rowWithMenu >= 0 && _rowWithMenu < _folderListView.numberOfRows) {
        SMFolder *folder = [self selectedFolder:_rowWithMenu];
        NSAssert(folder != nil, @"bad selected folder");

        [appController showNewLabelSheet:folder.fullName];
    }
    else {
        [appController showNewLabelSheet:nil];
    }
}

- (void)deleteLabel {
    NSAssert(_rowWithMenu >= 0 && _rowWithMenu < _folderListView.numberOfRows, @"bad _rowWithMenu %ld", _rowWithMenu);

    SMFolder *folder = [self selectedFolder:_rowWithMenu];
    NSAssert(folder != nil, @"bad selected folder");

    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:[NSString stringWithFormat:@"Are you sure you want to delete label %@?", folder.fullName]];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    if([alert runModal] != NSAlertFirstButtonReturn) {
        SM_LOG_DEBUG(@"Label deletion cancelled");
        return;
    }
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];

    [appDelegate.currentMailboxController deleteFolder:folder.fullName];
    
    if([[[appDelegate.currentMailboxController selectedFolder] fullName] isEqualToString:folder.fullName]) {
        SMFolder *inboxFolder = [appDelegate.currentMailbox inboxFolder];
        [self changeFolder:inboxFolder];
    }
}

- (void)hideLabel {
    NSAssert(_rowWithMenu >= 0 && _rowWithMenu < _folderListView.numberOfRows, @"bad _rowWithMenu %ld", _rowWithMenu);
    
    SMFolder *folder = [self selectedFolder:_rowWithMenu];
    NSAssert(folder != nil, @"bad selected folder");

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSAssert(!appDelegate.currentAccountIsUnified, @"current account cannot be unified to change labels");
    
    NSMutableDictionary *labels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:appDelegate.currentAccountIdx]];
    SMFolderLabel *label = [labels objectForKey:folder.fullName];
    label.visible = NO;
    [[appDelegate preferencesController] setLabels:appDelegate.currentAccountIdx labels:labels];
    
    [self updateFolderListView];
}

- (void)makeLabelFavorite {
    NSAssert(_rowWithMenu >= 0 && _rowWithMenu < _folderListView.numberOfRows, @"bad _rowWithMenu %ld", _rowWithMenu);

    SMFolder *folder = [self selectedFolder:_rowWithMenu];
    NSAssert(folder != nil, @"bad selected folder");

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSAssert(!appDelegate.currentAccountIsUnified, @"current account cannot be unified to change labels");
    
    NSMutableDictionary *labels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:appDelegate.currentAccountIdx]];
    SMFolderLabel *label = [labels objectForKey:folder.fullName];
    label.favorite = YES;
    [[appDelegate preferencesController] setLabels:appDelegate.currentAccountIdx labels:labels];
    
    [self updateFolderListView];
}

- (void)removeLabelFromFavorites {
    NSAssert(_rowWithMenu >= 0 && _rowWithMenu < _folderListView.numberOfRows, @"bad _rowWithMenu %ld", _rowWithMenu);

    SMFolder *folder = [self selectedFolder:_rowWithMenu];
    NSAssert(folder != nil, @"bad selected folder");

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSAssert(!appDelegate.currentAccountIsUnified, @"current account cannot be unified to change labels");
    
    NSMutableDictionary *labels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:appDelegate.currentAccountIdx]];
    SMFolderLabel *label = [labels objectForKey:folder.fullName];
    label.favorite = NO;
    [[appDelegate preferencesController] setLabels:appDelegate.currentAccountIdx labels:labels];

    [self updateFolderListView];
}

#pragma mark Editing cells (renaming labels)

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
    NSTextField *textField = [obj object];
    
    _labelToRename = textField.stringValue;
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if(_labelToRename == nil)
        return;

    NSTextField *textField = [obj object];
    NSString *newLabelName = textField.stringValue;
    
    if([newLabelName isEqualToString:_labelToRename])
        return;

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    [appDelegate.currentMailboxController renameFolder:_labelToRename newFolderName:newLabelName];
}

#pragma mark Cell selection

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    return [[SMMailboxRowView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
}

@end
