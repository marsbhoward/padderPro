//
//  JSGroup.m
//  PadderPro
//

#import "JSGroup.h"

@implementation JSGroup

@synthesize name, children;

+ (instancetype)groupNamed:(NSString *)n {
    JSGroup *g = [[JSGroup alloc] init];
    [g setName:n];
    return g;
}

- (id)init {
    if (self = [super init]) {
        children = [[NSMutableArray alloc] init];
    }
    return self;
}

@end
