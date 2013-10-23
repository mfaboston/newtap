//
//  MFAVideoPlayerControllerViewController.h
//  MFA Guide
//
//  Created by Matthew Krom on 6/21/13.
//
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "MFAVideoPlayerUIView.h"


@class AVPlayer;
@class MFAVideoPlayerUIView;

@interface MFAVideoPlayerControllerViewController : UIViewController
{
    id mTimeObserver;
    float mRestoreAfterScrubbingRate;

    IBOutlet MFAVideoPlayerUIView *playerView;
    BOOL seekToZeroBeforePlay;
}


@property (nonatomic, retain) NSURL * fileUrl;

@property (nonatomic, retain) AVPlayerItem * mPlayerItem;
@property (readwrite, retain, setter=setPlayer:, getter=player) AVPlayer* mPlayer;
@property (retain, nonatomic) IBOutlet MFAVideoPlayerUIView *mPlaybackView;

@property (nonatomic, retain) IBOutlet UIToolbar *mToolbar;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *mPlayButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *mStopButton;
@property (nonatomic, retain) IBOutlet UISlider* mScrubber;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *mCCButton;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *mDoneButton;

- (IBAction)toggleCC:(id)sender;
- (IBAction)goAwayPlayer:(id)sender;


- (IBAction)loadAssetFromFile:sender;
- (IBAction)play:(id)sender;
- (IBAction)pause:(id)sender;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context;

@end