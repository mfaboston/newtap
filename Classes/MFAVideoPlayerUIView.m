//
//  MFAVideoPlayerUIView.m
//  MFA Guide
//
//  Created by Matthew Krom on 6/21/13.
//
//

#import "MFAVideoPlayerUIView.h"
#import <AVFoundation/AVFoundation.h>

@implementation MFAVideoPlayerUIView


+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayer*)player {
    return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVPlayer *)player {
    [(AVPlayerLayer *)[self layer] setPlayer:player];
}

/* Specifies how the video is displayed within a player layer’s bounds.
 (AVLayerVideoGravityResizeAspect is default) */
- (void)setVideoFillMode:(NSString *)fillMode
{
	AVPlayerLayer *playerLayer = (AVPlayerLayer*)[self layer];
	playerLayer.videoGravity =  AVLayerVideoGravityResizeAspect;
}

- (CGRect)getVideoContentFrame {
    AVPlayerLayer *avLayer = (AVPlayerLayer *)[self layer];
    // AVPlayerLayerContentLayer
    CALayer *layer = (CALayer *)[[avLayer sublayers] objectAtIndex:0];
    CGRect transformedBounds = CGRectApplyAffineTransform(layer.bounds, CATransform3DGetAffineTransform(layer.sublayerTransform));
    return transformedBounds;
}

@end
