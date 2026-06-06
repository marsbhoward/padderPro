//
//  JSActionStick.h
//  PadderPro
//

#import "JSAction.h"

@interface JSActionStick : JSAction {
    void *secondaryCookie;
    double xMin, xMax, yMin, yMax;
    double currentX, currentY;
    double threshold;
    BOOL rotated; // YES = 90° CW: Left→Up, Right→Down, Up→Right, Down→Left
}

@property(readonly) void *secondaryCookie;

// Returns normalized deflection magnitude (0.0–1.0) for the given subaction index.
// 0.0 = just at threshold, 1.0 = fully deflected. Used for proportional cursor speed.
- (double) analogValueForSubActionIndex:(NSUInteger)idx;

- (id) initWithIndex:(int)idx
                name:(NSString *)stickName
             xCookie:(void *)xCook xMin:(double)xmin xMax:(double)xmax
             yCookie:(void *)yCook yMin:(double)ymin yMax:(double)ymax
             rotated:(BOOL)rot;

@end
