//
//  Game.m
//  AppScaffold
//

#import "Game.h" 

@implementation Game

- (id)initWithWidth:(float)width height:(float)height
{
    if ((self = [super initWithWidth:width height:height]))
    {
        // this is where the code of your game will start. 
        // in this sample, we add just a simple quad to see if it works.
        /*
        SPTexture *circleTexture = [[SPTexture alloc] initWithWidth:100.0 height:100.0
            draw:^(CGContextRef context)
            {
                CGMutablePathRef circlePath = CGPathCreateMutable();
                
                CGPathAddEllipseInRect(circlePath, NULL, CGRectMake(0.0, 0.0, 100.0, 100.0));
                CGContextAddPath(context, circlePath);
                
                CGContextClip(context);
                
                CGContextAddPath(context, circlePath);
                
                CGContextSetFillColorWithColor(context, [[UIColor blueColor] CGColor]);
                CGContextFillPath(context);

                CGContextAddPath(context, circlePath);
                
                CGContextSetStrokeColorWithColor(context, [[UIColor whiteColor] CGColor]);
                CGContextSetLineWidth(context, 8.0);
                CGContextStrokePath(context);
                
                CGPathRelease(circlePath);
            }];
         */
        
        background = [[SPImage alloc] initWithContentsOfFile:@"background.png"];
        [self addChild:background];
        
        circle = [[SPImage alloc] initWithContentsOfFile:@"control.png"];
        //[circleTexture release];
        
        circle.x = (self.width / 2) - 50.0;
        circle.y = (self.height / 2) - 50.0;
        
        [self addChild:circle];
        
        particleSystem = [[SXParticleSystem alloc] initWithContentsOfFile:@"plasma.xml"];
        particleSystem.x = 0.0f;
        particleSystem.y = 0.0f;
        [self addChild:particleSystem];
        [self.juggler addObject:particleSystem];
        
        [self addEventListener:@selector(onTouch:) atObject:self forType:SP_EVENT_TYPE_TOUCH];
        tracking = false;
        
        //
        // Setup UDP socket
        //
        
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
        
                
        // Per default, this project compiles as an iPhone application. To change that, enter the 
        // project info screen, and in the "Build"-tab, find the setting "Targeted device family".
        //
        // Now Choose:  
        //   * iPhone      -> iPhone only App
        //   * iPad        -> iPad only App
        //   * iPhone/iPad -> Universal App  
        // 
        // If you want to support the iPad, you have to change the "iOS deployment target" setting
        // to "iOS 3.2" (or "iOS 4.2", if it is available.)
    }
    return self;
}

- (void)dealloc
{
    [background release];
    [circle release];
    [particleSystem release];
    [socket release];
    [super dealloc];
}



- (void)onTouch:(SPTouchEvent *)event
{
    SPTouch *circleTouch = [[event touchesWithTarget:circle andPhase:SPTouchPhaseBegan] anyObject];
    if (circleTouch) {
        tracking = true;
    }

    
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
        
        NSString *verticalString = [NSString stringWithFormat:@"%02.2X", verticalMove];
        verticalString = [verticalString substringFromIndex:([verticalString length] - 2)];
        
        NSString *horizontalString = [NSString stringWithFormat:@"%02.2X", horizontalMove];
        horizontalString = [horizontalString substringFromIndex:([horizontalString length] - 2)];
        
        NSString *sendString = [NSString stringWithFormat:@"0x42 0x47 0x01 0x40 0x%@ 0x%@", verticalString, horizontalString];
        
        NSData *sendData = [sendString dataUsingEncoding:NSASCIIStringEncoding];
        
        NSLog(@"%@, %@", sendString, sendData);
        
        if([socket sendData:sendData withTimeout:10.0 tag:0] == NO)
        {
            NSLog(@"Error sending data.");
        }
        
        
        //NSLog(@"vertical: %f  horizontal: %f\n", verticalMove, horizontalMove);
        
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
        
        else if (touch.phase == SPTouchPhaseMoved)
        {
            particleSystem.emitterX = touchPosition.x;
            particleSystem.emitterY = touchPosition.y;
            circle.x = touchPosition.x - (circle.width / 2);
            circle.y = touchPosition.y - (circle.height / 2);
        }
        
        else if ((touch.phase == SPTouchPhaseEnded) || (touch.phase == SPTouchPhaseCancelled))
        {
            tracking = false;
            [NSObject cancelPreviousPerformRequestsWithTarget:particleSystem];
            [particleSystem stop];
            
            //center circle on screen
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
