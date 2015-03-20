//
//  MFAVideoPlayerControllerViewController.m
//  MFA Guide
//
//  Created by Matthew Krom on 6/21/13.
//
//

#import "MFAVideoPlayerControllerViewController.h"
#import "MFAVideoPlayerUIView.h"
#import "TapAppDelegate.h"



NSString * const kTracksKey         = @"tracks";
NSString * const kPlayableKey		= @"playable";
/* PlayerItem keys */
NSString * const kStatusKey         = @"status";

/* AVPlayer keys */
NSString * const kRateKey			= @"rate";
NSString * const kCurrentItemKey	= @"currentItem";



@interface MFAVideoPlayerControllerViewController ()
- (void)removePlayerTimeObserver;
- (void)playerItemDidReachEnd:(NSNotification *)notification ;
- (void)observeValueForKeyPath:(NSString*) path ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys;
- (void)initScrubberTimer;
- (IBAction)beginScrubbing:(id)sender;
- (IBAction)endScrubbing:(id)sender;
- (IBAction)scrub:(id)sender;
@end


@interface MFAVideoPlayerControllerViewController (Player)
- (void)removePlayerTimeObserver;
- (CMTime)playerItemDuration;
- (BOOL)isPlaying;
- (void)playerItemDidReachEnd:(NSNotification *)notification ;
- (void)observeValueForKeyPath:(NSString*) path ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys;
@end


@implementation MFAVideoPlayerControllerViewController

@synthesize fileUrl, mPlayer, mPlayerItem, mPlaybackView, mToolbar, mSecondaryToolbar, mPlayButton, mStopButton, mCCButton, mScrubber, mDoneButton, mRestart, tapper;
@synthesize toolbarsHidden;
@synthesize offerCCNumber;

@synthesize assetForMediaTypes, mfaSubtitleOptionsGroup, mfaSubtitleOption, playerItemForSubtitles, mfaSubtitleDefaultOption;

BOOL subtitlesInsteadOfCC = YES;

static void *AVPlayerDemoPlaybackViewControllerRateObservationContext = &AVPlayerDemoPlaybackViewControllerRateObservationContext;
static void *AVPlayerDemoPlaybackViewControllerStatusObservationContext = &AVPlayerDemoPlaybackViewControllerStatusObservationContext;
static void *AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext = &AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext;

UITapGestureRecognizer *tap;


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
		toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		return YES;
	}
	return NO;
}


- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationLandscapeLeft;
}


- (BOOL)offerCC {
    if (subtitlesInsteadOfCC) {
        return [self subtitlesDetected];
    } else {
        return [offerCCNumber boolValue];
    }
}
- (void)setOfferCC:(BOOL)x {
    self.offerCCNumber = [NSNumber numberWithBool:x];
    NSLog(@"Setting offerCCNumber to %@", self.offerCCNumber);
}



#pragma mark Prepare to play asset, URL

