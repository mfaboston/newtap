//
//  MFAVideoPlayerUIView.h
//  MFA Guide
//
//  Created by Matthew Krom on 6/21/13.
//
//

#import <UIKit/UIKit.h>


@class AVPlayer;

@interface MFAVideoPlayerUIView : UIView

@property (nonatomic, retain) AVPlayer *player;

- (void)setPlayer:(AVPlayer*)player;
- (void)setVideoFillMode:(NSString *)fillMode;
- (CGRect)getVideoContentFrame;

@end
