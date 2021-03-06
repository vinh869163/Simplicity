//
//  SMViewController.h
//  CustomTokenField
//
//  Created by Evgeny Baskakov on 2/11/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMTokenView;
@class SMTokenEditView;
@class SMTokenFieldBox;
@class SMClickThroughTextField;

@interface SMTokenFieldViewController : NSViewController<NSTextViewDelegate>

@property (weak) IBOutlet NSScrollView *scrollView;
@property (weak) IBOutlet SMTokenFieldBox *boxView;
@property (weak) IBOutlet NSView *innerView;
@property (weak) IBOutlet SMClickThroughTextField *placeholderLabel;

@property (readonly) BOOL tokenSelectionActive;

@property id target;
@property SEL action;
@property SEL cancelAction;
@property SEL enterAction;
@property SEL clearAction;
@property SEL tokenEditAction;
@property SEL arrowUpAction;
@property SEL arrowDownAction;
@property NSTimeInterval actionDelay;

@property (readonly) NSArray *representedTokenObjects;
@property (readonly) NSUInteger tokenCount;
@property (readonly) NSString *stringValue;

- (void)getFocus;
- (void)releaseFocus;
- (void)addToken:(NSString*)tokenName contentsText:(NSString*)contentsText representedObject:(NSObject*)representedObject target:(id)target action:(SEL)action editedAction:(SEL)editedAction deletedAction:(SEL)deletedAction;
- (SMTokenView*)changeToken:(SMTokenView*)tokenView tokenName:(NSString*)tokenName contentsText:(NSString*)contentsText representedObject:(NSObject*)representedObject target:(id)target action:(SEL)action editedAction:(SEL)editedAction deletedAction:(SEL)deletedAction;
- (void)deleteToken:(SMTokenView*)tokenView;
- (void)editToken:(SMTokenView*)token;
- (void)cursorLeftFrom:(SMTokenEditView*)sender jumpToBeginning:(BOOL)jumpToBeginning extendSelection:(BOOL)extendSelection;
- (void)cursorRightFrom:(SMTokenEditView*)sender jumpToEnd:(BOOL)jumpToEnd extendSelection:(BOOL)extendSelection;
- (void)clearCursorSelection;
- (void)tokenMouseDown:(SMTokenView*)token event:(NSEvent *)theEvent;
- (void)clickWithinTokenEditor:(SMTokenEditView*)tokenEditor;
- (void)deleteSelectedTokensAndText;
- (void)deleteAllTokensAndText;
- (void)triggerCancel:(SMTokenEditView*)sender;
- (void)triggerArrowUp:(SMTokenEditView*)sender;
- (void)triggerArrowDown:(SMTokenEditView*)sender;
- (void)triggerEnter:(SMTokenEditView*)sender;
- (void)startProgress;
- (void)stopProgress;

@end

