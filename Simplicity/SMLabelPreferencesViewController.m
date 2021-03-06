//
//  SMLabelPreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/13/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMUserAccount.h"
#import "SMMailbox.h"
#import "SMAccountMailbox.h"
#import "SMFolder.h"
#import "SMFolderLabel.h"
#import "SMFolderColorController.h"
#import "SMAccountMailboxController.h"
#import "SMPreferencesController.h"
#import "SMLabelPreferencesViewController.h"

@interface SMLabelPreferencesViewController ()

@property (weak) IBOutlet NSPopUpButton *accountList;
@property (weak) IBOutlet NSTableView *labelTable;
@property (weak) IBOutlet NSButton *addLabelButton;
@property (weak) IBOutlet NSButton *removeLabelButton;
@property (weak) IBOutlet NSButton *reloadLabelsButton;
@property (weak) IBOutlet NSProgressIndicator *reloadProgressIndicator;

@end

@implementation SMLabelPreferencesViewController {
    NSInteger _selectedAccount;
    BOOL _hasPendingChanges;
    NSMutableDictionary<NSNumber*, NSColorWell*> *_colorWells;
    NSMutableDictionary<NSNumber*, NSButton*> *_favoriteButtons;
    NSMutableDictionary<NSNumber*, NSButton*> *_visibleButtons;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    if(appDelegate.accountsExist && !appDelegate.currentAccountIsUnified) {
        _selectedAccount = appDelegate.currentAccountIdx;
    }
    else {
        _selectedAccount = -1;
    }
    
    [self initAccountList];
    [self setControlsEnabled:(appDelegate.accountsExist? YES : NO)];
    
    _reloadProgressIndicator.hidden = YES;

    _colorWells = [NSMutableDictionary dictionary];
    _favoriteButtons = [NSMutableDictionary dictionary];
    _visibleButtons = [NSMutableDictionary dictionary];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newLabelCreated) name:@"NewLabelCreated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLabels) name:@"FolderListUpdated" object:nil];
}

- (void)viewDidAppear {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectLabelColorAction:) name:NSColorPanelColorDidChangeNotification object:[NSColorPanel sharedColorPanel]];
    
    [self updateLabels];
}

- (void)viewDidDisappear {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSColorPanelColorDidChangeNotification object:[NSColorPanel sharedColorPanel]];

    [self hideColorPanel];
    [self saveLabels];
}

- (void)showProgress {
    [_reloadProgressIndicator startAnimation:self];

    _reloadProgressIndicator.hidden = NO;
}

- (void)hideProgress {
    [_reloadProgressIndicator stopAnimation:self];
    
    _reloadProgressIndicator.hidden = YES;
}

- (void)newLabelCreated {
    [self showProgress];
}

- (void)updateLabels {
    [self hideProgress];

    [_colorWells removeAllObjects];
    [_favoriteButtons removeAllObjects];
    [_visibleButtons removeAllObjects];
    [_labelTable reloadData];
}

- (void)saveLabels {
    if(!_hasPendingChanges) {
        return;
    }

    NSAssert(_selectedAccount >= 0, @"_selectedAccount is negative");
    
    NSUInteger accountIdx = _selectedAccount;

    // Save label colors.
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMFolderColorController *folderColorController = [appDelegate.accounts[accountIdx] folderColorController];
    SMAccountMailbox *mailbox = [appDelegate.accounts[accountIdx] mailbox];
 
    for(NSUInteger i = 0, n = mailbox.folders.count; i < n; i++) {
        NSColorWell *colorWell = [_colorWells objectForKey:[NSNumber numberWithInteger:i]];
        
        if(colorWell != nil) {
            SMFolder *folder = mailbox.folders[i];
            [folderColorController setFolderColor:folder.fullName color:colorWell.color];
        }
    }

    // Save label favorite and visibility states.
    NSMutableDictionary *updatedLabels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:accountIdx]];
    for(NSUInteger i = 0, n = mailbox.folders.count; i < n; i++) {
        SMFolder *folder = mailbox.folders[i];
        SMFolderLabel *label = [updatedLabels objectForKey:folder.fullName];

        NSButton *visibleCheckbox = [_visibleButtons objectForKey:[NSNumber numberWithInteger:i]];
        
        if(visibleCheckbox != nil) {
            label.visible = (visibleCheckbox.state == NSOnState? YES : NO);
        }

        NSButton *favoriteCheckbox = [_favoriteButtons objectForKey:[NSNumber numberWithInteger:i]];
        
        if(favoriteCheckbox != nil) {
            label.favorite = (favoriteCheckbox.state == NSOnState? YES : NO);
        }
    }
    
    [[appDelegate preferencesController] setLabels:_selectedAccount labels:updatedLabels];

    _hasPendingChanges = FALSE;
}

