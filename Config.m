//
//  Config.m
//  PadderPro
//
//  Created by Sam McCall on 4/05/09.
//

@implementation Config

-(id) init {
	if(self=[super init]) {
		entries = [[NSMutableDictionary alloc] init];
	}
	return self;
}

@synthesize name, entries;

-(void) setTarget:(Target*)target forAction:(id)jsa {
	[entries setValue:target forKey: [jsa stringify]];
}
-(Target*) getTargetForAction: (id) jsa {
	return [entries objectForKey: [jsa stringify]];
}

// Secondary target: a concurrent key press fired alongside the primary target.
// Stored under a suffixed key so it persists through the same JSON save/load path.
-(NSString*) secondaryKeyFor:(id)jsa {
    return [[jsa stringify] stringByAppendingString:@"~~also"];
}
-(void) setSecondaryTarget:(Target*)target forAction:(id)jsa {
    NSString *key = [self secondaryKeyFor:jsa];
    if (target == NULL)
        [entries removeObjectForKey:key];
    else
        [entries setValue:target forKey:key];
}
-(Target*) getSecondaryTargetForAction:(id)jsa {
    return [entries objectForKey:[self secondaryKeyFor:jsa]];
}

-(void) saveJSONTo:(NSURL *)filename {
    NSMutableDictionary *mapping_dict = [[NSMutableDictionary alloc] init];
    [mapping_dict setObject:name forKey:@"name"];
    [mapping_dict setObject:@"PadderPro-1.1" forKey:@"format"];

    NSMutableDictionary *mapping_entries = [[NSMutableDictionary alloc] init];
    for (id key in entries) {
        [mapping_entries setObject:[[entries objectForKey:key] stringify] forKey:key];
    }
    [mapping_dict setObject:mapping_entries forKey:@"entries"];

    NSError *error = nil;
    NSData *json_data = [NSJSONSerialization dataWithJSONObject:mapping_dict options:0 error:&error];
    if (json_data) {
        [json_data writeToURL:filename atomically:true];
    } else {
        NSLog(@"Failed to serialize mapping to JSON: %@", error);
    }

    [mapping_entries release];
    [mapping_dict release];
}

-(Config*) loadSkelFromJSON:(NSData *)jsonData {
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    name = [dict objectForKey:@"name"];
    return self;
}

-(Config*) loadFromJSON:(NSData *)jsonData withConfigList:(NSArray*)configs {
    NSDictionary *jd = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    NSString *jname = [jd objectForKey:@"name"];
    if (![jname isEqualToString:name]) {
        [NSException raise:@"Loading from JSON with different name" format:@"Loading from JSON with different name", nil];
    }
    
    NSDictionary *entries_d = [jd objectForKey:@"entries"];
    for(id key in entries_d) {
        NSString *value = [entries_d objectForKey:key];
        [entries setObject: [Target unstringify:value withConfigList:configs] forKey:key];
    }
    return self;
}

@end
