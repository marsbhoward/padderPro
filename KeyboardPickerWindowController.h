//
//  KeyboardPickerWindowController.h
//  PadderPro
//

#import <Cocoa/Cocoa.h>

@protocol KeyboardPickerDelegate <NSObject>
- (void)keyboardPickerDidFinishWithCodes:(NSArray *)codes descr:(NSString *)descr;
@end

@interface KeyboardPickerWindowController : NSWindowController

@property (nonatomic, weak) id<KeyboardPickerDelegate> delegate;

- (void)showWithInitialCodes:(NSArray *)codes;

@end
