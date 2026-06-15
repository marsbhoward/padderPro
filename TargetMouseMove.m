//
//  TargetMouseMove.m
//  PadderPro
//

#import "TargetMouseMove.h"

@implementation TargetMouseMove

-(BOOL) isContinuous { return YES; }

@synthesize dir, speed, leadDelay;

-(id) init {
    if (self = [super init]) {
        speed = 3;
    }
    return self;
}

-(NSString*) stringify {
    return [[NSString alloc] initWithFormat:@"mmove~%d~%d", dir, speed];
}

+(TargetMouseMove*) unstringifyImpl:(NSArray*)comps {
    TargetMouseMove *target = [[TargetMouseMove alloc] init];
    [target setDir:[[comps objectAtIndex:1] integerValue]];
    if ([comps count] >= 3)
        [target setSpeed:[[comps objectAtIndex:2] integerValue]];
    return target;
}

-(void) trigger:(JoystickController *)jc  {
    inputValue = 0.0;
    activatedAt = CFAbsoluteTimeGetCurrent();
}
-(void) untrigger:(JoystickController *)jc { }

-(void) update:(JoystickController *)jc {
    if (![self running]) return;

    // When a concurrent key/button is mapped alongside this movement, hold off on
    // moving for a brief lead-in so the key/button registers as "down" first.
    // This makes held-button drags reliable (the button is down before the drag starts).
    if (leadDelay) {
        static const double kLeadSeconds = 0.05;
        if (CFAbsoluteTimeGetCurrent() - activatedAt < kLeadSeconds)
            return;
    }

    NSRect screenRect = [[NSScreen mainScreen] frame];
    double height = screenRect.size.height;

    // inputValue is the stick's deflection magnitude (0.0 = just past threshold, 1.0 = fully pushed)
    // 0.0 means button-triggered (no stick) → use full speed
    double deflection = (self.inputValue < 0.01) ? 1.0 : self.inputValue;
    double pxPerTick = speed * 3.0 * deflection;
    double dx = 0.0, dy = 0.0;

    // dir: 0=Up, 1=Down, 2=Left, 3=Right
    // dy positive = down (AppKit y subtracted to lower y = move down)
    switch (dir) {
        case 0: dy = -pxPerTick; break; // Up
        case 1: dy = +pxPerTick; break; // Down
        case 2: dx = -pxPerTick; break; // Left
        case 3: dx = +pxPerTick; break; // Right
    }

    NSPoint *mouseLoc = &jc->mouseLoc;
    mouseLoc->x += dx;
    mouseLoc->y -= dy;

    // Clamp to screen
    mouseLoc->x = fmax(0, fmin(mouseLoc->x, screenRect.size.width));
    mouseLoc->y = fmax(0, fmin(mouseLoc->y, height));

    CGPoint cgPos = CGPointMake(mouseLoc->x, height - mouseLoc->y);
    CGWarpMouseCursorPosition(cgPos);
    CGAssociateMouseAndMouseCursorPosition(true);

    // If a mouse button is currently held (e.g. via a concurrent "Also press key"
    // mapped to a mouse button), emit the matching drag event so the held button
    // drags along with the movement instead of staying put. A bare warp produces
    // no events, so without this the held button never registers as a drag.
    CGEventSourceStateID st = kCGEventSourceStateCombinedSessionState;
    CGEventType dragType = 0;
    CGMouseButton btn = kCGMouseButtonLeft;
    if (CGEventSourceButtonState(st, kCGMouseButtonLeft)) {
        dragType = kCGEventLeftMouseDragged;  btn = kCGMouseButtonLeft;
    } else if (CGEventSourceButtonState(st, kCGMouseButtonRight)) {
        dragType = kCGEventRightMouseDragged; btn = kCGMouseButtonRight;
    } else if (CGEventSourceButtonState(st, kCGMouseButtonCenter)) {
        dragType = kCGEventOtherMouseDragged; btn = kCGMouseButtonCenter;
    }
    if (dragType) {
        CGEventRef drag = CGEventCreateMouseEvent(NULL, dragType, cgPos, btn);
        // Preserve held modifiers (e.g. Shift) across drag events.
        CGEventSetFlags(drag, PPHeldModifierFlags());
        CGEventSetIntegerValueField(drag, kCGMouseEventDeltaX, (int64_t)dx);
        CGEventSetIntegerValueField(drag, kCGMouseEventDeltaY, (int64_t)dy);
        CGEventPost(kCGHIDEventTap, drag);
        CFRelease(drag);
    }
}

@end
