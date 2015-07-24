//
//  SMMessageEditorViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/13/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <WebKit/WebUIDelegate.h>

#import <MailCore/MailCore.h>

#import "SMTokenField.h"
#import "SMColorWellWithIcon.h"
#import "SMEditorToolBoxViewController.h"
#import "SMLabeledTokenFieldBoxViewController.h"
#import "SMAttachmentItem.h"
#import "SMAttachmentsPanelViewController.h"
#import "SMMessageEditorBase.h"
#import "SMMessageEditorController.h"
#import "SMMessageEditorWebView.h"
#import "SMMessageEditorViewController.h"

@implementation SMMessageEditorViewController {
    SMMessageEditorBase *_messageEditorBase;
    SMMessageEditorController *_messageEditorController;
    SMEditorToolBoxViewController *_editorToolBoxViewController;
    SMAttachmentsPanelViewController *_attachmentsPanelViewController;
    NSMutableArray *_attachmentsPanelViewConstraints;
    Boolean _attachmentsPanelShown;
}

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil embedded:(Boolean)embedded {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if(self) {
        _embedded = embedded;

        _messageEditorBase = [[SMMessageEditorBase alloc] init];
        _messageEditorController = [[SMMessageEditorController alloc] init];
        
        // To
        
        _toBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
        
        // Cc
        
        _ccBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
        
        // Bcc
        
        _bccBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
        
        // editor toolbox
        
        _editorToolBoxViewController = [[SMEditorToolBoxViewController alloc] initWithNibName:@"SMEditorToolBoxViewController" bundle:nil];
        _editorToolBoxViewController.messageEditorViewController = self;
        
        // register events
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processAddressFieldEditingEnd:) name:@"LabeledTokenFieldEndedEditing" object:nil];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // To

    [_toBoxViewController addControlSwitch:self action:@selector(toggleFullAddressPanel:)];
    
    [_toBoxView addSubview:_toBoxViewController.view];
    
    [_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    
    [_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    [_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    
    [_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    
    if(!_embedded) {
        // Cc
        
        [_ccBoxView addSubview:_ccBoxViewController.view];
        
        [_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
        
        [_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
        
        [_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
        
        [_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
        
        // Bcc
        
        [_bccBoxView addSubview:_bccBoxViewController.view];
        
        [_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
        
        [_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
        
        [_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
        
        [_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    }
    else {
        // In the embedded mode, reduce the number of editor controls.
        
        NSView *view = [self view];
        
        [view removeConstraint:_ccTopConstraint];
        [view removeConstraint:_ccLeadingConstraint];
        [view removeConstraint:_ccTrailingConstraint];
        
        [view removeConstraint:_bccTopConstraint];
        [view removeConstraint:_bccLeadingConstraint];
        [view removeConstraint:_bccTrailingConstraint];
        
        [view removeConstraint:_subjectTopConstraint];
        [view removeConstraint:_subjectLeadingConstraint];
        [view removeConstraint:_subjectTrailingConstraint];
        
        [view removeConstraint:_toolboxTopConstraint];
        
        [_ccBoxView removeFromSuperview];
        [_bccBoxView removeFromSuperview];
        [_subjectBoxView removeFromSuperview];
        
        _toolboxTopConstraint = [NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_editorToolBoxView attribute:NSLayoutAttributeTop multiplier:1 constant:1];
        
        [view addConstraint:_toolboxTopConstraint];
    }
    
    // editor toolbox
    
    [_editorToolBoxView addSubview:_editorToolBoxViewController.view];
    
    [_editorToolBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_editorToolBoxView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_editorToolBoxViewController.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    
    [_editorToolBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_editorToolBoxView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_editorToolBoxViewController.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    [_editorToolBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_editorToolBoxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_editorToolBoxViewController.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    
    [_editorToolBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_editorToolBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_editorToolBoxViewController.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];

    // Controls initialization
    
    [_toBoxViewController.label setStringValue:@"To:"];
    [_ccBoxViewController.label setStringValue:@"Cc:"];
    [_bccBoxViewController.label setStringValue:@"Bcc:"];
    
    [_editorToolBoxViewController.sendButton setEnabled:NO];
    
    // Editor toolbox
    NSAssert(_editorToolBoxViewController != nil, @"editor toolbox is nil");
    
    [_editorToolBoxViewController.fontSelectionButton removeAllItems];
    [_editorToolBoxViewController.fontSelectionButton addItemsWithTitles:[SMMessageEditorBase fontFamilies]];
    [_editorToolBoxViewController.fontSelectionButton selectItemAtIndex:0];
    
    NSArray *textSizes = [[NSArray alloc] initWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", nil];
    
    [_editorToolBoxViewController.textSizeButton removeAllItems];
    [_editorToolBoxViewController.textSizeButton addItemsWithTitles:textSizes];
    [_editorToolBoxViewController.textSizeButton selectItemAtIndex:2];
    
    _editorToolBoxViewController.textForegroundColorSelector.icon = [NSImage imageNamed:@"Editing-Text-icon.png"];
    _editorToolBoxViewController.textBackgroundColorSelector.icon = [NSImage imageNamed:@"Text-Marker.png"];
    
    // WebView post-setup
    
    _messageTextEditor.messageEditorBase = _messageEditorBase;
    _messageTextEditor.editorToolBoxViewController = _editorToolBoxViewController;
}

- (NSUInteger)editorFullHeight {
    NSAssert(_embedded, @"editor height is implemented for embedded mode only");
    return _toBoxViewController.view.frame.size.height + _editorToolBoxViewController.view.frame.size.height + _messageTextEditor.contentHeight - 2; // TODO: better spec. of this '2' - that's because of overlapping 'to', 'subject' and editor views
}

#pragma mark Message actions

- (void)sendMessage {
    NSString *messageText = [_messageTextEditor getMessageText];
    
    [_messageEditorController sendMessage:messageText subject:_subjectField.stringValue to:_toBoxViewController.tokenField.stringValue cc:_ccBoxViewController.tokenField.stringValue bcc:_bccBoxViewController.tokenField.stringValue];

    if(!_embedded) {
        [[[self view] window] close];
    }
}

- (void)deleteMessage {
    NSLog(@"%s: TODO - save the message to drafts", __func__);

    [self saveMessage];

    if(!_embedded) {
        [[[self view] window] close];
    }
    else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DeleteMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self, @"MessageEditorViewController", nil]];
    }
}

- (void)saveMessage {
    NSString *messageText = [_messageTextEditor getMessageText];
    NSString *subject = _subjectField.stringValue;
    NSString *to = _toBoxViewController.tokenField.stringValue;
    NSString *cc = _ccBoxViewController.tokenField.stringValue;
    NSString *bcc = _bccBoxViewController.tokenField.stringValue;
    
    if(subject == nil) {
        subject = @"TODO: subject";
    }
    
    if(to == nil) {
        to = @"TODO: to";
    }
    
    if(cc == nil) {
        cc = @"TODO: cc";
    }
    
    if(bcc == nil) {
        bcc = @"TODO: bcc";
    }

    [_messageEditorController saveDraft:messageText subject:subject to:to cc:cc bcc:bcc];
}

- (void)attachDocument {
    [self toggleAttachmentsPanel];
}

#pragma mark Text attrbitute actions

- (void)toggleBold {
    [_messageTextEditor toggleBold];
}

- (void)toggleItalic {
    [_messageTextEditor toggleItalic];
}

- (void)toggleUnderline {
    [_messageTextEditor toggleUnderline];
}

- (void)toggleBullets {
    [_messageTextEditor toggleBullets];
}

- (void)toggleNumbering {
    [_messageTextEditor toggleNumbering];
}

- (void)toggleQuote {
    [_messageTextEditor toggleQuote];
}

- (void)shiftLeft {
    [_messageTextEditor shiftLeft];
}

- (void)shiftRight {
    [_messageTextEditor shiftRight];
}

- (void)selectFont {
    [_messageTextEditor selectFont:[_editorToolBoxViewController.fontSelectionButton indexOfSelectedItem]];
}

- (void)setTextSize {
    NSInteger index = [_editorToolBoxViewController.textSizeButton indexOfSelectedItem];
    
    if(index < 0 || index >= _editorToolBoxViewController.textSizeButton.numberOfItems) {
        NSLog(@"%s: selected text size value index %ld is out of range", __func__, index);
        return;
    }
    
    NSInteger textSize = [[_editorToolBoxViewController.textSizeButton itemTitleAtIndex:index] integerValue];
    
    [_messageTextEditor setTextSize:textSize];
}

- (void)justifyText {
    [_messageTextEditor justifyText:[_editorToolBoxViewController.justifyTextControl selectedSegment]];
}

- (void)showSource {
    [_messageTextEditor showSource];
}

- (void)setTextForegroundColor {
    [_messageTextEditor setTextForegroundColor:_editorToolBoxViewController.textForegroundColorSelector.color];
}

- (void)setTextBackgroundColor {
    [_messageTextEditor setTextBackgroundColor:_editorToolBoxViewController.textBackgroundColorSelector.color];
}

#pragma mark UI elements collaboration

- (void)toggleFullAddressPanel:(id)sender {
    NSButton *controlSwitch = sender;

    if(controlSwitch.state == NSOnState) {
        NSLog(@"control panel is on");
    }
    else if(controlSwitch.state == NSOffState) {
        NSLog(@"control panel is off");
    }
    else {
        NSAssert(false, @"unknown controlSwitch state %ld", controlSwitch.state);
    }
}

- (void)processAddressFieldEditingEnd:(NSNotification*)notification {
    id object = [notification object];
    
    if(object == _toBoxViewController) {
        NSString *toValue = [[_toBoxViewController.tokenField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \t"]];
        
        // TODO: verify the destination email address / recepient name more carefully
        
        [_editorToolBoxViewController.sendButton setEnabled:(toValue.length != 0)];
    }
}

#pragma mark Attachments panel

- (void)toggleAttachmentsPanel {
    if(!_attachmentsPanelShown) {
        [self showAttachmentsPanel];
    } else {
        [self hideAttachmentsPanel];
    }
}

- (void)showAttachmentsPanel {
    if(_attachmentsPanelShown)
        return;
    
    NSView *view = [self view];
    NSAssert(view != nil, @"view is nil");
    
    NSAssert(_messageEditorBottomConstraint != nil, @"_messageEditorBottomConstraint not created");
    [view removeConstraint:_messageEditorBottomConstraint];
    
    if(_attachmentsPanelViewController == nil) {
        _attachmentsPanelViewController = [[SMAttachmentsPanelViewController alloc] initWithNibName:@"SMAttachmentsPanelViewController" bundle:nil];
        
        NSView *attachmentsView = _attachmentsPanelViewController.view;
        NSAssert(attachmentsView, @"attachmentsView");
        
        NSAssert(_attachmentsPanelViewConstraints == nil, @"_attachmentsPanelViewConstraints already created");
        _attachmentsPanelViewConstraints = [NSMutableArray array];
        
        [_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageTextEditor attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
        
        [_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
        
        [_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
        
        [_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];
        
        [_attachmentsPanelViewController enableEditing:_messageEditorController];
    }
    
    [view addSubview:_attachmentsPanelViewController.view];
    [view addConstraints:_attachmentsPanelViewConstraints];
    
    _attachmentsPanelShown = YES;
}

- (void)hideAttachmentsPanel {
    if(!_attachmentsPanelShown)
        return;
    
    NSView *view = [self view];
    NSAssert(view != nil, @"view is nil");
    
    NSAssert(_attachmentsPanelViewConstraints != nil, @"_attachmentsPanelViewConstraints not created");
    [view removeConstraints:_attachmentsPanelViewConstraints];
    
    [_attachmentsPanelViewController.view removeFromSuperview];
    
    NSAssert(_messageEditorBottomConstraint != nil, @"_messageEditorBottomConstraint not created");
    [view addConstraint:_messageEditorBottomConstraint];
    
    _attachmentsPanelShown = NO;
}

#pragma mark Misc

- (void)closeEditor {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_messageEditorController closeEditor];
    [_messageTextEditor stopTextMonitor];
}

@end
