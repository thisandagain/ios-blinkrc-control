//
//  Game.m
//  AppScaffold
//

#import "Game.h" 

@implementation Game

/**
 * Init With Width (Standard)
 *
 * @param  object
 *
 * @return object
 */
- (id)initWithWidth:(float)width height:(float)height
{
    if ((self = [super initWithWidth:width height:height]))
    {   
		// Background
        background = [[SPImage alloc] initWithContentsOfFile:@"background.png"];
        [self addChild:background];
        
		// Control
        circle = [[SPImage alloc] initWithContentsOfFile:@"control.png"];
        circle.x = (self.width / 2) - 50.0;
        circle.y = (self.height / 2) - 50.0;
        [self addChild:circle];
        
		// Particle system
        particleSystem = [[SXParticleSystem alloc] initWithContentsOfFile:@"plasma.xml"];
        particleSystem.x = 0.0f;
        particleSystem.y = 0.0f;
        [self addChild:particleSystem];
        [self.juggler addObject:particleSystem];
        
		// Touch event listener
        [self addEventListener:@selector(onTouch:) atObject:self forType:SP_EVENT_TYPE_TOUCH];
        tracking = false;
        
		// ###
		
		// UDP socket
        socket = [[AsyncUdpSocket alloc] initWithDelegate:self];
        
        NSError *bindError = nil;
        if ([socket bindToPort:8088 error:&bindError] == NO) {
            NSLog(@"%@", [bindError localizedDescription]);
        }
        
        NSError *connectError = nil;
        if ([socket connectToHost:@"192.168.1.88" onPort:8088 error:&connectError] == NO)
        {
            NSLog(@"%@", [connectError localizedDescription]);
        }
        
        [socket enableBroadcast:YES error:nil];
    }
    return self;
}

/**
 * Deallocate
 *
 * @param  void
 *
 * @return  void
 */
- (void)dealloc
{
    [background release];
    [circle release];
    [particleSystem release];
    [socket release];
    [super dealloc];
}

/**
 * onTouch event
 *
 * @param  SPTouchEvent
 *
 * @return  void
 */
- (void)onTouch:(SPTouchEvent *)event
{
	// Check for target "hit"
    SPTouch *circleTouch = [[event touchesWithTarget:circle andPhase:SPTouchPhaseBegan] anyObject];
    if (circleTouch) {
        tracking = true;
    }
    
	// Track touch position
    SPTouch *touch = [[event touchesWithTarget:self] anyObject];
    if (touch && tracking)
    {
        SPPoint *touchPosition = [touch locationInSpace:self];
        int verticalMove = (int) lroundf((touchPosition.y - (self.height / 2)) / (self.height / 2) * -100);
        int horizontalMove = (int) lroundf((touchPosition.x - (self.width / 2)) / (self.width / 2) * 100);
        
        if (verticalMove > 100) {
            verticalMove = 100;
        } else if (verticalMove < -100) {
            verticalMove = -100;
        }
        
        if (horizontalMove > 100) {
            horizontalMove = 100;
        } else if (horizontalMove < -100) {
            horizontalMove = -100;
        }
        
		// UDP command string setup
        NSString *verticalString = [NSString stringWithFormat:@"%02.2X", verticalMove];
        verticalString = [verticalString substringFromIndex:([verticalString length] - 2)];
        
        NSString *horizontalString = [NSString stringWithFormat:@"%02.2X", horizontalMove];
        horizontalString = [horizontalString substringFromIndex:([horizontalString length] - 2)];
        
        // V1 Command Set:
		//NSString *sendString = [NSString stringWithFormat:@"0x42 0x47 0x01 0x40 0x%@ 0x%@", verticalString, horizontalString];
        // V2 Command Set:
		NSString *sendString = [NSString stringWithFormat:@"BG 0x02 0x88 0x01 0x%@ 0x01 0x%@ 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00", verticalString, horizontalString];
		
        NSData *sendData = [sendString dataUsingEncoding:NSASCIIStringEncoding];
        
        NSLog(@"%@, %@", sendString, sendData);
        
        if([socket sendData:sendData withTimeout:10.0 tag:0] == NO)
        {
            NSLog(@"Error sending data.");
        }
        
        //NSLog(@"vertical: %f  horizontal: %f\n", verticalMove, horizontalMove);
        
		// Phase: Began
        if (touch.phase == SPTouchPhaseBegan)
        {
            SPTween *circleDisappear = [SPTween tweenWithTarget:circle time:0.2 transition:SP_TRANSITION_EASE_IN];
            [circleDisappear animateProperty:@"scaleX" targetValue:0.0];
            [circleDisappear animateProperty:@"scaleY" targetValue:0.0];
            [circleDisappear animateProperty:@"x" targetValue:touchPosition.x];
            [circleDisappear animateProperty:@"y" targetValue:touchPosition.y];
            [self.juggler removeTweensWithTarget:circle];
            [self.juggler addObject:circleDisappear];
            
            particleSystem.emitterX = touchPosition.x;
            particleSystem.emitterY = touchPosition.y;
            [particleSystem performSelector:@selector(start) withObject:nil afterDelay:0.2];
        }
		// Phase: Moved
        else if (touch.phase == SPTouchPhaseMoved)
        {
			// Move sprite & particle emitter
            particleSystem.emitterX = touchPosition.x;
            particleSystem.emitterY = touchPosition.y;
            circle.x = touchPosition.x - (circle.width / 2);
            circle.y = touchPosition.y - (circle.height / 2);
        }
		// Phase: Ended
        else if ((touch.phase == SPTouchPhaseEnded) || (touch.phase == SPTouchPhaseCancelled))
        {
            tracking = false;
            [NSObject cancelPreviousPerformRequestsWithTarget:particleSystem];
            [particleSystem stop];
            
            // Re-center circle on screen
            SPTween *circleReturn = [SPTween tweenWithTarget:circle time:0.3 transition:SP_TRANSITION_EASE_OUT];
            [circleReturn animateProperty:@"scaleX" targetValue:1.0];
            [circleReturn animateProperty:@"scaleY" targetValue:1.0];
            [circleReturn animateProperty:@"x" targetValue:(self.width / 2) - 50.0];
            [circleReturn animateProperty:@"y" targetValue:(self.height / 2) - 50.0];
            [self.juggler removeTweensWithTarget:circle];
            [self.juggler addObject:circleReturn];
        }
    }
}

@end