/*
 Invoked at the completion of the loading of the values for all keys on the asset that we require.
 Checks whether loading was successfull and whether the asset is playable.
 If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
 */
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    /* Make sure that the value of each key has loaded successfully. */
	for (NSString *thisKey in requestedKeys)
	{
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
		if (keyStatus == AVKeyValueStatusFailed)
		{
			[self assetFailedToPrepareForPlayback:error];
			return;
		}
	}
    
    /* Use the AVAsset playable property to detect whether the asset can be played. */
    if (FALSE && (!asset.playable))
    {
        /* Generate an error describing the failure. */
		NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
		NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
		NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
								   localizedDescription, NSLocalizedDescriptionKey,
								   localizedFailureReason, NSLocalizedFailureReasonErrorKey,
								   nil];
		NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];

        /* Display the error to the user. */
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
        return;
    }
	
	/* At this point we're ready to set up for playback of the asset. */
    
    /* Stop observing our prior AVPlayerItem, if we have one. */
    if (self.mPlayerItem)
    {
        /* Remove existing player item key value observers and notifications. */
        [self.mPlayerItem removeObserver:self forKeyPath:kStatusKey];
		
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.mPlayerItem];
    }
	
    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    self.mPlayerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    /* Observe the player item "status" key to determine when it is ready to play. */
    [self.mPlayerItem addObserver:self
                       forKeyPath:kStatusKey
                          options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                          context:AVPlayerDemoPlaybackViewControllerStatusObservationContext];
	
    /* When the player item has played to its end time we'll toggle
     the movie controller Pause button to be the Play button */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.mPlayerItem];
	
    seekToZeroBeforePlay = NO;
	
    /* Create new player, if we don't already have one. */
    if (!self.mPlayer)
    {
        /* Get a new AVPlayer initialized to play the specified player item. */
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.mPlayerItem]];
		
        /* Observe the AVPlayer "currentItem" property to find out when any
         AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did
         occur.*/
        [self.player addObserver:self
                      forKeyPath:kCurrentItemKey
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext];
        
        /* Observe the AVPlayer "rate" property to update the scrubber control. */
        [self.player addObserver:self
                      forKeyPath:kRateKey
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerRateObservationContext];
    }
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (self.player.currentItem != self.mPlayerItem)
    {
        /* Replace the player item with a new player item. The item replacement occurs
         asynchronously; observe the currentItem property to find out when the
         replacement will/did occur*/
        [self.mPlayer replaceCurrentItemWithPlayerItem:self.mPlayerItem];
        
        [self syncPlayPauseButtons];
    }
	
    [self.mScrubber setValue:0.0];
}


- (IBAction)loadAssetFromFile:sender {
    NSLog(@"fileUrl is %@", fileUrl);
    BOOL subtitleHardCodedSampleVideo = NO;
    
    AVURLAsset *asset;

    if (subtitleHardCodedSampleVideo) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"subtitles" ofType:@"m4v"];
        NSURL *trialUrl = [NSURL fileURLWithPath:path];
        asset = [AVURLAsset URLAssetWithURL:trialUrl options:nil];
    } else {
        asset = [AVURLAsset URLAssetWithURL:fileUrl options:nil];
    }
    
    self.assetForMediaTypes = asset;
    NSArray *requestedKeys = @[kTracksKey, kPlayableKey];
    NSLog(@"!!!!!!! Asset URL is %@", fileUrl);
    [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
     ^{
        dispatch_async(dispatch_get_main_queue(),
        ^{
            /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
            [self prepareToPlayAsset:asset withKeys:requestedKeys];
        });
    }];
}


/* ---------------------------------------------------------
 **  Called when the value at the specified key path relative
 **  to the given object has changed.
 **  Adjust the movie play and pause button controls when the
 **  player item "status" value changes. Update the movie
 **  scrubber control when the player item is ready to play.
 **  Adjust the movie scrubber control when the player item
 **  "rate" value changes. For updates of the player
 **  "currentItem" property, set the AVPlayer for which the
 **  player layer displays visual output.
 **  NOTE: this method is invoked on the main queue.
 ** ------------------------------------------------------- */

