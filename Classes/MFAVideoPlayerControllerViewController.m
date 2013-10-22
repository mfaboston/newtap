//
//  MFAVideoPlayerControllerViewController.m
//  MFA Guide
//
//  Created by Matthew Krom on 6/21/13.
//
//

#import "MFAVideoPlayerControllerViewController.h"
#import "MFAVideoPlayerUIView.h"


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

@synthesize fileUrl, mPlayer, mPlayerItem, mPlaybackView, mToolbar, mPlayButton, mStopButton, mScrubber;




static const NSString *ItemStatusContext;

static void *AVPlayerDemoPlaybackViewControllerRateObservationContext = &AVPlayerDemoPlaybackViewControllerRateObservationContext;
static void *AVPlayerDemoPlaybackViewControllerStatusObservationContext = &AVPlayerDemoPlaybackViewControllerStatusObservationContext;
static void *AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext = &AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext;




- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
		toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		return YES;
	}
	return NO;
}

//- (void)syncUI {
//    if ((self.player.currentItem != nil) &&
//        ([self.player.currentItem status] == AVPlayerItemStatusReadyToPlay)) {
//        self.mPlayButton.enabled = YES;
//    }
//    else {
//        self.mPlayButton.enabled = NO;
//    }
//}

//- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
//{
//    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
//    if (self) {
//        // Custom initialization
//    }
//    return self;
//}




- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    /* Make sure that the value of each key has loaded successfully. */
	for (NSString *thisKey in requestedKeys)
	{
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
		if (keyStatus == AVKeyValueStatusFailed)
		{
			//[self assetFailedToPrepareForPlayback:error];
            NSLog(@"FAILURE ");
            NSLog(@"FAILURE ");
            NSLog(@"FAILURE ");
            NSLog(@"FAILURE ");
            NSLog(@"FAILURE ");
			return;
		}
		/* If you are also implementing -[AVAsset cancelLoading], add your code here to bail out properly in the case of cancellation. */
	}
    
    /* Use the AVAsset playable property to detect whether the asset can be played. */
    if (!asset.playable)
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
	
    BOOL seekToZeroBeforePlay = NO;
	
    /* Create new player, if we don't already have one. */
    if (!self.mPlayer)
    {
        /* Get a new AVPlayer initialized to play the specified player item. */
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.mPlayerItem]];
		
        /* Observe the AVPlayer "currentItem" property to find out when any
         AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did
         occur.*/
//        [self.player addObserver:self
//                      forKeyPath:kCurrentItemKey
//                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
//                         context:AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext];
        
        /* Observe the AVPlayer "rate" property to update the scrubber control. */
//        [self.player addObserver:self
//                      forKeyPath:kRateKey
//                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
//                         context:AVPlayerDemoPlaybackViewControllerRateObservationContext];
    }
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (self.player.currentItem != self.mPlayerItem)
    {
        /* Replace the player item with a new player item. The item replacement occurs
         asynchronously; observe the currentItem property to find out when the
         replacement will/did occur*/
        [self.player replaceCurrentItemWithPlayerItem:self.mPlayerItem];
        
//        [self syncPlayPauseButtons];
    }
	
//    [self.mScrubber setValue:0.0];
}

- (IBAction)loadAssetFromFile:sender {
    
    
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileUrl options:nil];
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
                        
//                        ^{
//                            NSError *error;
//                            AVKeyValueStatus status = [asset statusOfValueForKey:tracksKey error:&error];
//                            NSLog(@"Any errors?????????? %@", error);
//                            
//                            if (status == AVKeyValueStatusLoaded) {
////                                self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
//                                self.playerItem = [[AVPlayerItem playerItemWithURL:fileUrl] retain]; // MK retain??
//                                [self.playerItem addObserver:self forKeyPath:@"status"
//                                                     options:0 context:&ItemStatusContext];
//                                [[NSNotificationCenter defaultCenter] addObserver:self
//                                                                         selector:@selector(playerItemDidReachEnd:)
//                                                                             name:AVPlayerItemDidPlayToEndTimeNotification
//                                                                           object:self.playerItem];
//                                self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
//
//                                [self.player retain]; // MK ???
//
//                                [self.playerView setPlayer:self.player];
//                                
//                                if (self.player.currentItem != self.playerItem) {
//                                    [[self player] replaceCurrentItemWithPlayerItem:self.playerItem];
//                                }
//                                
//                                [self.view addSubview:self.playerView];
//                                NSLog(@"INFO: %@ / %@", self.playerItem.asset, self.playerItem.tracks);
//
//                                // added
//                                [self play:NULL];
//                            }
//                            else {
//                                // You should deal with the error appropriately.
//                                NSLog(@"The asset's tracks were not loaded:\n%@", [error localizedDescription]);
//                            }
//                        });
//     }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    
	/* AVPlayerItem "status" property value observer. */
	if (context == AVPlayerDemoPlaybackViewControllerStatusObservationContext)
	{
//		[self syncPlayPauseButtons];
        
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

                
//                if (! self.playerView) {
//                    self.playerView = [MFAVideoPlayerUIView new];
//                  self.playerView.player = player;
//                 player.closedCaptionDisplayEnabled = YES;
//                    [self.view addSubview:self.playerView];
//                    [self enablePlayerButtons];
//                  [player play];
//                }
                
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
    else if (context == &ItemStatusContext) {
        dispatch_async(dispatch_get_main_queue(),
                       ^{
                           [self syncUI];
                       });
        return;
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object
                           change:change context:context];
    }
    return;
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


