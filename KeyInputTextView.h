//
//  KeyInputTextField.h
//  PadderPro
//

#import <Cocoa/Cocoa.h>
#import "KeyboardPickerWindowController.h"
@class TargetController;

@interface KeyInputTextView : NSTextView <KeyboardPickerDelegate> {
    IBOutlet NSWindow         *window;
    IBOutlet TargetController *targetController;
    BOOL     hasKey;
    NSArray  *vkCodes;
    NSString *descr;
    BOOL     enabled;
    KeyboardPickerWindowController *picker;
}

@property(readonly) BOOL    hasKey;
@property(readonly) NSArray *vkCodes;
@property(readonly) NSString *descr;
@property(readwrite) BOOL   enabled;

- (void) clear;
- (void) setVkCodes:(NSArray *)codes descr:(NSString *)d;

@end