- (void)observeValueForKeyPath:(NSString*) path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
	/* AVPlayerItem "status" property value observer. */
	if (context == AVPlayerDemoPlaybackViewControllerStatusObservationContext)
	{
        
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
                /* Indicates that the status of the player is not yet known because
                 it has not tried to load new media resources for playback */
            case AVPlayerStatusUnknown:
            {
                [self removePlayerTimeObserver];
                [self syncScrubber];
                
                [self disableScrubber];
                [self disablePlayerButtons];
            }
                break;
                
            case AVPlayerStatusReadyToPlay:
            {
                /* Once the AVPlayerItem becomes ready to play, i.e.
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
                 its duration can be fetched from the item. */
                
                [self initScrubberTimer];
                
                [self enableScrubber];
                [self enablePlayerButtons];

                //FF commented out transformedBounds to silence analyer error
//                CGRect transformedBounds  = [self.mPlaybackView getVideoContentFrame];
//                NSLog(@"Setting mPlaybackView.frame to %f %f %f %f", transformedBounds.origin.x,
//                      transformedBounds.origin.y,
//                      transformedBounds.size.width, transformedBounds.size.height                     );
                
                CGRect fullScreenBounds = CGRectMake(0.0f, 0.0f, 480.f, 320.f);
//                self.mPlaybackView.frame = transformedBounds;
                self.mPlaybackView.frame = fullScreenBounds;
                
                
                
                AVPlayerItem *playerItem = (AVPlayerItem *)object;
                NSArray * mediaOptions = self.assetForMediaTypes.availableMediaCharacteristicsWithMediaSelectionOptions;
                NSLog(@"Mediaoptions are %@", mediaOptions);
                BOOL hasSubtitles = NO;
                for (NSString * str in mediaOptions) {
                    if ([str isEqualToString:AVMediaCharacteristicLegible]) {
                        hasSubtitles = YES;
                    }
                }
                
                NSLog(@"Has Subtitles: %@", [NSNumber numberWithBool:hasSubtitles]);
                self.mfaSubtitleOptionsGroup = [self.assetForMediaTypes mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];
                for (AVMediaSelectionOption * o in self.mfaSubtitleOptionsGroup.options) {
                    if ([o hasMediaCharacteristic:AVMediaCharacteristicContainsOnlyForcedSubtitles]) {
                        // This is the "forced" subtitles: the default that should be used
                        // when no subtitles are chosen. (Contains only essential text)
                        self.mfaSubtitleDefaultOption = o;
                    } else if ([o hasMediaCharacteristic:AVMediaCharacteristicLegible]) {
                        // No language/locale checking; will take one at random if multiple present
                        self.mfaSubtitleOption = o;
                    }

                }
//                self.mfaSubtitleOption = self.mfaSubtitleOptionsGroup.options[0];
//                self.mfaSubtitleDefaultOption = self.mfaSubtitleOptionsGroup.options[1];
                self.playerItemForSubtitles = playerItem;
                NSLog(@"subtitleOptions is %@", self.mfaSubtitleOptionsGroup);
                NSLog(@"mfaSubtitleOptionsGroup.options is %@", self.mfaSubtitleOptionsGroup.options);
                
//                [playerItem selectMediaOption:(AVMediaSelectionOption *) inMediaSelectionGroup:<#(AVMediaSelectionGroup *)#>
                
                [self initializeCCButtonAsApplicable];
                [self initializeCCBasedOnAppDelegatePrefs];

              	[mPlayer play];
            }
                break;
                
            case AVPlayerStatusFailed:
            {
                AVPlayerItem *playerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:playerItem.error];
            }
                break;
        }
	}
	/* AVPlayer "rate" property value observer. */
	else if (context == AVPlayerDemoPlaybackViewControllerRateObservationContext)
	{
        [self syncPlayPauseButtons];
	}
	/* AVPlayer "currentItem" property observer.
     Called when the AVPlayer replaceCurrentItemWithPlayerItem:
     replacement will/did occur. */
	else if (context == AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext)
	{
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        /* Is the new player item null? */
        if (newPlayerItem == (id)[NSNull null])
        {
            [self disablePlayerButtons];
            [self disableScrubber];
        }
        else /* Replacement of player currentItem has occurred */
        {
            /* Set the AVPlayer for which the player layer displays visual output. */
            [self.mPlaybackView setPlayer:mPlayer];
            
            /* Specifies that the player should preserve the video’s aspect ratio and
             fit the video within the layer’s bounds. */
            [self.mPlaybackView setVideoFillMode:AVLayerVideoGravityResizeAspect];
            
            [self syncPlayPauseButtons];
        }
	}
	else
	{
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
}


- (void)playerItemDidReachEnd:(NSNotification *)notification {
    [self.player seekToTime:kCMTimeZero];
    [self goAwayPlayer];
}


#pragma mark -
#pragma mark Play, Stop buttons

/* Show the stop button in the movie player controller. */