- (void)hideColorPanel {
    [[NSColorPanel sharedColorPanel] orderOut:nil];
}

- (void)selectLabelColorAction:(NSNotification*)notification {
    _hasPendingChanges = TRUE;
}

- (void)reloadAccountLabels {
    NSString *selectedAccountName = _accountList.titleOfSelectedItem;
    
    [self initAccountList];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if([[appDelegate preferencesController] accountsCount] > 0) {
        _selectedAccount = [[_accountList itemTitles] indexOfObjectIdenticalTo:selectedAccountName];
        if(_selectedAccount == NSNotFound) {
            SM_LOG_INFO(@"Account %@ disappeared, using default signature list position", selectedAccountName);
            
            _selectedAccount = 0;
        }
        
        [self setControlsEnabled:YES];
    }
    else {
        _selectedAccount = -1;
        
        [self setControlsEnabled:NO];
    }
    
    [_accountList selectItemAtIndex:_selectedAccount];
    
    [self updateLabels];
}

- (void)setControlsEnabled:(BOOL)enableControls {
    _accountList.enabled = enableControls;
    _labelTable.enabled = enableControls;
    _addLabelButton.enabled = enableControls;
    _removeLabelButton.enabled = enableControls;
    _reloadLabelsButton.enabled = enableControls;
}

- (void)initAccountList {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    [_accountList removeAllItems];
    
    for(NSUInteger i = 0, n = [[appDelegate preferencesController] accountsCount]; i < n; i++) {
        [_accountList addItemWithTitle:[[appDelegate preferencesController] accountName:i]];
    }
    
    [_accountList selectItemAtIndex:_selectedAccount];
}

#pragma mark IB actions

- (IBAction)accountListAction:(id)sender {
    [self hideColorPanel];
    [self saveLabels];

    _selectedAccount = [_accountList indexOfSelectedItem];
    
    [self updateLabels];
}

- (IBAction)addLabelAction:(id)sender {
    [self hideColorPanel];
    [self saveLabels];

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    NSString *nestingLabel = nil;
    if(_labelTable.selectedRow >= 0) {
        NSAssert(_selectedAccount >= 0, @"_selectedAccount is negative");
        
        SMUserAccount *account = appDelegate.accounts[_selectedAccount];
        id<SMMailbox> mailbox = [account mailbox];
        SMFolder *folder = mailbox.folders[_labelTable.selectedRow];
        
        nestingLabel = folder.fullName;
    }
    
    [appController showNewLabelSheet:nestingLabel];
}

- (IBAction)removeLabelAction:(id)sender {
    [self hideColorPanel];
    [self saveLabels];

    if(_labelTable.selectedRow >= 0) {
        NSAssert(_selectedAccount >= 0, @"_selectedAccount is negative");

        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        SMUserAccount *account = appDelegate.accounts[_selectedAccount];
        SMFolder *folder = [account mailbox].folders[_labelTable.selectedRow];

        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"OK"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setMessageText:[NSString stringWithFormat:@"Are you sure you want to delete label %@?", folder.fullName]];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        if([alert runModal] != NSAlertFirstButtonReturn) {
            SM_LOG_DEBUG(@"Label deletion cancelled");
            return;
        }

        [[account mailboxController] deleteFolder:folder.fullName];

        [self reloadAccountLabels];
    }
}

