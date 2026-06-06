//
//  JSActionStick.m
//  PadderPro
//

#import "JSActionStick.h"
#import "SubAction.h"

@implementation JSActionStick

@synthesize secondaryCookie;

- (id) initWithIndex:(int)idx
                name:(NSString *)stickName
             xCookie:(void *)xCook xMin:(double)xmin xMax:(double)xmax
             yCookie:(void *)yCook yMin:(double)ymin yMax:(double)ymax
             rotated:(BOOL)rot {
    if (self = [super init]) {
        index          = idx;
        name           = stickName;
        cookie         = xCook;
        secondaryCookie = yCook;
        xMin = xmin; xMax = xmax;
        yMin = ymin; yMax = ymax;
        rotated   = rot;
        threshold = 0.3;
        currentX  = 0.0;
        currentY  = 0.0;

        subActions = [NSArray arrayWithObjects:
            [[SubAction alloc] initWithIndex:0 name:@"Up"    base:self],
            [[SubAction alloc] initWithIndex:1 name:@"Down"  base:self],
            [[SubAction alloc] initWithIndex:2 name:@"Left"  base:self],
            [[SubAction alloc] initWithIndex:3 name:@"Right" base:self],
            nil
        ];
        [subActions retain];
    }
    return self;
}

- (void) notifyEvent:(IOHIDValueRef)value {
    IOHIDElementRef element = IOHIDValueGetElement(value);
    void *thisCookie = (void *)(uintptr_t)IOHIDElementGetCookie(element);
    int raw = IOHIDValueGetIntegerValue(value);

    if (thisCookie == cookie)
        currentX = -1.0 + 2.0 * (raw - xMin - 0.5) / (xMax - xMin);
    else
        currentY = -1.0 + 2.0 * (raw - yMin - 0.5) / (yMax - yMin);

    BOOL up, down, left, right;
    if (rotated) {
        // Left→Up, Right→Down, Up→Right, Down→Left
        up    = currentX < -threshold;
        down  = currentX >  threshold;
        right = currentY < -threshold;
        left  = currentY >  threshold;
    } else {
        up    = currentY < -threshold;
        down  = currentY >  threshold;
        left  = currentX < -threshold;
        right = currentX >  threshold;
    }

    [[subActions objectAtIndex:0] setActive:up];
    [[subActions objectAtIndex:1] setActive:down];
    [[subActions objectAtIndex:2] setActive:left];
    [[subActions objectAtIndex:3] setActive:right];
}

- (id) findSubActionForValue:(IOHIDValueRef)value {
    IOHIDElementRef element = IOHIDValueGetElement(value);
    void *thisCookie = (void *)(uintptr_t)IOHIDElementGetCookie(element);
    int raw = IOHIDValueGetIntegerValue(value);

    double x = currentX, y = currentY;
    if (thisCookie == cookie)
        x = -1.0 + 2.0 * (raw - xMin - 0.5) / (xMax - xMin);
    else
        y = -1.0 + 2.0 * (raw - yMin - 0.5) / (yMax - yMin);

    if (rotated) {
        if (x < -threshold) return [subActions objectAtIndex:0]; // Up
        if (x >  threshold) return [subActions objectAtIndex:1]; // Down
        if (y < -threshold) return [subActions objectAtIndex:3]; // Right
        if (y >  threshold) return [subActions objectAtIndex:2]; // Left
    } else {
        if (y < -threshold) return [subActions objectAtIndex:0]; // Up
        if (y >  threshold) return [subActions objectAtIndex:1]; // Down
        if (x < -threshold) return [subActions objectAtIndex:2]; // Left
        if (x >  threshold) return [subActions objectAtIndex:3]; // Right
    }
    return nil;
}

- (double) analogValueForSubActionIndex:(NSUInteger)idx {
    // Raw deflection in the subaction's direction (rotated=NO for both sticks)
    // SubAction order: 0=Up(Y-), 1=Down(Y+), 2=Left(X-), 3=Right(X+)
    double deflection = 0.0;
    switch (idx) {
        case 0: deflection = -currentY; break;
        case 1: deflection =  currentY; break;
        case 2: deflection = -currentX; break;
        case 3: deflection =  currentX; break;
    }
    return fmax(0.0, fmin(1.0, deflection));
}

- (BOOL) active {
    for (SubAction *sa in subActions)
        if (sa.active) return YES;
    return NO;
}

- (NSString *) stringify {
    return [[NSString alloc] initWithFormat:@"stick~%d", index];
}

@end