#define kCCButtonIndex 4
-(void)initializeCCButtonAsApplicable {
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mSecondaryToolbar items]];
    if ([toolbarItems count] >= (kCCButtonIndex + 1)) {
        if ([self subtitlesDetected]) {
            [toolbarItems replaceObjectAtIndex:kCCButtonIndex withObject:self.mCCButton];
        } else {
            //FF added autorelease
            [toolbarItems replaceObjectAtIndex:kCCButtonIndex withObject:[[self newFlexItem] autorelease]];

        }
        self.mSecondaryToolbar.items = toolbarItems;
    }
    
}
-(void)showStopButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mSecondaryToolbar items]];
    if ([toolbarItems count] > 3) {
        [toolbarItems replaceObjectAtIndex:2 withObject:self.mStopButton];
        self.mSecondaryToolbar.items = toolbarItems;
    }
}

/* Show the play button in the movie player controller. */
-(void)showPlayButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mSecondaryToolbar items]];
    if ([toolbarItems count] > 3) {
        [toolbarItems replaceObjectAtIndex:2 withObject:self.mPlayButton];
        self.mSecondaryToolbar.items = toolbarItems;
    }
}

/* If the media is playing, show the stop button; otherwise, show the play button. */
- (void)syncPlayPauseButtons
{
	if ([self isPlaying])
	{
        [self showStopButton];
	}
	else
	{
        [self showPlayButton];
	}
}

-(void)enablePlayerButtons
{
    self.mPlayButton.enabled = YES;
    self.mStopButton.enabled = YES;
}

-(void)disablePlayerButtons
{
    self.mPlayButton.enabled = NO;
    self.mStopButton.enabled = NO;
}



#pragma mark -
#pragma mark Movie scrubber control

/* ---------------------------------------------------------
 **  Methods to handle manipulation of the movie scrubber control
 ** ------------------------------------------------------- */

/* Requests invocation of a given block during media playback to update the movie scrubber control. */
-(void)initScrubberTimer
{
	double interval = .1f;
	
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration))
	{
		return;
	}
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		CGFloat width = CGRectGetWidth([self.mScrubber bounds]);
		interval = 0.5f * duration / width;
	}
    
	/* Update the scrubber during normal playback. */
	mTimeObserver = [[self.mPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC)
                                                                queue:NULL /* If you pass NULL, the main queue is used. */
                                                           usingBlock:^(CMTime time)
                      {
                          [self syncScrubber];
                      }] retain];
    
}

/* Set the scrubber based on the player current time. */
- (void)syncScrubber
{
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration))
	{
		mScrubber.minimumValue = 0.0;
		return;
	}
    
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		float minValue = [self.mScrubber minimumValue];
		float maxValue = [self.mScrubber maximumValue];
		double time = CMTimeGetSeconds([self.player currentTime]);
		
		[self.mScrubber setValue:(maxValue - minValue) * time / duration + minValue];
	}
}

/* The user is dragging the movie controller thumb to scrub through the movie. */
- (IBAction)beginScrubbing:(id)sender
{
	mRestoreAfterScrubbingRate = [self.player rate];
	[self.player setRate:0.f];
	
	/* Remove previous timer. */
	[self removePlayerTimeObserver];
}

/* Set the player current time to match the scrubber position. */
- (IBAction)scrub:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider* slider = sender;
		
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) {
			return;
		}
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			float minValue = [slider minimumValue];
			float maxValue = [slider maximumValue];
			float value = [slider value];
			
			double time = duration * (value - minValue) / (maxValue - minValue);
			
			[self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
		}
	}
}

/* The user has released the movie thumb control to stop scrubbing through the movie. */
- (IBAction)endScrubbing:(id)sender
{
	if (!mTimeObserver)
	{
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration))
		{
			return;
		}
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			CGFloat width = CGRectGetWidth([self.mScrubber bounds]);
			double tolerance = 0.5f * duration / width;
            
			mTimeObserver = [[self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC) queue:NULL usingBlock:
                              ^(CMTime time)
                              {
                                  [self syncScrubber];
                              }] retain];
		}
	}
    
	if (mRestoreAfterScrubbingRate)
	{
		[self.player setRate:mRestoreAfterScrubbingRate];
		mRestoreAfterScrubbingRate = 0.f;
	}
}



- (BOOL)isScrubbing
{
    return mRestoreAfterScrubbingRate != 0.f;
}

