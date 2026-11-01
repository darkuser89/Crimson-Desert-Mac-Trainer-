// SPDX-License-Identifier: GPL-3.0-only
#import "CrimsonAdapter.h"
#import "CrimsonNative.h"
#import "OverlayShortcuts.h"
#include <math.h>
void MTPresentationRunTests(void);
void CDRuntimeRunTests(void) {
    NSCAssert(!CDCorrectBuild(),@"Test host is not the supported game image");
    NSCAssert(!CDSetPlayerStatRatio(0,1,1) && !CDSetPlayerStatRatio(3,1,1)
        && !CDSetPlayerStatRatio(0,NAN,1) && !CDSetPlayerStatRatio(0,-1,1)
        && !CDSetOverlayInteraction(YES),@"Unsupported process never invokes native addresses");
    NSCAssert(!CDRequestEffect(0,YES,0,1) && !CDRequestEffect(7,YES,15,1) && !CDRequestEffect(12,YES,797522,1) && !CDRequestEffect(13,YES,0,1),@"New effects and transactions reject an unsupported host before resolving any native address");
    CDReleaseEffects();
    MTOverlayShortcuts *keys=[MTOverlayShortcuts new];keys.enabled=YES;
    [keys setRegistered:YES keyCode:10 shortcut:MTShortcutPanel];
    NSEvent *alias=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:50];
    NSCAssert(MTShortcutForEvent(alias)==MTShortcutPanel && ![keys ownsLocalEvent:alias],@"Unregistered ANSI alias retains local fallback");
    [keys setRegistered:YES keyCode:50 shortcut:MTShortcutPanel];
    NSCAssert([keys ownsLocalEvent:alias],@"Registered alias consumes its AppKit echo");
    __block int toggles=0;keys.handler=^(MTOverlayShortcut action){(void)action;toggles++;};
    [keys nativeShortcut:MTShortcutPanel pressed:YES];[keys nativeShortcut:MTShortcutPanel pressed:YES];
    NSCAssert(toggles==1,@"Physical aliases cannot duplicate a held action");
    [keys nativeShortcut:MTShortcutPanel pressed:NO];[keys nativeShortcut:MTShortcutPanel pressed:YES];
    NSCAssert(toggles==2,@"Fresh alias press opens once");
    MTUseCrimsonFeatures();
    NSCAssert(MTFeatureCount==13,@"Complete image catalog with separate money action");
    NSMutableSet *hotkeys=[NSMutableSet new];
    for(NSInteger i=0;i<MTFeatureCount;i++) {
        const MTFeatureInfo *info=MTFeatureInfoAt(i);
        NSCAssert(info->oneShot==(i==7 || i==11 || i==12),@"Only explicit inventory/time actions are one-shots");
        [hotkeys addObject:[NSString stringWithFormat:@"%u/%lu",info->key,(unsigned long)info->modifiers]];
    }
    NSCAssert(hotkeys.count==(NSUInteger)MTFeatureCount,@"Unique physical key and modifier combinations");
    __block NSDictionary *snapshot=@{@"buildMatched":@YES,@"thread":@"GameThread",@"actorKey":@123,@"fieldIndex":@1,
        @"health":@{@"raw":@300000,@"rawMaximum":@300000,@"rawMinimum":@0,@"value":@300,@"maximum":@300},
        @"stamina":@{@"raw":@120000,@"rawMaximum":@120000,@"value":@120,@"maximum":@120},
        @"spirit":@{@"raw":@30000,@"rawMaximum":@30000,@"value":@30,@"maximum":@30},@"seconds":@10000};
    NSMutableArray *requests=[NSMutableArray new];__block NSUInteger releases=0;
    CDCrimsonAdapter *adapter=[[CDCrimsonAdapter alloc]initWithReader:^{return snapshot;}
        requester:^BOOL(unsigned feature,BOOL wanted,double value,uint32_t key){[requests addObject:@[@(feature),@(wanted),@(value),@(key)]];return YES;}
        releaser:^{releases++;} cursor:^BOOL(BOOL wanted){return wanted;}];
    MTGameContext *initial=[adapter captureContext];NSCAssert(initial.kind==MTSessionSolo,@"Valid owned context");
    NSCAssert(![adapter applyFeature:0 wanted:YES value:0].active && requests.count==1,@"Full health and queue acceptance alone are not proof of protection");
    NSMutableDictionary *full=[snapshot mutableCopy];
    NSDictionary *protectedStat=@{@"raw":@300000,@"rawMaximum":@300000,@"rawMinimum":@300000,@"value":@300,@"maximum":@300};
    full[@"health"]=protectedStat;
    full[@"server"]=@{@"actorKey":@999,@"serverThread":@YES,@"health":protectedStat};snapshot=full;
    [adapter captureContext];NSCAssert(![adapter applyFeature:0 wanted:YES value:0].active,@"Stale server owner rejected");
    full[@"server"]=@{@"actorKey":@123,@"serverThread":@YES,@"health":protectedStat};snapshot=[full copy];
    [adapter captureContext];NSCAssert([adapter applyFeature:0 wanted:YES value:0].active,@"Matching client and authoritative floor confirms protection");
    NSCAssert(![adapter applyFeature:0 wanted:NO value:0].active && ![requests.lastObject[1] boolValue],@"Disable issues native release");
    NSUInteger count=requests.count;[adapter applyFeature:0 wanted:NO value:0];
    NSCAssert(requests.count==count,@"Inactive polling does not issue redundant releases");
    NSCAssert(![adapter applyFeature:7 wanted:NO value:99].available,@"Closed inventory has no selected-item action");
    [adapter performOneShot:7 value:99];NSCAssert(requests.count==count,@"No implicit fallback from missing selected item to money");
    [adapter performOneShot:11 value:0];NSCAssert(requests.count==count+1,@"Time one-shot runs exactly once");
    [adapter applyFeature:11 wanted:NO value:0];NSCAssert(requests.count==count+1,@"One-shots are not repeated by polling");
    full=[snapshot mutableCopy];full[@"actorKey"]=@456;full[@"fieldIndex"]=@2;snapshot=full;
    NSCAssert(![[adapter captureContext].identity isEqual:initial.identity],@"Travel/owner changes context");
    [adapter releaseEffects];NSCAssert(releases==1,@"Context release invokes native ownership cleanup");
    [adapter performOneShot:11 value:0];NSCAssert([requests.lastObject[3] isEqual:@456],@"One-shot targets newly validated owner");
    snapshot=@{@"buildMatched":@YES,@"thread":@"GameThread",@"loading":@YES};
    NSCAssert([adapter captureContext].kind==MTSessionLoading,@"Missing actor is loading");
    count=requests.count;[adapter performOneShot:11 value:0];
    NSCAssert(![adapter applyFeature:0 wanted:YES value:0].available && requests.count==count,@"Loading drops actions and performs no writes");
    snapshot=@{@"buildMatched":@YES,@"thread":@"Worker",@"actorKey":@999};
    NSCAssert([adapter captureContext].kind==MTSessionUnsupported && ![adapter applyFeature:0 wanted:YES value:0].available,@"Wrong thread never exposes effects");
    MTPresentationRunTests();
    MTUseDemoFeatures();NSCAssert(MTFeatureCount==6,@"Original demo keeps its six simulated examples");
    puts("Crimson synthetic checks passed: 13 controls, owner/readback validation, native cleanup, explicit one-shots, loading and thread guard.");
}
