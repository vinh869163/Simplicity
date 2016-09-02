//
//  SMURLChooserViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/30/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMURLChooserViewController.h"

@interface SMURLChooserViewController ()
@property (weak) IBOutlet NSTextField *promptLabel;
@property (weak) IBOutlet NSButton *browseFileButton;
@property (weak) IBOutlet NSButton *okButton;
@property (weak) IBOutlet NSButton *cancelButton;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSImageView *imageView;
@end

@implementation SMURLChooserViewController {
    NSOpenPanel *_fileDlg;
    NSURLSessionDataTask *_downloadTask;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _okButton.enabled = NO;
    _cancelButton.enabled = YES;
    _progressIndicator.hidden = NO;
    _progressIndicator.displayedWhenStopped = NO;
}

- (void)chooseImage:(NSImage*)image url:(NSURL*)url {
    [self stopProgress];

    _chosenImage = image? image : [NSImage imageNamed:NSImageNameUserGuest];
    _imageView.image = _chosenImage;
    _okButton.enabled = YES;
}

- (void)startProgress {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_progressIndicator startAnimation:self];
    });
}

- (void)stopProgress {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_progressIndicator stopAnimation:self];
    });
}

- (BOOL)loadLocalImageFileFromUrl:(NSURL*)url {
    if([url checkResourceIsReachableAndReturnError:nil]) {
        NSImage *img = [[NSImage alloc]initWithContentsOfURL:url];
        
        if(img) {
            [self chooseImage:img url:url];
            return TRUE;
        }
    }

    return FALSE;
}

- (void)controlTextDidChange:(NSNotification *)obj {
    [_downloadTask cancel];
    _downloadTask = nil;
    
    NSURL *localPathUrl = [NSURL fileURLWithPath:_urlTextField.stringValue isDirectory:NO];
    if([self loadLocalImageFileFromUrl:localPathUrl]) {
        return;
    }

    NSURL *url = [NSURL URLWithString:_urlTextField.stringValue];
    if(url == nil) {
        return;
    }
    
    if([self loadLocalImageFileFromUrl:url]) {
        return;
    }
    
    [self startProgress];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSession *session = [NSURLSession sharedSession];
    
    _downloadTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSImage *image = nil;
        if(error == nil && data != nil && [response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse*)response).statusCode == 200) {
            image = [[NSImage alloc] initWithData:data];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self chooseImage:image url:url];
        });
    }];
    
    [_downloadTask resume];
}

- (IBAction)urlTextFieldAction:(id)sender {
    NSLog(@"urlTextFieldAction");
}

- (IBAction)browseFileButtonAction:(id)sender {
    if(_fileDlg == nil) {
        _fileDlg = [NSOpenPanel openPanel];
        
        [_fileDlg setCanChooseFiles:YES];
        [_fileDlg setCanChooseDirectories:NO];
        [_fileDlg setPrompt:@"Choose image"];
        [_fileDlg setAllowedFileTypes:[NSImage imageTypes]];
        [_fileDlg setAllowsOtherFileTypes:NO];
        [_fileDlg setAllowsMultipleSelection:NO];
    }

    [_fileDlg beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        NSArray<NSURL*>* files = [_fileDlg URLs];
        for(NSURL* url in files) {
            NSImage *img = nil;
            if(url) {
                img = [[NSImage alloc]initWithContentsOfURL:url];
            }
            
            if(img) {
                _urlTextField.stringValue = url.path;

                [self chooseImage:img url:url];
                break;
            }
        }
        
        [_fileDlg close];
    }];
}

- (IBAction)okButtonAction:(id)sender {
    [self stopProgress];

    if(_target && _actionOk) {
        [_target performSelectorOnMainThread:_actionOk withObject:self waitUntilDone:NO];
    }
}

- (IBAction)cancelButtonAction:(id)sender {
    [self stopProgress];

    if(_target && _actionCancel) {
        [_target performSelectorOnMainThread:_actionCancel withObject:self waitUntilDone:NO];
    }
}

@end
