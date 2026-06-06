//
//  TargetMouseMove.h
//  PadderPro
//
//  Created by Yifeng Huang on 7/26/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Target.h"

@interface TargetMouseMove : Target {
    int dir;
    int speed; // 1–10, default 3
}

@property(readwrite) int dir;
@property(readwrite) int speed;

+(TargetMouseMove*) unstringifyImpl: (NSArray*) comps;

@end
