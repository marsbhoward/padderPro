//
//  TargetKeyboard.h
//  PadderPro
//
//  Created by Sam McCall on 5/05/09.
//  Copyright 2009 University of Otago. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class Target;

// Codes 256+ are mouse buttons (0-based button index + 256)
#define kPPMouseButton(n) (256 + (n))
#define kPPMouseLeft    256
#define kPPMouseRight   257
#define kPPMouseMiddle  258
#define kPPMouseBack    259
#define kPPMouseForward 260

// Currently-held modifier flags from synthesized modifier keys (Shift/Ctrl/Opt/Cmd/Fn).
// Used so other synthesizers (e.g. mouse movement drags) carry held modifiers.
CGEventFlags PPHeldModifierFlags(void);

@interface TargetKeyboard : Target {
    NSArray  *vkCodes; // NSNumber(CGKeyCode) — one or more keys
    NSString *descr;
}

@property (readwrite, copy) NSArray  *vkCodes;
@property (readwrite, copy) NSString *descr;

+(TargetKeyboard*) unstringifyImpl: (NSArray*) comps;

@end