-(void)enableScrubber
{
    self.mScrubber.enabled = YES;
}

-(void)disableScrubber
{
    self.mScrubber.enabled = NO;    
}



#pragma mark -
#pragma mark Movie sContorls





- (IBAction)pause:(id)sender
{
    [self.player pause];
    [self showPlayButton];
}


- (IBAction)play:sender {
   	/* If we are at the end of the movie, we must seek to the beginning first
     before starting playback. */
	if (YES == seekToZeroBeforePlay)
	{
		seekToZeroBeforePlay = NO;
		[self.mPlayer seekToTime:kCMTimeZero];
	}
    
	[self.mPlayer play];
	
    [self showStopButton];
}

- (IBAction)restartVideo:sender{
    NSLog(@"Restart Video");
    
    CMTime newTime = CMTimeMakeWithSeconds(0.2, 1);
    [mPlayer seekToTime:newTime];
}

- (TapAppDelegate *) applicationDelegate {
    return (TapAppDelegate*)[[UIApplication sharedApplication] delegate];
}

- (IBAction)toggleCC:(id)sender
{
    if ([self.mfaIsCCEnabled isEqualToNumber:@1]) {
        [self turnOffCC];
    } else {
        [self turnOnCC];
    }
}

- (BOOL) subtitlesDetected {
    return ((self.playerItemForSubtitles) && (self.mfaSubtitleOptionsGroup));

}
- (IBAction)turnOnCC {
    self.mfaIsCCEnabled = @1;
    [self setCCTint:true];
    
    if (subtitlesInsteadOfCC) {
        if ([self subtitlesDetected]) {
            [self.playerItemForSubtitles selectMediaOption:self.mfaSubtitleOption
                                     inMediaSelectionGroup:self.mfaSubtitleOptionsGroup];
        }

    } else {
        self.mPlayer.closedCaptionDisplayEnabled = true;
    }
    [[self applicationDelegate] setCCInDefaults:true];
    
}
- (IBAction)turnOffCC {
    self.mfaIsCCEnabled = @0;
    [self setCCTint:false];

    if (subtitlesInsteadOfCC) {
        if ([self subtitlesDetected]) {
//            if (self.mfaSubtitleOptionsGroup.allowsEmptySelection) {
              [self.playerItemForSubtitles selectMediaOption:self.mfaSubtitleDefaultOption inMediaSelectionGroup:self.mfaSubtitleOptionsGroup];
//            } else {
//                NSLog(@"Group does not allow empty selection");
//            }
        }
        
    } else {
        self.mPlayer.closedCaptionDisplayEnabled = false;
    }
    [[self applicationDelegate] setCCInDefaults:false];
}

-(void) setCCTint:(BOOL)engaged {
    if (engaged) {
        NSLog(@"Setting tint to BLUE");
        self.mCCButton.tintColor = [UIColor blueColor];
    } else {
        NSLog(@"Setting tint to CLEAR");
        self.mCCButton.tintColor = [UIColor clearColor];
    }

}

- (IBAction)doneTap:(id)sender{
    [self goAwayPlayer];
}


- (void) turnOnToolBars {
//    if ([self.mToolbar isHidden]) {
    [self setToolbarsHidden:[NSNumber numberWithBool:NO]];
    NSLog(@"turn ON ToolBars");
        [UIView animateWithDuration:0.35f animations:
     ^{
         [self.mToolbar setTransform:CGAffineTransformIdentity];
         [self.mSecondaryBox setTransform:CGAffineTransformIdentity];
         [self.mToolbar setHidden:NO];
         [self.mSecondaryBox setHidden:NO];
         [self performSelector:@selector(turnOffToolBars) withObject:nil afterDelay:5.0];
     } completion:nil];
//    }

}
- (void) turnOffToolBars {
    NSLog(@"turn OFF ToolBars");
    [self setToolbarsHidden:[NSNumber numberWithBool:YES]];
    if (![self.mToolbar isHidden]){
        [UIView animateWithDuration:0.35f animations:
         ^{
             [self.mToolbar setTransform:CGAffineTransformMakeTranslation(0.f, -40.0f)];
             [self.mSecondaryBox setTransform:CGAffineTransformMakeTranslation(0.f, CGRectGetHeight([self.mSecondaryBox bounds])+28.0)];
             [NSObject cancelPreviousPerformRequestsWithTarget:self];
//             [self.mToolbar setHidden:YES];
         }completion:nil];
    }
}

