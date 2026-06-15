//
//  SubAction.m
//  PadderPro
//
//  Created by Sam McCall on 5/05/09.
//

@implementation SubAction

@synthesize base, name, index, active;

-(id) initWithIndex:(int)newIndex name: (NSString*)newName base: (JSAction*)newBase {
	if(self = [super init]) {
		[self setName: newName];
		[self setBase: newBase];
		[self setIndex: newIndex];
	}
	return self;
}

-(NSString*) stringify {
	return [[NSString alloc] initWithFormat: @"%@~%d", [base stringify], index];
}

// Combo member: held when this direction is active; it carries its own target.
-(BOOL) isHeld { return active; }
-(NSArray*) suppressibleSubactions { return @[self]; }
// Identify a hat direction by its hat's cookie plus the direction index.
-(NSString*) comboToken {
	return [NSString stringWithFormat:@"%d.%d", (int)(intptr_t)[base cookie], index];
}

@end
