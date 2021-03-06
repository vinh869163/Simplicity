//
//  SMMessageEditorViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/13/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SMEditorReplyKind.h"
#import "SMHTMLMessageEditorView.h"

@class SMAddress;
@class SMMessage;
@class SMAddressFieldViewController;
@class SMLabeledTextFieldBoxViewController;
@class SMMessageEditorView;
@class SMInlineButtonPanelViewController;
@class SMMessageThreadViewController;

@interface SMMessageEditorViewController : NSViewController

@property (readonly) __weak SMMessageThreadViewController *messageThreadViewController;
@property (readonly) CGFloat editorFullHeight;
@property (readonly) BOOL hasUnsavedContents;
@property (readonly) BOOL plainText;

+ (void)getReplyAddressLists:(SMMessage*)message replyKind:(SMEditorReplyKind)replyKind accountAddress:(SMAddress*)accountAddress to:(NSArray<SMAddress*>**)to cc:(NSArray<SMAddress*>**)cc;

- (id)initWithFrame:(NSRect)frame messageThreadViewController:(SMMessageThreadViewController*)messageThreadViewController draftUid:(uint32_t)draftUid plainText:(BOOL)plainText;
- (void)setEditorFrame:(NSRect)frame;
- (void)setResponders:(BOOL)initialSetup focusKind:(SMEditorFocusKind)focusKind;
- (void)startEditorWithHTML:(NSString*)messageHtmlBody subject:(NSString*)subject to:(NSArray<SMAddress*>*)to cc:(NSArray<SMAddress*>*)cc bcc:(NSArray<SMAddress*>*)bcc kind:(SMEditorContentsKind)editorKind mcoAttachments:(NSArray*)mcoAttachments;
- (void)makeHTMLText;
- (void)makePlainText;
- (void)sendMessage;
- (void)deleteEditedDraft;
- (void)toggleBold;
- (void)toggleItalic;
- (void)toggleUnderline;
- (void)toggleBullets;
- (void)toggleNumbering;
- (void)toggleQuote;
- (void)shiftLeft;
- (void)shiftRight;
- (void)selectFont;
- (void)setTextSize;
- (void)justifyText;
- (void)showSource;
- (void)setTextForegroundColor;
- (void)setTextBackgroundColor;
- (BOOL)closeEditor:(BOOL)shouldSaveDraft askConfirmationIfNecessary:(BOOL)askConfirmationIfNecessary;
- (void)saveDocument:(id)sender;
- (void)makeWindow;

#pragma mark Attachments

- (void)openAttachmentDialog;
- (void)toggleAttachmentsPanel:(id)sender;
- (void)attachFile:(NSURL*)url;
- (NSString*)attachInlinedImage:(NSURL*)url;

#pragma mark Find contents panel

- (void)showFindContentsPanel:(BOOL)replace;
- (void)hideFindContentsPanel;
- (void)findContents:(NSString*)stringToFind matchCase:(BOOL)matchCase forward:(BOOL)forward;
- (void)replaceOccurrence:(NSString*)replacement;
- (void)replaceAllOccurrences:(NSString*)replacement;
- (void)removeFindContentsResults;

@end