-(void) toggleToolbars{
    NSLog(@"Toggle ToolBars");
    if ([self.toolbarsHidden boolValue]) {
        [self turnOnToolBars];
    } else {
        [self turnOffToolBars];
    }
    
}


-(IBAction)handleTapper:(UIPanGestureRecognizer *)recognizer {
    [self toggleToolbars];
}


- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)tap
{
    if (CGRectContainsPoint(self.mSecondaryBox.bounds, [tap locationInView:self.mSecondaryBox])
        || CGRectContainsPoint(self.mToolbar.bounds, [tap locationInView:self.mToolbar])){
        return NO;
    }
    return YES;
}


- (void)goAwayPlayer {
    [mPlayer pause];
    [mPlayer replaceCurrentItemWithPlayerItem:NULL]; // otherwise the next showing of a video shows previous asset
    [self turnOffToolBars];
    
    [[self presentingViewController] dismissViewControllerAnimated:YES completion:NULL];
}



#pragma mark Player Item

- (BOOL)isPlaying
{
	return mRestoreAfterScrubbingRate != 0.f || [self.player rate] != 0.f;
}

/* ---------------------------------------------------------
 **  Get the duration for a AVPlayerItem.
 ** ------------------------------------------------------- */

- (CMTime)playerItemDuration
{
	AVPlayerItem *playerItem = [self.player currentItem];
	if (playerItem.status == AVPlayerItemStatusReadyToPlay)
	{
        /*
         NOTE:
         Because of the dynamic nature of HTTP Live Streaming Media, the best practice
         for obtaining the duration of an AVPlayerItem object has changed in iOS 4.3.
         Prior to iOS 4.3, you would obtain the duration of a player item by fetching
         the value of the duration property of its associated AVAsset object. However,
         note that for HTTP Live Streaming Media the duration of a player item during
         any particular playback session may differ from the duration of its asset. For
         this reason a new key-value observable duration property has been defined on
         AVPlayerItem.
         
         See the AV Foundation Release Notes for iOS 4.3 for more information.
         */
        
		return([playerItem duration]);
	}
	
	return(kCMTimeInvalid);
}


/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver
{
	if (mTimeObserver)
	{
		[self.player removeTimeObserver:mTimeObserver];
		[mTimeObserver release];
		mTimeObserver = nil;
	}
}






#pragma mark -
#pragma mark Error Handling - Preparing Assets for Playback Failed

/* --------------------------------------------------------------
 **  Called when an asset fails to prepare for playback for any of
 **  the following reasons:
 **
 **  1) values of asset keys did not load successfully,
 **  2) the asset keys did load successfully, but the asset is not
 **     playable
 **  3) the item did not become ready to play.
 ** ----------------------------------------------------------- */

-(void)assetFailedToPrepareForPlayback:(NSError *)error
{
    [self removePlayerTimeObserver];
    [self syncScrubber];
    [self disableScrubber];
    [self disablePlayerButtons];
    
    /* Display the error. */
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
														message:[error localizedFailureReason]
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
	[alertView show];
	[alertView release];
}




- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		[self setPlayer:nil];
		
		[self setWantsFullScreenLayout:YES];
	}
	
	return self;
}

- (id)init
{
  
    return [self initWithNibName:@"MFAVideoPlayer" bundle:nil];
}

//FF refectored from getFlexItem to newFlexItem
-(UIBarButtonItem *) newFlexItem {
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
}