- (IBAction)editLabelAction:(id)sender {
    NSAssert([sender isKindOfClass:[NSTextField class]], @"bad sender %@", sender);

    NSTextField *editedLabelField = (NSTextField*)sender;
    NSInteger labelIndex = editedLabelField.tag;
    
    NSAssert(_selectedAccount >= 0, @"_selectedAccount is negative");

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMUserAccount *account = appDelegate.accounts[_selectedAccount];
    if(labelIndex < 0 || labelIndex >= [account mailbox].folders.count) {
        SM_LOG_ERROR(@"Bad edited label index %ld", labelIndex);
        return;
    }
    
    SMFolder *folder = [account mailbox].folders[labelIndex];

    [[account mailboxController] renameFolder:folder.fullName newFolderName:editedLabelField.stringValue];

    [self reloadLabelsAction:self];
}

- (IBAction)reloadLabelsAction:(id)sender {
    [self hideColorPanel];
    [self saveLabels];
    [self showProgress];

    NSAssert(_selectedAccount >= 0, @"_selectedAccount is negative");

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMUserAccount *account = appDelegate.accounts[_selectedAccount];
    SMAccountMailboxController *mailboxController = [account mailboxController];

    [mailboxController scheduleFolderListUpdate:YES];
}

- (IBAction)labelVisibleCheckAction:(id)sender {
    _hasPendingChanges = YES;
}

- (IBAction)labelFavoriteCheckAction:(id)sender {
    _hasPendingChanges = YES;
}

#pragma mark Table implementation

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(!appDelegate.accountsExist) {
        return 0;
    }
    
    if(_selectedAccount < 0) {
        return 0;
    }
    
    SMUserAccount *account = appDelegate.accounts[_selectedAccount];
    id<SMMailbox> mailbox = [account mailbox];
    
    return mailbox.folders.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSAssert(_selectedAccount >= 0, @"_selectedAccount is negative");

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMUserAccount *account = appDelegate.accounts[_selectedAccount];
    id<SMMailbox> mailbox = [account mailbox];
    SMFolder *folder = mailbox.folders[row];
    
    NSNumber *rowNumber = [NSNumber numberWithInteger:row];
    
    if([tableColumn.identifier isEqualToString:@"Color"]) {
        NSColorWell *colorWell = [_colorWells objectForKey:rowNumber];
        if(colorWell == nil) {
            colorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];

            [_colorWells setObject:colorWell forKey:rowNumber];
        }
        
        // TODO: use selected account index here too
        colorWell.color = [account.folderColorController colorForFolder:folder.fullName];

        return colorWell;
    }
    else if([tableColumn.identifier isEqualToString:@"Label"]) {
        NSTableCellView *view = [tableView makeViewWithIdentifier:@"LabelTableCell" owner:self];
        view.textField.stringValue = folder.fullName;
        view.textField.tag = row;
        
        return view;
    }
    else if([tableColumn.identifier isEqualToString:@"Favorite"]) {
        NSButton *checkbox = [_favoriteButtons objectForKey:rowNumber];
        if(checkbox == nil) {
            checkbox = [tableView makeViewWithIdentifier:@"FavoriteCheckBox" owner:self];
            [_favoriteButtons setObject:checkbox forKey:rowNumber];
        }
        
        SMFolderLabel *label = [[[appDelegate preferencesController] labels:_selectedAccount] objectForKey:folder.fullName];
        checkbox.state = (label != nil? (label.favorite? NSOnState : NSOffState) : NSOnState);
        
        return checkbox;
    }
    else if([tableColumn.identifier isEqualToString:@"Visible"]) {
        NSButton *checkbox = [_visibleButtons objectForKey:rowNumber];
        if(checkbox == nil) {
            checkbox = [tableView makeViewWithIdentifier:@"VisibleCheckBox" owner:self];
            [_visibleButtons setObject:checkbox forKey:rowNumber];
        }
        
        SMFolderLabel *label = [[[appDelegate preferencesController] labels:_selectedAccount] objectForKey:folder.fullName];
        checkbox.state = (label != nil? (label.visible? NSOnState : NSOffState) : NSOnState);
        
        return checkbox;
    }
    else {
        return nil;
    }
}

@end
