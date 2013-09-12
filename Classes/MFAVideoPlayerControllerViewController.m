//
//  MFAVideoPlayerControllerViewController.m
//  MFA Guide
//
//  Created by Matthew Krom on 6/21/13.
//
//

#import "MFAVideoPlayerControllerViewController.h"

@interface MFAVideoPlayerControllerViewController ()

@end

@implementation MFAVideoPlayerControllerViewController

@synthesize fileUrl, player;

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

- (void)syncUI {
    if ((self.player.currentItem != nil) &&
        ([self.player.currentItem status] == AVPlayerItemStatusReadyToPlay)) {
        self.playButton.enabled = YES;
    }
    else {
        self.playButton.enabled = NO;
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}



NSString * const kTracksKey         = @"tracks";
NSString * const kPlayableKey		= @"playable";
/* PlayerItem keys */
NSString * const kStatusKey         = @"status";

/* AVPlayer keys */
NSString * const kRateKey			= @"rate";
NSString * const kCurrentItemKey	= @"currentItem";


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
    if (self.playerItem)
    {
        /* Remove existing player item key value observers and notifications. */
        
        [self.playerItem removeObserver:self forKeyPath:kStatusKey];
		
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.playerItem];
    }
	
    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    /* Observe the player item "status" key to determine when it is ready to play. */
    [self.playerItem addObserver:self
                       forKeyPath:kStatusKey
                          options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                          context:AVPlayerDemoPlaybackViewControllerStatusObservationContext];
	
    /* When the player item has played to its end time we'll toggle
     the movie controller Pause button to be the Play button */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.playerItem];
	
    BOOL seekToZeroBeforePlay = NO;
	
    /* Create new player, if we don't already have one. */
    if (!self.player)
    {
        /* Get a new AVPlayer initialized to play the specified player item. */
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.playerItem]];
		
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
    if (self.player.currentItem != self.playerItem)
    {
        /* Replace the player item with a new player item. The item replacement occurs
         asynchronously; observe the currentItem property to find out when the
         replacement will/did occur*/
        [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
        
//        [self syncPlayPauseButtons];
    }
	
//    [self.mScrubber setValue:0.0];
}

- (IBAction)loadAssetFromFile:sender {
    
    
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileUrl options:nil];
//    NSString *tracksKey = @"tracks";
    
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
//                [self removePlayerTimeObserver];
//                [self syncScrubber];
//                
//                [self disableScrubber];
//                [self disablePlayerButtons];
            }
                break;
                
            case AVPlayerStatusReadyToPlay:
            {
                /* Once the AVPlayerItem becomes ready to play, i.e.
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
                 its duration can be fetched from the item. */
                
//                [self initScrubberTimer];
//                
//                [self enableScrubber];
                if (! self.playerView) {
                    self.playerView = [MFAVideoPlayerUIView new];
                    self.playerView.player = player;
                    player.closedCaptionDisplayEnabled = YES;
                    [self.view addSubview:self.playerView];
//                    [self enablePlayerButtons];
                    [player play];
                }
                
            }
                break;
                
            case AVPlayerStatusFailed:
            {
                AVPlayerItem *playerItem = (AVPlayerItem *)object;
//                [self assetFailedToPrepareForPlayback:playerItem.error];
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
    [player play];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
  //    [self.player seekToTime:kCMTimeZero];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //[self.playerView setBounds:(CGRectMake(0.0, 0.0, 320.0f, 640.0f))];
    [self syncUI];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
