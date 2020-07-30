//
//  GameViewController.m
//  MSocket
//
//  Created by alan on 2020/7/30.
//  Copyright © 2020 OceanMaster. All rights reserved.
//

#import "GameViewController.h"
#import "GameScene.h"
#import "MSSocketServer.h"

@interface GameViewController ()<MSSocketServerDelegate>

@end

@implementation GameViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [MSSocketServer shareServer:self];
    // Load the SKScene from 'GameScene.sks'
    GameScene *scene = (GameScene *)[SKScene nodeWithFileNamed:@"GameScene"];
    
    // Set the scale mode to scale to fit the window
    scene.scaleMode = SKSceneScaleModeAspectFill;
    
    SKView *skView = (SKView *)self.view;
    
    // Present the scene
    [skView presentScene:scene];
    
    skView.showsFPS = YES;
    skView.showsNodeCount = YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)socketServer:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"from client data: %@",data);
}
@end
