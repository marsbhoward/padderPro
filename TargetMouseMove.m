//
//  TargetMouseMove.m
//  PadderPro
//

#import "TargetMouseMove.h"

@implementation TargetMouseMove

-(BOOL) isContinuous { return YES; }

@synthesize dir, speed;

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

-(void) trigger:(JoystickController *)jc  { inputValue = 0.0; }
-(void) untrigger:(JoystickController *)jc { }

-(void) update:(JoystickController *)jc {
    if (![self running]) return;

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
}

@end
