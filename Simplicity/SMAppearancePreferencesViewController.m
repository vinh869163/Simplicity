//
//  SMAppearancePreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/20/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMPreferencesController.h"
#import "SMAccountsViewController.h"
#import "SMMailboxViewController.h"
#import "SMAppearancePreferencesViewController.h"

@interface SMAppearancePreferencesViewController ()
@property (weak) IBOutlet NSButton *fixedFontButton;
@property (weak) IBOutlet NSButton *regularFontButton;
@property (weak) IBOutlet NSPopUpButton *mailboxThemeList;
@end

@implementation SMAppearancePreferencesViewController {
    NSFont *_regularFont;
    NSFont *_fixedFont;
    NSArray *_mailboxThemeNames;
    NSArray *_mailboxThemeValues;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _mailboxThemeNames = @[@"Light", @"Medium light", @"Medium dark", @"Dark"];
    _mailboxThemeValues = @[@(SMMailboxTheme_Light), @(SMMailboxTheme_MediumLight), @(SMMailboxTheme_MediumDark), @(SMMailboxTheme_Dark)];

    [_mailboxThemeList removeAllItems];
    [_mailboxThemeList addItemsWithTitles:_mailboxThemeNames];

    //
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSUInteger mailboxThemeValue = [[appDelegate preferencesController] mailboxTheme];
    
    NSAssert(mailboxThemeValue < _mailboxThemeNames.count, @"bad mailboxThemeValue %lu loaded from preferences", mailboxThemeValue);

    [_mailboxThemeList selectItemAtIndex:mailboxThemeValue];
    
    //
    
    _regularFont = [[appDelegate preferencesController] regularMessageFont];
    [self reloadRegularFontButton];
    
    _fixedFont = [[appDelegate preferencesController] fixedMessageFont];
    [self reloadFixedFontButton];
}

- (void)reloadRegularFontButton {
    _regularFontButton.title = [NSString stringWithFormat:@"%@ %lu", _regularFont.displayName, (NSUInteger)_regularFont.pointSize];
}

- (void)reloadFixedFontButton {
    _fixedFontButton.title = [NSString stringWithFormat:@"%@ %lu", _fixedFont.displayName, (NSUInteger)_fixedFont.pointSize];
}

- (void)setRegularFont:(id)sender {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    _regularFont = [fontManager convertFont:[fontManager selectedFont]];

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setRegularMessageFont:_regularFont];
    
    [self reloadRegularFontButton];
}

- (void)setFixedFont:(id)sender {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    _fixedFont = [fontManager convertFont:[fontManager selectedFont]];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setFixedMessageFont:_fixedFont];
    
    [self reloadFixedFontButton];
}

- (IBAction)regularFontButtonAction:(id)sender {
    [self.view.window makeFirstResponder:self];

    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    [fontManager setSelectedFont:_regularFont isMultiple:NO];
    [fontManager setAction:@selector(setRegularFont:)];

    NSFontPanel *fontPanel = [fontManager fontPanel:YES];
    [fontPanel makeKeyAndOrderFront:sender];
}

- (IBAction)fixedSizeButtonAction:(id)sender {
    [self.view.window makeFirstResponder:self];
    
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    [fontManager setSelectedFont:_fixedFont isMultiple:NO];
    [fontManager setAction:@selector(setFixedFont:)];
    
    NSFontPanel *fontPanel = [fontManager fontPanel:YES];
    [fontPanel makeKeyAndOrderFront:sender];
}

- (IBAction)mailboxThemeListAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    SMMailboxTheme mailboxThemeValue = (SMMailboxTheme)[_mailboxThemeList indexOfSelectedItem];

    [[appDelegate preferencesController] setMailboxTheme:mailboxThemeValue];
    [[[appDelegate appController] accountsViewController] setMailboxTheme:mailboxThemeValue];
    [[[appDelegate appController] mailboxViewController] updateFolderListView];
}

@end