- (void)playerItemDidReachEnd:(NSNotification *)notification {
  //    [self.player seekToTime:kCMTimeZero];
}











#pragma mark -
#pragma mark Play, Stop buttons

/* Show the stop button in the movie player controller. */
-(void)showStopButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems replaceObjectAtIndex:0 withObject:self.mStopButton];
    self.mToolbar.items = toolbarItems;
}

/* Show the play button in the movie player controller. */
-(void)showPlayButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems replaceObjectAtIndex:0 withObject:self.mPlayButton];
    self.mToolbar.items = toolbarItems;
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





- (void)handleSwipe:(UISwipeGestureRecognizer *)gestureRecognizer
{
    
    NSLog(@"SWIPE!!!!!!!!!!!!!");
    UIView* view = [self view];
	UISwipeGestureRecognizerDirection direction = [gestureRecognizer direction];
	CGPoint location = [gestureRecognizer locationInView:view];
	
	if (location.y < CGRectGetMidY([view bounds]))
	{
		if (direction == UISwipeGestureRecognizerDirectionUp)
		{
			[UIView animateWithDuration:0.2f animations:
             ^{
                 [[self navigationController] setNavigationBarHidden:YES animated:YES];
             } completion:
             ^(BOOL finished)
             {
                 [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
             }];
		}
		if (direction == UISwipeGestureRecognizerDirectionDown)
		{
			[UIView animateWithDuration:0.2f animations:
             ^{
                 [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
             } completion:
             ^(BOOL finished)
             {
                 [[self navigationController] setNavigationBarHidden:NO animated:YES];
             }];
		}
	}
	else
	{
		if (direction == UISwipeGestureRecognizerDirectionDown)
		{
            if (![self.mToolbar isHidden])
			{
				[UIView animateWithDuration:0.2f animations:
                 ^{
                     [self.mToolbar setTransform:CGAffineTransformMakeTranslation(0.f, CGRectGetHeight([self.mToolbar bounds]))];
                 } completion:
                 ^(BOOL finished)
                 {
                     [self.mToolbar setHidden:YES];
                 }];
			}
		}
		else if (direction == UISwipeGestureRecognizerDirectionUp)
		{
            if ([self.mToolbar isHidden])
			{
				[self.mToolbar setHidden:NO];
				
				[UIView animateWithDuration:0.2f animations:
                 ^{
                     [self.mToolbar setTransform:CGAffineTransformIdentity];
                 } completion:^(BOOL finished){}];
			}
		}
	}
}

- (IBAction)pause:(id)sender
{
	NSLog(@"Pause");
    [self.player pause];
    [self showPlayButton];
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
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
//    {
//        return [self initWithNibName:@"AVPlayerDemoPlaybackView-iPad" bundle:nil];
//	}
//    else
//    {
        return [self initWithNibName:@"MFAVideoPlayer" bundle:nil];
//	}
}



- (void)viewDidLoad
{
    
    [self setPlayer:nil];
    
	UIView* view  = [self view];
    
	UISwipeGestureRecognizer* swipeUpRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
	[swipeUpRecognizer setDirection:UISwipeGestureRecognizerDirectionUp];
	[view addGestureRecognizer:swipeUpRecognizer];
	[swipeUpRecognizer release];
	
	UISwipeGestureRecognizer* swipeDownRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
	[swipeDownRecognizer setDirection:UISwipeGestureRecognizerDirectionDown];
	[view addGestureRecognizer:swipeDownRecognizer];
	[swipeDownRecognizer release];
    
    UIBarButtonItem *scrubberItem = [[UIBarButtonItem alloc] initWithCustomView:self.mScrubber];
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    self.mToolbar.items = [NSArray arrayWithObjects:self.mPlayButton, flexItem, scrubberItem, nil];
    
    
	[self initScrubberTimer];
	[self syncPlayPauseButtons];
	[self syncScrubber];
    
    [super viewDidLoad];
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (void)dealloc {
    [playerView release];
//    [_mPlayBackView release];
    [super dealloc];
}
- (void)viewDidUnload {
//    [Player release];
//    Player = nil;
    [playerView release];
    playerView = nil;;
    [super viewDidUnload];
}
@end