- (void)viewDidLoad
{
    NSLog(@"Load MFAPLayer View");
    [self setPlayer:nil];
    [self setToolbarsHidden:[NSNumber numberWithBool:NO]];
    UIBarButtonItem *scrubberItem = [[UIBarButtonItem alloc] initWithCustomView:self.mScrubber];
    MPVolumeView *_volumeView = [ [MPVolumeView alloc] initWithFrame: self.mVolumeBox.bounds];
    [_volumeView setShowsVolumeSlider:YES];
    [_volumeView setShowsRouteButton:NO];
    [_volumeView sizeToFit];
    [self.mVolumeBox addSubview:_volumeView];
    
    //FF Added
    [_volumeView release];

    UIBarButtonItem * flexItem = [self newFlexItem];

    
    self.mToolbar.items = [NSArray arrayWithObjects:self.mDoneButton, flexItem, scrubberItem, flexItem,  nil];
    
    //FF
    [flexItem release];
    [scrubberItem release];
    
    [self.mSecondaryBox.layer setCornerRadius:10.0f];
    // border
    [self.mSecondaryBox.layer setBorderColor:[UIColor lightGrayColor].CGColor];
    [self.mSecondaryBox.layer setBorderWidth:1.5f];
    
    [self.mSecondaryBox.layer setBorderWidth:1.5f];

    self.mSecondaryBox.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.60f];
    
    [self.mSecondaryBox clipsToBounds];
    
    //FF Commented out
//    [self.mSecondaryToolbar setBackgroundImage:[UIImage new]
                 // forToolbarPosition:UIToolbarPositionAny
                         // barMetrics:UIBarMetricsDefault];
    
    [self.mSecondaryToolbar setBackgroundColor:[UIColor clearColor]];
    [self.mSecondaryToolbar setBackgroundImage:[UIImage alloc] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    
   
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];

    [super viewDidLoad];
}

-(void)initializePlayerButtons {
    //FF Added autorelease
    UIBarButtonItem * flexItem = [[self newFlexItem] autorelease];
    if ([self offerCC]) {
        self.mSecondaryToolbar.items = [NSArray arrayWithObjects: self.mRestart, flexItem, self.mPlayButton, flexItem, self.mCCButton, nil];
    } else{
        self.mSecondaryToolbar.items = [NSArray arrayWithObjects: self.mRestart, flexItem, self.mPlayButton, flexItem, flexItem, nil];
    }
	[self initScrubberTimer];
	[self syncPlayPauseButtons];
	[self syncScrubber];
    [self turnOnToolBars];

}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    
    
    
//    [self performSelector:@selector(turnOnToolBars) withObject:nil afterDelay:5.0];
    
    [self initializePlayerButtons];
    
}

-(void)initializeCCBasedOnAppDelegatePrefs {
    BOOL shouldEnableCC = [[self applicationDelegate] ccFromDefaults];
    NSLog(@" should enable CC with blueness: %@", (shouldEnableCC ? @"YES" : @"NO"));
    
    if (shouldEnableCC) {
        [self turnOnCC];
    } else {
        [self turnOffCC];
    }

}


-(void)viewWillDisappear:(BOOL)animated  {
    NSLog(@"MfaVideo... viewWillDisappear");
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
    [self.mPlayerItem removeObserver:self forKeyPath:kStatusKey];
    [self.player removeObserver:self forKeyPath:kCurrentItemKey];
    [self.player removeObserver:self forKeyPath:kRateKey];

    NSLog(@"R1");
    [playerView release];
    NSLog(@"R2");
//    [self.mPlayer release];
    NSLog(@"R3");
//    [self.mPlayerItem release];
    NSLog(@"R4");
//    [self.player release];
    NSLog(@"R5");
    self.mPlayer = nil;
    self.mPlayerItem = nil;
    self.player = nil;
    
    //FF added
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (void)dealloc {
    [_mSecondary release];
    [_mVolumeBox release];
    [_mSecondaryBox release];
    [tapper release];
    [super dealloc];
}

- (void)viewDidUnload {
    NSLog(@"viewDidUnload");
    [playerView release];
    playerView = nil;;
    mPlayer=nil;
    [self setMCCButton:nil];
    [self setMDoneButton:nil];
    [self setMRestart:nil];
    [self setMSecondary:nil];
    [self setMVolumeBox:nil];
    [self setMSecondaryBox:nil];
    [self setTapper:nil];
    [super viewDidUnload];
}
@end
