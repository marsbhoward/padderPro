//
//  TargetKeyboard.m
//  PadderPro
//

@implementation TargetKeyboard

@synthesize vkCodes, descr;

-(NSString*) stringify {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSNumber *code in vkCodes)
        [parts addObject:[code stringValue]];
    return [[NSString alloc] initWithFormat:@"key~%@~%@",
            [parts componentsJoinedByString:@","], descr];
}

+(TargetKeyboard*) unstringifyImpl:(NSArray*)comps {
    NSParameterAssert([comps count] == 3);
    TargetKeyboard *t = [[TargetKeyboard alloc] init];
    NSMutableArray *codes = [NSMutableArray array];
    for (NSString *s in [[comps objectAtIndex:1] componentsSeparatedByString:@","])
        [codes addObject:@([s integerValue])];
    [t setVkCodes:codes];
    [t setDescr:[comps objectAtIndex:2]];
    return t;
}

static void postMouseBtn(int button, BOOL down) {
    NSPoint loc = [NSEvent mouseLocation];
    CGFloat h   = [NSScreen mainScreen].frame.size.height;
    CGPoint pt  = CGPointMake(loc.x, h - loc.y);
    CGEventType t;
    switch (button) {
        case 0: t = down ? kCGEventLeftMouseDown   : kCGEventLeftMouseUp;   break;
        case 1: t = down ? kCGEventRightMouseDown  : kCGEventRightMouseUp;  break;
        default:t = down ? kCGEventOtherMouseDown  : kCGEventOtherMouseUp;  break;
    }
    CGEventRef e = CGEventCreateMouseEvent(NULL, t, pt, (CGMouseButton)button);
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
}

static void postKey(CGKeyCode code, BOOL down) {
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef e = CGEventCreateKeyboardEvent(src, code, down);
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
    if (src) CFRelease(src);
}

-(void) trigger:(JoystickController *)jc {
    for (NSNumber *code in vkCodes) {
        int c = [code intValue];
        if (c >= 256) postMouseBtn(c - 256, YES);
        else postKey((CGKeyCode)c, YES);
    }
}

-(void) untrigger:(JoystickController *)jc {
    for (NSNumber *code in [vkCodes reverseObjectEnumerator]) {
        int c = [code intValue];
        if (c >= 256) postMouseBtn(c - 256, NO);
        else postKey((CGKeyCode)c, NO);
    }
}

@end
