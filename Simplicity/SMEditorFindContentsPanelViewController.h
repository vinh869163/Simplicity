//
//  SMEditorFindContentsPanelViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/7/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessageEditorViewController;

@interface SMEditorFindContentsPanelViewController : NSViewController

@property IBOutlet NSSearchField *findField;
@property IBOutlet NSTextField *replaceField;

@property (weak) SMMessageEditorViewController *messageEditorViewController;

- (void)showReplaceControls;
- (void)hideReplaceControls;

@end
