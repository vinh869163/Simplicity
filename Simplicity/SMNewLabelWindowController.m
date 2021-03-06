//
//  SMNewLabelWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/5/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMUserAccount.h"
#import "SMNotificationsController.h"
#import "SMUserAccount.h"
#import "SMMailbox.h"
#import "SMAccountMailboxController.h"
#import "SMFolder.h"
#import "SMFolderColorController.h"
#import "SMNewLabelWindowController.h"

@implementation SMNewLabelWindowController {
    NSString *_nestingLabel;
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
    [self updateExistingLabelsList];
    [self updateSuggestedNestingLabel];
}

- (IBAction)createAction:(id)sender {
    NSString *folderName = _labelName.stringValue;
    NSString *parentFolderName = _labelNestedCheckbox.state == NSOnState? _nestingLabelNameButton.titleOfSelectedItem : nil;
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    NSAssert(!appDelegate.currentAccountIsUnified, @"cannot create label in unified account");
    NSAssert([appDelegate.currentMailboxController isKindOfClass:[SMAccountMailboxController class]], @"can't create folders in the unified mailbox");
    SMAccountMailboxController *mailboxController = (SMAccountMailboxController*)appDelegate.currentMailboxController;

    NSString *fullFolderName = [mailboxController createFolder:folderName parentFolder:parentFolderName];
    if(fullFolderName != nil) {
        
        // TODO: sophisticated error handling
        
        [[appDelegate.currentAccount folderColorController] setFolderColor:fullFolderName color:_labelColorWell.color];
        
        [mailboxController scheduleFolderListUpdate:YES];
        
        [SMNotificationsController localNotifyNewLabelCreated:fullFolderName account:(SMUserAccount*)appDelegate.currentAccount];
    }

    [self closeNewLabelWindow];
}

- (IBAction)cancelAction:(id)sender {
    [self closeNewLabelWindow];
}

- (IBAction)toggleNestedLabelAction:(id)sender {
    const BOOL nestLabel = (_labelNestedCheckbox.state == NSOnState);

    [_nestingLabelNameButton setEnabled:nestLabel];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self closeNewLabelWindow];
}

- (void)closeNewLabelWindow {
    [_labelColorWell deactivate];
    [[NSColorPanel sharedColorPanel] orderOut:nil];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate appController] hideNewLabelSheet];
}

- (void)updateExistingLabelsList {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    id<SMMailbox> mailbox = appDelegate.currentMailbox;

    NSMutableArray *labelsList = [NSMutableArray array];
    for(SMFolder *folder in mailbox.folders)
        [labelsList addObject:folder.fullName];

    [_nestingLabelNameButton removeAllItems];
    [_nestingLabelNameButton addItemsWithTitles:labelsList];
}

- (void)updateSuggestedNestingLabel {
    if(_suggestedNestingLabel != nil) {
        [_nestingLabelNameButton selectItemWithTitle:_suggestedNestingLabel];
        [_nestingLabelNameButton setEnabled:YES];
        [_labelNestedCheckbox setState:NSOnState];

        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        NSColor *nestingColor = [[appDelegate.currentAccount folderColorController] colorForFolder:_suggestedNestingLabel];
        
        if(nestingColor != nil) {
            _labelColorWell.color = nestingColor;
        }
        else {
            _labelColorWell.color = [SMFolderColorController randomLabelColor];
        }
    }
    else {
        [_nestingLabelNameButton setEnabled:NO];
        [_labelNestedCheckbox setState:NSOffState];

        _labelColorWell.color = [SMFolderColorController randomLabelColor];
    }
}

@end
