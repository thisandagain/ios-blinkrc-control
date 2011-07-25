//
//  Game.h
//  AppScaffold
//

#import <Foundation/Foundation.h>
#import "SXParticleSystem.h"
#import "AsyncUdpSocket.h"

@interface Game : SPStage
{
    SPImage *background;
    SPImage *circle;
    SXParticleSystem *particleSystem;
    
    BOOL tracking;
    
    AsyncUdpSocket *socket;
}

@end
