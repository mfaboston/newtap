//
//  MFAVideoPlayerUIView.m
//  MFA Guide
//
//  Created by Matthew Krom on 6/21/13.
//
//

#import "MFAVideoPlayerUIView.h"

@implementation MFAVideoPlayerUIView

- (id)initWithFrame:(CGRect)frame
{
    NSLog(@"Frame initting is %f %f %f %f", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

+ (Class)layerClass {
    return [AVPlayerLayer class];
}
- (AVPlayer*)player {
    return [(AVPlayerLayer *)[self layer] player];
}
- (void)setPlayer:(AVPlayer *)player {
    [(AVPlayerLayer *)[self layer] setPlayer:player];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
