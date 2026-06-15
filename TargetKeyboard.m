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

// We track held modifier keys ourselves and stamp the combined flags onto every
// synthetic event. Relying on the system's flag state is unreliable: a synthesized
// modifier key-down doesn't update the global modifier flags unless the event itself
// carries the flag, and games read modifier state (not just the raw keycode).
static CGEventFlags gHeldModifiers = 0;

static CGEventFlags flagForKeycode(int c) {
    switch (c) {
        case 56: case 60: return kCGEventFlagMaskShift;       // L/R Shift
        case 59: case 62: return kCGEventFlagMaskControl;     // L/R Control
        case 58: case 61: return kCGEventFlagMaskAlternate;   // L/R Option
        case 55: case 54: return kCGEventFlagMaskCommand;     // L/R Command
        case 63:          return kCGEventFlagMaskSecondaryFn; // Fn
        case 57:          return kCGEventFlagMaskAlphaShift;  // Caps Lock
        default:          return 0;
    }
}

// Exposed for other synthesizers (mouse movement) so their events carry held modifiers.
CGEventFlags PPHeldModifierFlags(void) { return gHeldModifiers; }

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
    // Preserve any currently-held modifiers (e.g. a concurrent Shift).
    CGEventSetFlags(e, gHeldModifiers);
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
}

static void postKey(CGKeyCode code, BOOL down) {
    // Maintain our own held-modifier set, then stamp it on the event so both the
    // modifier itself and any keys/clicks pressed alongside it register correctly.
    CGEventFlags mod = flagForKeycode((int)code);
    if (mod) {
        if (down) gHeldModifiers |= mod;
        else      gHeldModifiers &= ~mod;
    }
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef e = CGEventCreateKeyboardEvent(src, code, down);
    CGEventSetFlags(e, gHeldModifiers);
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
    if (src) CFRelease(src);
}

// Order codes so modifier keys (Shift/Ctrl/Opt/Cmd/Fn/Caps) come first, regardless of
// the order they were picked. Modifiers must be pressed before the keys/clicks they
// modify (and released after) so e.g. "4 + Ctrl" behaves like "Ctrl + 4".
-(NSArray*) orderedCodesModifiersFirst {
    NSMutableArray *mods = [NSMutableArray array];
    NSMutableArray *others = [NSMutableArray array];
    for (NSNumber *code in vkCodes) {
        int c = [code intValue];
        if (c < 256 && flagForKeycode(c) != 0) [mods addObject:code];
        else [others addObject:code];
    }
    return [mods arrayByAddingObjectsFromArray:others];
}

-(void) trigger:(JoystickController *)jc {
    for (NSNumber *code in [self orderedCodesModifiersFirst]) {
        int c = [code intValue];
        if (c >= 256) postMouseBtn(c - 256, YES);
        else postKey((CGKeyCode)c, YES);
    }
}

-(void) untrigger:(JoystickController *)jc {
    for (NSNumber *code in [[self orderedCodesModifiersFirst] reverseObjectEnumerator]) {
        int c = [code intValue];
        if (c >= 256) postMouseBtn(c - 256, NO);
        else postKey((CGKeyCode)c, NO);
    }
}

@end
