//
//  MFAVideoPlayerControllerViewController.h
//  MFA Guide
//
//  Created by Matthew Krom on 6/21/13.
//
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "MFAVideoPlayerUIView.h"


@class AVPlayer;
@class MFAVideoPlayerUIView;

@interface MFAVideoPlayerControllerViewController : UIViewController <UIGestureRecognizerDelegate>
{
    id mTimeObserver;
    float mRestoreAfterScrubbingRate;

    IBOutlet MFAVideoPlayerUIView *playerView;
    BOOL seekToZeroBeforePlay;
    
    NSNumber * toolbarsHidden;
    NSNumber * offerCCNumber;
}


@property (nonatomic, retain) NSURL * fileUrl;
@property (nonatomic, retain) NSNumber * toolbarsHidden;
@property (nonatomic, retain) NSNumber * offerCCNumber;

@property (nonatomic, retain) AVPlayerItem * mPlayerItem;
@property (readwrite, retain, setter=setPlayer:, getter=player) AVPlayer* mPlayer;
@property (retain, nonatomic) IBOutlet MFAVideoPlayerUIView *mPlaybackView;

@property (nonatomic, retain) IBOutlet UIToolbar *mToolbar;
@property (retain, nonatomic) IBOutlet UIToolbar *mSecondaryToolbar;
@property (retain, nonatomic) IBOutlet UIView *mSecondaryBox;


@property (nonatomic, retain) IBOutlet UIBarButtonItem *mPlayButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *mStopButton;
@property (nonatomic, retain) IBOutlet UISlider* mScrubber;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *mCCButton;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *mDoneButton;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *mRestart;
@property (retain, nonatomic) IBOutlet UIView *mSecondary;
@property (retain, nonatomic) IBOutlet UIView *mVolumeBox;

@property (retain, nonatomic) IBOutlet UITapGestureRecognizer *tapper;

- (IBAction)toggleCC:(id)sender;
- (IBAction)doneTap:(id)sender;
- (IBAction)restartVideo:(id)sender;

- (IBAction)loadAssetFromFile:sender;
- (IBAction)play:(id)sender;
- (IBAction)pause:(id)sender;

- (BOOL)offerCC;
- (void)setOfferCC:(BOOL)x;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context;

- (IBAction)handleTapper:(UITapGestureRecognizer *)recognizer;

@end