#import <Foundation/Foundation.h>
#include <ApplicationServices/ApplicationServices.h>
#import "key-tap.h"

@implementation LoggerConfig

@synthesize output;
@synthesize epoch;

@end

/* CGEventTapCallBack function signature:
    proxy
        A proxy for the event tap. See CGEventTapProxy. This callback function may pass this proxy to other functions such as the event-posting routines.
    type
        The event type of this event. See “Event Types.”
    event
        The incoming event. This event is owned by the caller, and you do not need to release it.
    refcon
        A pointer to user-defined data. You specify this pointer when you create the event tap. Several different event taps could use the same callback function, each tap with its own user-defined data.
*/
CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    LoggerConfig *config = (__bridge LoggerConfig *)refcon;
    @autoreleasepool {
        NSMutableArray *modifiers = [NSMutableArray arrayWithCapacity:10];
        CGEventFlags flags = CGEventGetFlags(event);
        if ((flags & kCGEventFlagMaskShift) == kCGEventFlagMaskShift)
            [modifiers addObject:@"shift"];
        if ((flags & kCGEventFlagMaskControl) == kCGEventFlagMaskControl)
            [modifiers addObject:@"control"];
        if ((flags & kCGEventFlagMaskAlternate) == kCGEventFlagMaskAlternate)
            [modifiers addObject:@"alt"];
        if ((flags & kCGEventFlagMaskCommand) == kCGEventFlagMaskCommand)
            [modifiers addObject:@"command"];
        if ((flags & kCGEventFlagMaskSecondaryFn) == kCGEventFlagMaskSecondaryFn)
            [modifiers addObject:@"fn"];

        // Ignoring the following flags:
        //     kCGEventFlagMaskAlphaShift =    NX_ALPHASHIFTMASK,
        //     kCGEventFlagMaskHelp =          NX_HELPMASK,
        //     kCGEventFlagMaskNumericPad =    NX_NUMERICPADMASK,
        //     kCGEventFlagMaskNonCoalesced =  NX_NONCOALSESCEDMASK

        NSString *modifierString = [modifiers componentsJoinedByString:@"+"];

        // The incoming keycode. CGKeyCode is just a typedef of uint16_t, so we treat it like an int
        CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        // CGEventKeyboardGetUnicodeString
        // Keypress code goes here.
        NSString *action;
        if (type == kCGEventKeyDown)
            action = @"down";
        else if (type == kCGEventKeyUp)
            action = @"up";
        else
            action = @"other";

        NSTimeInterval offset = [[NSDate date] timeIntervalSince1970] - config.epoch;

        // logLine format:
        // ticks since started <TAB> key code <TAB> action <TAB> modifiers
        // so it'll look something like "13073    45    up    shift+command"
        NSString *logLine = [NSString stringWithFormat:@"%d\t%d\t%@\t%@\n",
            (int)offset, keycode, action, modifierString];
        NSLog(@"> %@", logLine);
        [config.output writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
    }
    // We must return the event for it to be useful.
    return event;
}

int main(void) {
    // set up the file that we'll be logging into
    // NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    LoggerConfig *config = [[LoggerConfig alloc] init];
    NSUserDefaults *args = [NSUserDefaults standardUserDefaults];

    // grabs command line arguments --directory
    NSString *directory = [args stringForKey:@"directory"];
    if (!directory) {
        // default to /var/log/osx-tap
        directory = @"/var/log/osx-tap";
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];

    // create directory if needed (since withIntermediateDirectories:YES,
    //   this shouldn't fail if the directory already exists)
    bool directory_success = [fileManager createDirectoryAtPath:directory
        withIntermediateDirectories:YES attributes:nil error:nil];
    if (!directory_success) {
        NSLog(@"Could not create directory: %@", directory);
        return 1;
    }

    config.epoch = [[NSDate date] timeIntervalSince1970];
    NSString *filename = [NSString stringWithFormat:@"%d.log", (int)config.epoch];
    NSString *filepath = [NSString pathWithComponents:@[directory, filename]];
    bool create_success = [fileManager createFileAtPath:filepath contents:nil attributes:nil];
    if (!create_success) {
        NSLog(@"Could not create file: %@", filepath);
        return 1;
    }

    // now that it's been created, we can open the file
    config.output = [NSFileHandle fileHandleForWritingAtPath:filepath];
    // [config.output seekToEndOfFile];

    // Create an event tap. We are interested in key ups and downs.
    CGEventMask eventMask = ((1 << kCGEventKeyDown) | (1 << kCGEventKeyUp));
    /*
    CGEventTapCreate(CGEventTapLocation tap, CGEventTapPlacement place,
        CGEventTapOptions options, CGEventMask eventsOfInterest,
        CGEventTapCallBack callback, void *refcon

    CGEventTapLocation tap:
        kCGHIDEventTap
            Specifies that an event tap is placed at the point where HID system events enter the window server.
        kCGSessionEventTap
            Specifies that an event tap is placed at the point where HID system and remote control events enter a login session.
        kCGAnnotatedSessionEventTap
            Specifies that an event tap is placed at the point where session events have been annotated to flow to an application.

    CGEventTapPlacement place:
        kCGHeadInsertEventTap
            Specifies that a new event tap should be inserted before any pre-existing event taps at the same location.
        kCGTailAppendEventTap
            Specifies that a new event tap should be inserted after any pre-existing event taps at the same location.

    CGEventTapOptions options:
       kCGEventTapOptionDefault = 0x00000000
       kCGEventTapOptionListenOnly = 0x00000001

    ...

    CGEventTapCallBack has arguments:
        (CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)

    */
    // we don't want to discard config
    // CFBridgingRetain(config);
    CFMachPortRef eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0,
        eventMask, myCGEventCallback, (__bridge void *)config);

    if (!eventTap) {
        NSLog(@"failed to create event tap");
        return 1;
    }
    if (!CGEventTapIsEnabled(eventTap)) {
        NSLog(@"event tap is not enabled");
        return 1;
    }

    /* Create a run loop source.

    allocator
        The allocator to use to allocate memory for the new object. Pass NULL or kCFAllocatorDefault to use the current default allocator.
    port
        The Mach port for which to create a CFRunLoopSource object.
    order
        A priority index indicating the order in which run loop sources are processed. order is currently ignored by CFMachPort run loop sources. Pass 0 for this value.
    */
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);

    /* Adds a CFRunLoopSource object to a run loop mode.
    CFRunLoopAddSource(CFRunLoopRef rl, CFRunLoopSourceRef source, CFStringRef mode);

    rl
        The run loop to modify.
    source
        The run loop source to add. The source is retained by the run loop.
    mode
        The run loop mode to which to add source. Use the constant kCFRunLoopCommonModes to add source to the set of objects monitored by all the common modes.
    */
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);

    // Enable the event tap.
    // CGEventTapEnable(eventTap, true);

    // Runs the current thread’s CFRunLoop object in its default mode indefinitely:
    CFRunLoopRun();

    return 0;
}
