//
//  JSGroup.h
//  PadderPro
//
//  A non-selectable grouping node for the controller outline (e.g. "Combos",
//  "Left Trigger"). Exposes -name so the outline renders it like any other row.
//

#import <Cocoa/Cocoa.h>

@interface JSGroup : NSObject {
    NSString *name;
    NSMutableArray *children;
}

@property(readwrite, copy) NSString *name;
@property(readonly) NSMutableArray *children;

+ (instancetype)groupNamed:(NSString *)name;

@end
