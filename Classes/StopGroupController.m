#import "StopGroupController.h"
#import "TapAppDelegate.h"
#import "TourController.h"

@interface StopGroupController (PrivateMethods)

- (void)showControls;
- (void)showControlsAndFadeOut:(NSTimeInterval)seconds;
- (void)hideControls;
- (void)cancelControlsTimer;

- (void)checkForAutoplay;
- (BOOL)audioStopIsVideo:(VideoStop *)audioStop;

- (void)playAudio:(NSString *)audioSrc;
- (void)stopAudio;
- (void)updateViewForAudioPlayerInfo;
- (void)updateViewForAudioPlayerState;
- (void)updateCurrentTimeForAudioPlayer;

- (void)playVideo:(NSString *)videoSrc;
- (void)stopVideo;
- (void)hideVideo;
- (void)updateViewForVideoPlayerDimensions;
- (void)updateViewForVideoPlayerInfo;
- (void)updateViewForVideoPlayerState;
- (void)updateCurrentTimeForVideoPlayer;

- (CGRect)zoomRectForScale:(float)scale withCenter:(CGPoint)center;

@end

#pragma mark -

@implementation StopGroupController

@synthesize stopTable, moviePlayerController, stopGroup;
@synthesize scrollOverflowIndicator;

MPMoviePlayerController * permanentMoviePlayerController;

- (id)initWithStopGroup:(StopGroup*)stop
{
	if ((self = [super initWithNibName:@"StopGroup" bundle:[NSBundle mainBundle]])) {
		[self setStopGroup:stop];
		[self setTitle:[stopGroup getTitle]];
		firstRun = YES;
	}
	return self;
}

- (void)viewDidUnload
{
    /* Not needed in iOS6+ */
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"SGC: viewDidUnload did removeObserver");
    
    [super viewDidUnload];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"SGC: dealloc did removeObserver");
	[controlsTimer release];
	[audioPlayer release];
	[autoplayTimer release];
	[updateTimer release];
	[progressView release];
	[currentTime release];
	[duration release];
	[progressBar release];
	[playButton release];
	[volumeView release];
	[volumeSlider release];
	[scrollView release];
	[stopTableShadow release];
	[stopTable release];
	[imageView release];
	[moviePlayerHolder release];
	[moviePlayerTapDetector release];
	[moviePlayerController release];
	[stopGroup release];
	[super dealloc];
}

#pragma mark -
#pragma mark UIViewController

NSTimeInterval mkLogInt;

-(void)mkLogInit {
    mkLogInt = [NSDate timeIntervalSinceReferenceDate];
}
-(void)mkLog:(NSString*)string {
    NSLog(@"%f SGV %@", [NSDate timeIntervalSinceReferenceDate] - mkLogInt, string);
}

- (void)viewDidLoad
{
    [self mkLogInit];
    [self mkLog:@"SGV ViewDidLoad start"];

    self.navigationItem.backBarButtonItem =
    [[[UIBarButtonItem alloc] initWithTitle:@"Back"
                                      style:UIBarButtonItemStyleBordered
                                     target:nil
                                     action:nil] autorelease];

    
	// Calculate table height
	UIImage *background = [UIImage imageNamed:@"table-cell-bg.png"];
	NSInteger numberOfStops = [[self stopGroup] numberOfStops];
    // NSLog(@"NumberofStops is %d", numberOfStops);
	CGFloat tableHeight = numberOfStops	* background.size.height;
	
	// Set up header image, try portrait image first but get landscape image if portrait isn't available
	NSString *headerImageSrc = [stopGroup getHeaderPortraitImage];
	if (headerImageSrc == nil) {
		headerImageSrc = [stopGroup getHeaderLandscapeImage];
	}
	if (headerImageSrc != nil) {
		
		// Set up image
		NSBundle *tourBundle = [((TourController*)[self navigationController]) tourBundle];
        
//        NSLog(@"%@ ::: %@ / %@ / %@", headerImageSrc, [headerImageSrc lastPathComponent], [[headerImageSrc lastPathComponent] stringByDeletingPathExtension], [headerImageSrc stringByDeletingLastPathComponent]
//              );
        
		NSString *imagePath = [tourBundle pathForResource:[[headerImageSrc lastPathComponent] stringByDeletingPathExtension]
												   ofType:[[headerImageSrc lastPathComponent] pathExtension]
											  inDirectory:[headerImageSrc stringByDeletingLastPathComponent]];
      //  NSLog(@"Loading image at %@", imagePath);
		imageView = [[TapDetectingImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imagePath]];
		[imageView setDelegate:self];
		
		// Calculate image scale
		CGFloat scale;
        

        
        BOOL experimental = YES;
        if (experimental) {
            scale = 1.0f;
        } else {
            scale = scrollView.frame.size.width / imageView.image.size.width;
        }
        

        [self mkLog:@"scale point 0"];

        
        //NSLog(@"Scale from %f / %f", scrollView.frame.size.width, imageView.image.size.width);
//        NSLog(@"Scale is %f", scale);
		// Setup scroll view
		if (self.view.frame.size.height - imageView.image.size.height * scale >= tableHeight) {
			[scrollView setFrame:CGRectMake(0, 0, scrollView.frame.size.width, imageView.image.size.height * scale)];
			lastRowNeedsPadding = ((self.view.frame.size.height - tableHeight) - (imageView.image.size.height * scale)) > background.size.height;
		}
		else {
			if (numberOfStops > 5) {
				tableHeight = background.size.height * 5;
			}
			[scrollView setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - tableHeight)];
			lastRowNeedsPadding = YES;
		}
		[scrollView setBackgroundColor:[UIColor blackColor]];
		[scrollView setMinimumZoomScale:scale];
		[scrollView setMaximumZoomScale:scale];
        [self mkLog:@"scale point 1"];

//        scale = 1.0f;
       // NSLog(@"Setting scale: %f", scale);

		[scrollView setZoomScale:scale];
        
//        NSLog(@"Setting content size %f %f", imageView.frame.size.width, imageView.frame.size.height);
		[scrollView setContentSize:imageView.frame.size];
		if (imageView.frame.size.height > scrollView.frame.size.height) {
			[scrollView scrollRectToVisible:CGRectMake(0, (imageView.frame.size.height - scrollView.frame.size.height) / 2, scrollView.frame.size.width, scrollView.frame.size.height) animated:NO];
		}
		[scrollView addSubview:imageView];
	}
	else {
		
		// Hide scroll view
		[scrollView setFrame:CGRectMake(0, 0, self.view.frame.size.width, 0)];
		[scrollView setHidden:YES];
        [self mkLog:@"scale point 2"];

	}
    [self mkLog:@"scale point 3"];

	// Setup table
	[stopTable setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"table-bg.png"]]];
	[stopTable setRowHeight:[background size].height];
	[stopTable setFrame:CGRectMake(0, scrollView.frame.origin.y + scrollView.frame.size.height, self.view.frame.size.width, self.view.frame.size.height - scrollView.frame.size.height)];
	if (stopTable.frame.size.height < numberOfStops * background.size.height) {
		[stopTable setScrollEnabled:YES];
	}
	
	// Setup shadow
	[stopTableShadow setFrame:CGRectMake(stopTable.frame.origin.x, stopTable.frame.origin.y, stopTableShadow.frame.size.width, stopTableShadow.frame.size.height)];
	[[self view] insertSubview:stopTableShadow aboveSubview:stopTable];

    [self mkLog:@"stopTable x"];

	// Setup audio controls
	[progressView setFlipped:YES];
	[progressBar setMaximumTrackImage:[UIImage imageNamed:@"audio-slider-minimum.png"] forState:UIControlStateNormal];
	[progressBar setMinimumTrackImage:[UIImage imageNamed:@"audio-slider-maximum.png"] forState:UIControlStateNormal];
	[progressBar setThumbImage:[UIImage imageNamed:@"audio-handle.png"] forState:UIControlStateNormal];
	[volumeView setFrame:CGRectMake(0, scrollView.frame.size.height - volumeView.frame.size.height, volumeView.frame.size.width, volumeView.frame.size.height)];
    [self mkLog:@"progressBar x"];

	// Replace volume slider with MPVolumeView so it's tied to the system audio
	MPVolumeView *systemVolumeSlider = [[MPVolumeView alloc] initWithFrame:[volumeSlider frame]];
	[[volumeSlider superview] addSubview:systemVolumeSlider];
	[volumeSlider removeFromSuperview];
	[volumeSlider release];
	[systemVolumeSlider release];
    [self mkLog:@"volumeSlider x"];

	// Setup up movie player
    BOOL experimentalMP = YES;
    if (experimentalMP) {
        [self mkLog:@"altMP 5.0"];
        moviePlayerHolder = [[UIView alloc] initWithFrame:[scrollView frame]];
        [self mkLog:@"altMP 5.1"];
        if (! permanentMoviePlayerController) {
            [self mkLog:@"altMP 5.1b"];
            permanentMoviePlayerController =  [[MPMoviePlayerController alloc] init];
            [permanentMoviePlayerController setShouldAutoplay:YES];
            [permanentMoviePlayerController setControlStyle:MPMovieControlStyleNone];
            [self mkLog:@"altMP 5.1c"];
        }
        moviePlayerController = permanentMoviePlayerController;
        [self mkLog:@"altMP 5.2"];
        [[moviePlayerController view] setFrame:[scrollView frame]];
        [self mkLog:@"altMP 5.3"];
        [moviePlayerController setContentURL:nil];
    } else {
        // standard/early
        moviePlayerHolder = [[UIView alloc] initWithFrame:[scrollView frame]];
        [self mkLog:@"moviePlayerController 0.1"];
        moviePlayerController = [[MPMoviePlayerController alloc] init];
        [self mkLog:@"moviePlayerController 0.2"];
        [[moviePlayerController view] setFrame:[scrollView frame]];
        [self mkLog:@"moviePlayerController 0.3"];
        [moviePlayerController setShouldAutoplay:YES];
        [self mkLog:@"moviePlayerController 0.4"];
        [moviePlayerController setControlStyle:MPMovieControlStyleNone];
        //	[moviePlayerController setScalingMode:MPMovieScalingModeAspectFill];
        [self mkLog:@"moviePlayerController 0.5"];
        [moviePlayerController setContentURL:nil];
        [self mkLog:@"moviePlayerController 0.x"];
    }
    
    NSLog(@"MoviePlayerHolder %@", [scrollView frame]);

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoPlayerNaturalSizeAvailable:) name:MPMovieNaturalSizeAvailableNotification object:moviePlayerController];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoPlayerDurationAvailable:) name:MPMovieDurationAvailableNotification object:moviePlayerController];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoPlayerPlaybackStateDidChange:) name:MPMoviePlayerPlaybackStateDidChangeNotification object:moviePlayerController];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoPlayerPlaybackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:moviePlayerController];
    [self mkLog:@"moviePlayerController 1"];
	[moviePlayerHolder addSubview:[moviePlayerController view]];
	moviePlayerTapDetector = [[TapDetectingView alloc] initWithFrame:[scrollView bounds]];
	[moviePlayerTapDetector setDelegate:self];
	[moviePlayerHolder addSubview:moviePlayerTapDetector];
	[moviePlayerHolder setAlpha:0.0f];
    [self mkLog:@"moviePlayerController x"];
    [self mkLog:@"SGV ViewDidLoad Done"];
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
	// Deselect anything from the table
	[stopTable deselectRowAtIndexPath:[stopTable indexPathForSelectedRow] animated:animated];
	[self willRotateToInterfaceOrientation:[self interfaceOrientation] duration:0.0];
	[super viewWillAppear:animated];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    
    BOOL shouldAutoplay = NO;
    // June 2014: turning off autoplay per MFA
    
	// Check for intro
	if (firstRun) {
		firstRun = NO;
		if (autoplayTimer) {
			[autoplayTimer invalidate];
		}
        if (shouldAutoplay) {
            autoplayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(checkForAutoplay) userInfo:nil repeats:NO];
        }
	}
	
	// Flash scroll bars
	if ([stopTable isScrollEnabled]) {
		[stopTable flashScrollIndicators];
	}
	
	[super viewDidAppear:animated];
    [self initializeScrollOverflowIndicator];
//    NSLog(@"stopTable CONTENT %f x %f", stopTable.contentSize.width, stopTable.contentSize.height);
//    NSLog(@"stopTable WINDOW %f x %f", stopTable.frame.size.width, stopTable.frame.size.height);
//    NSLog(@"stopTable %d aix-enrows; %f height", [stopTable numberOfRowsInSection:0], [stopTable rowHeight]);

    
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)inScrollView {
    [self hideScrollOverflow];
}

- (void) initializeScrollOverflowIndicator {
    [scrollOverflowIndicator setAlpha:([self scrollContentOverflows] ? 1.0f : 0.0f)];
    
    [scrollOverflowIndicator setHidden:NO];
}
- (void) hideScrollOverflow {
    [UIView transitionWithView:self.view duration:0.35 options:UIViewAnimationCurveEaseInOut animations:^{
        [scrollOverflowIndicator setAlpha:0.0f];
    } completion:nil];

}

- (BOOL) scrollContentOverflows {
    float extra = (stopTable.contentSize.height - stopTable.frame.size.height);
    return (extra > 0.0);

}

- (void)viewWillDisappear:(BOOL)animated
{
	if (autoplayTimer) {
		[autoplayTimer invalidate];
		autoplayTimer = nil;
	}
	[self stopAudio];
	[self stopVideo];
	[super viewWillDisappear:animated];
}

#pragma mark -
#pragma mark TapDetectingImageViewDelegate

- (void)tapDetectingImageView:(TapDetectingImageView *)view gotSingleTapAtPoint:(CGPoint)tapPoint
{
	if ([progressView isHidden]) {
		[self showControls];
	}
	else {
		[self hideControls];
	}
}

#pragma mark -
#pragma mark TapDetectingViewDelegate

- (void)tapDetectingView:(TapDetectingView *)view gotSingleTapAtPoint:(CGPoint)tapPoint
{
	[self cancelControlsTimer];
	if ([progressView isHidden]) {
		[self showControls];
	}
	else {
		[self hideControls];
	}
}

#pragma mark -
#pragma mark Controls

- (void)showControls
{
	[progressView setHidden:NO];
	[progressView setAlpha:0.0f];
	[volumeView setHidden:NO];
	[volumeView setAlpha:0.0f];
	[UIView animateWithDuration:0.25f animations:^{
		[progressView setAlpha:1.0f];
		[volumeView setAlpha:1.0f];
	}];
	
}

- (void)showControlsAndFadeOut:(NSTimeInterval)seconds
{
	[self showControls];
	if (controlsTimer) {
		[controlsTimer invalidate];
	}
	controlsTimer = [NSTimer scheduledTimerWithTimeInterval:2.5f target:self selector:@selector(hideControls) userInfo:nil repeats:NO];
}

- (void)hideControls
{
	// Cleanup controls timer since it automatically release
	controlsTimer = nil;
	
	// Fade out controls
	[UIView animateWithDuration:0.25f animations:^{
		[progressView setAlpha:0.0f];
		[volumeView setAlpha:0.0f];
	} completion:^(BOOL finished){
		[progressView setHidden:YES];
		[volumeView setHidden:YES];
	}];
}

- (void)cancelControlsTimer
{
	if (controlsTimer) {
		[controlsTimer invalidate];
		controlsTimer = nil;
	}	
}

- (void)togglePlay
{
	[playButton setImage:[UIImage imageNamed:@"audio-play-up.png"] forState:UIControlStateNormal];
	[playButton setImage:[UIImage imageNamed:@"audio-play-down.png"] forState:UIControlStateSelected];
}

- (void)togglePause
{
	[playButton setImage:[UIImage imageNamed:@"audio-pause-up.png"] forState:UIControlStateNormal];
	[playButton setImage:[UIImage imageNamed:@"audio-pause-down.png"] forState:UIControlStateSelected];
}

- (IBAction)progressSliderTouchDown:(UISlider *)sender
{
	[self cancelControlsTimer];
	if ([[moviePlayerController view] isDescendantOfView:[self view]]) {
		[moviePlayerController pause];
		isSeeking = YES;
	}
}

- (IBAction)progressSliderTouchUp:(UISlider *)sender
{
	if ([[moviePlayerController view] isDescendantOfView:[self view]]) {
		if (moviePlayerIsPlaying && [moviePlayerController playbackState] != MPMoviePlaybackStatePlaying) {
			[moviePlayerController play];
		}
		isSeeking = NO;
	}
}

- (IBAction)progressSliderMoved:(UISlider *)sender
{
	if ([[moviePlayerController view] isDescendantOfView:[self view]]) {
		moviePlayerController.currentPlaybackTime = sender.value;
		[self updateCurrentTimeForVideoPlayer];
	}
	else {
		audioPlayer.currentTime = sender.value;
		[self updateCurrentTimeForAudioPlayer];
	}
}

- (IBAction)playButtonPressed:(UIButton *)sender
{
	[self cancelControlsTimer];
	if ([[moviePlayerController view] isDescendantOfView:[self view]]) {
		if ([moviePlayerController playbackState] == MPMoviePlaybackStatePlaying) {
			[moviePlayerController pause];
		}
		else {
			[moviePlayerController play];
		}
		[self updateViewForVideoPlayerState];
	}
	else {
		if (audioPlayer.playing) {
			[audioPlayer pause];
		}
		else {
			[audioPlayer play];
		}
		[self updateViewForAudioPlayerState];
	}
}

- (IBAction)volumeSliderMoved:(UISlider *)sender
{
	audioPlayer.volume = [sender value];
}

#pragma mark -
#pragma mark Audio Player

- (void)checkForAutoplay
{
	// Cleanup autoplay timer since it is automatically released
	autoplayTimer = nil;
	
	// Check type of first stop to determine if it should autoplay
	BaseStop *refStop = [[self stopGroup] stopAtIndex:0];
	if ([refStop isKindOfClass:[VideoStop class]] &&
		[(VideoStop *)refStop isAudio]) {
		VideoStop *audioStop = (VideoStop *)refStop;
		NSString *audioSrc = [audioStop getSourcePath];
		if ([self audioStopIsVideo:audioStop]) {
			[self playVideo:audioSrc];
		}
		else {
			[self playAudio:audioSrc];
			[self showControls];
		}
		[stopTable selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:YES scrollPosition:UITableViewScrollPositionNone];
	}
}

- (BOOL)audioStopIsVideo:(VideoStop *)audioStop
{
	NSString *audioSrc = [audioStop getSourcePath];
	NSString *audioExtension = [[audioSrc pathExtension] lowercaseString];
	if ([audioExtension isEqualToString:@"mp4"]) {
		return YES;
	}
	return NO;
}

- (void)playAudio:(NSString *)audioSrc
{	
	// Get path to sound
	NSBundle *tourBundle = [((TourController*)[self navigationController]) tourBundle];
	NSString *audioPath = [tourBundle pathForResource:[[audioSrc lastPathComponent] stringByDeletingPathExtension]
											   ofType:[[audioSrc lastPathComponent] pathExtension]
										  inDirectory:[audioSrc stringByDeletingLastPathComponent]];

	// Check to see if file exists in bundle
	if (!audioPath) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error Loading Audio" message:@"The audio file for this stop could not be found." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alertView show];
		[alertView release];
		[stopTable deselectRowAtIndexPath:[stopTable indexPathForSelectedRow] animated:YES];
		return;
	}
	
	// Check to see if it or anything is playing
	NSURL *audioUrl = [[NSURL alloc] initFileURLWithPath:audioPath];
	if (audioPlayer) {
		if ([audioUrl isEqual:[audioPlayer url]]) {
			[audioUrl release];
			return;
		}
		[audioPlayer stop];
	}
	
	// Play sound
	if (audioPlayer) {
		[audioPlayer stop];
		[audioPlayer release];
	}
	audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioUrl error:nil];
	if (audioPlayer) {
		[audioPlayer play];
		[self updateViewForAudioPlayerInfo];
		[self updateViewForAudioPlayerState];
		[audioPlayer setDelegate:self];
	}
	[audioUrl release];
}

- (void)stopAudio
{
	if (audioPlayer) {
		[audioPlayer stop];
		[audioPlayer release];
		audioPlayer = nil;
	}
}

- (void)updateViewForAudioPlayerInfo
{
	duration.text = [NSString stringWithFormat:@"%d:%02d", (int)audioPlayer.duration / 60, (int)audioPlayer.duration % 60, nil];
	progressBar.maximumValue = audioPlayer.duration;
}

- (void)updateViewForAudioPlayerState
{
	[self updateCurrentTimeForAudioPlayer];
	if (updateTimer) {
		[updateTimer invalidate];
		updateTimer = nil;
	}
	if (audioPlayer.playing) {
		[self togglePause];
		updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.01f target:self selector:@selector(updateCurrentTimeForAudioPlayer) userInfo:audioPlayer repeats:YES];
	}
	else {
		[self togglePlay];
	}
}

- (void)updateCurrentTimeForAudioPlayer
{
	currentTime.text = [NSString stringWithFormat:@"%d:%02d", (int)audioPlayer.currentTime / 60, (int)audioPlayer.currentTime % 60, nil];
	progressBar.value = audioPlayer.currentTime;
}

#pragma mark -
#pragma mark AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
	[audioPlayer setCurrentTime:0.0f];
	[self updateViewForAudioPlayerState];
}

- (void)playerDecodeErrorDidOccur:(AVAudioPlayer *)p error:(NSError *)error
{
	// Alert?
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)p
{
	[self updateViewForAudioPlayerState];
}

#pragma mark -
#pragma mark Video Player

- (void)playVideo:(NSString *)videoSrc
{
	// Get path to video
	NSBundle *tourBundle = [((TourController*)[self navigationController]) tourBundle];
	NSString *videoPath = [tourBundle pathForResource:[[videoSrc lastPathComponent] stringByDeletingPathExtension]
											   ofType:[[videoSrc lastPathComponent] pathExtension]
										  inDirectory:[videoSrc stringByDeletingLastPathComponent]];
	
	// Check to see if file exists in bundle
	if (!videoPath) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error Loading Video" message:@"The video file for this stop could not be found." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alertView show];
		[alertView release];
		[stopTable deselectRowAtIndexPath:[stopTable indexPathForSelectedRow] animated:YES];
		return;
	}
	
	// Load video
	NSURL *videoUrl = [NSURL fileURLWithPath:videoPath];
	if ([[moviePlayerController contentURL] isEqual:videoUrl]) {
		[moviePlayerController setCurrentPlaybackTime:0.0f];
		[moviePlayerController play];
	}
	else {
		[moviePlayerController setContentURL:videoUrl];
	}
	
	// Add video to stage if needed and fade in
	if (![moviePlayerHolder isDescendantOfView:[self view]]) {
		[[self view] insertSubview:moviePlayerHolder belowSubview:progressView];
	}
}

- (void)stopVideo
{
	[moviePlayerController stop];
}

- (void)hideVideo
{
	[self stopVideo];
	if ([moviePlayerHolder isDescendantOfView:[self view]]) {
		[UIView animateWithDuration:0.5f animations:^{
			[[moviePlayerController view] setFrame:[scrollView frame]];
			[moviePlayerHolder setAlpha:0.0f];
			[moviePlayerHolder setFrame:[scrollView frame]];
			[volumeView setFrame:CGRectMake(0, scrollView.frame.size.height - volumeView.frame.size.height, volumeView.frame.size.width, volumeView.frame.size.height)];
			[stopTable setFrame:CGRectMake(0, scrollView.frame.origin.y + scrollView.frame.size.height, self.view.frame.size.width, self.view.frame.size.height - scrollView.frame.size.height)];
		} completion:^(BOOL finished) {
			[moviePlayerHolder removeFromSuperview];
		}];
	}
}

- (void)videoPlayerNaturalSizeAvailable:(NSNotification *)notification
{
	[self updateViewForVideoPlayerDimensions];
}

- (void)videoPlayerDurationAvailable:(NSNotification *)notification
{
	[self updateViewForVideoPlayerInfo];
}

- (void)videoPlayerPlaybackStateDidChange:(NSNotification *)notification
{
	if ([moviePlayerController playbackState] == MPMoviePlaybackStatePlaying &&
		[moviePlayerHolder alpha] < 1.0f) {
		[UIView animateWithDuration:0.5f animations:^{
			[moviePlayerHolder setAlpha:1.0f];
		}];
		[self showControlsAndFadeOut:4.0f];
	}
	[self updateViewForVideoPlayerState];
}

- (void)videoPlayerPlaybackDidFinish:(NSNotification *)notification
{
	[self updateViewForVideoPlayerState];
	[self hideControls];
	[self hideVideo];
	[stopTable deselectRowAtIndexPath:[stopTable indexPathForSelectedRow] animated:YES];
}

- (void)updateViewForVideoPlayerDimensions
{
	CGFloat movieHeight = self.view.frame.size.width / moviePlayerController.naturalSize.width * moviePlayerController.naturalSize.height;
	[UIView animateWithDuration:0.5f animations:^{
		[[moviePlayerController view] setFrame:CGRectMake(moviePlayerController.view.frame.origin.x, moviePlayerController.view.frame.origin.y, moviePlayerController.view.frame.size.width, movieHeight)];
		[moviePlayerHolder setFrame:CGRectMake(moviePlayerHolder.frame.origin.x, moviePlayerHolder.frame.origin.y, moviePlayerHolder.frame.size.width, movieHeight)];
		[volumeView setFrame:CGRectMake(0, moviePlayerHolder.frame.size.height - volumeView.frame.size.height, volumeView.frame.size.width, volumeView.frame.size.height)];
		[stopTable setFrame:CGRectMake(0, moviePlayerHolder.frame.origin.y + moviePlayerHolder.frame.size.height, self.view.frame.size.width, self.view.frame.size.height - moviePlayerHolder.frame.size.height)];
	}];
}

- (void)updateViewForVideoPlayerInfo
{
	duration.text = [NSString stringWithFormat:@"%d:%02d", (int)moviePlayerController.duration / 60, (int)moviePlayerController.duration % 60, nil];
	progressBar.maximumValue = moviePlayerController.duration;
}

- (void)updateViewForVideoPlayerState
{
	[self updateCurrentTimeForVideoPlayer];
	if (updateTimer) {
		[updateTimer invalidate];
		updateTimer = nil;
	}
	if ([moviePlayerController playbackState] == MPMoviePlaybackStatePlaying) {
		[self togglePause];
		moviePlayerIsPlaying = YES;
		updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.01f target:self selector:@selector(updateCurrentTimeForVideoPlayer) userInfo:moviePlayerController repeats:YES];
	}
	else {
		if (!isSeeking) {
			[self togglePlay];
			moviePlayerIsPlaying = NO;
		}
	}
}

- (void)updateCurrentTimeForVideoPlayer
{
	currentTime.text = [NSString stringWithFormat:@"%d:%02d", (int)moviePlayerController.currentPlaybackTime / 60, (int)moviePlayerController.currentPlaybackTime % 60, nil];
	if (!isSeeking) {
		progressBar.value = moviePlayerController.currentPlaybackTime;
	}
}

#pragma mark -
#pragma mark UIScrollViewDelegate 

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
	return imageView;
}

#pragma mark -
#pragma mark UITableViewDataSource

/**
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [[self stopGroup] getTitle];
}
**/

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[self stopGroup] numberOfStops];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSUInteger idx = [indexPath row];
	BaseStop *refStop = [[self stopGroup] stopAtIndex:idx];
	static NSString *cellIdent = @"stop-group-cell";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdent];
	if (cell == nil) {
		
		// Create a new reusable table cell
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdent] autorelease];
		
		// Set the background
		UIImageView *background = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-cell-bg.png"]];
		[cell setBackgroundView:background];
		[background release];
		UIImageView *selectedBackground = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-cell-bg-selected.png"]];
		[cell setSelectedBackgroundView:selectedBackground];
		[selectedBackground release];
		
		// Init the label
		[[cell textLabel] setOpaque:NO];
		[[cell textLabel] setBackgroundColor:[UIColor clearColor]];
		[[cell textLabel] setFont:[UIFont systemFontOfSize:18]];
		[[cell textLabel] setTextColor:[UIColor whiteColor]];
	}
	
	// Set the title
	[[cell textLabel] setText:[refStop getTitle]];
	if (idx == [[self stopGroup] numberOfStops] - 1 && lastRowNeedsPadding) {
		UIView *padding = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width * 0.1, 10)];
		[cell setAccessoryView:padding];
		[padding release];
	}
	else {
		[cell setAccessoryView:nil];
	}
	
	// Set the associated icon
	[[cell imageView] setImage:[UIImage imageWithContentsOfFile:[refStop getIconPath]]];
	
	return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate

/**
 * ref: http://www.iphonedevsdk.com/forum/iphone-sdk-development/3739-how-should-i-display-detail-view-variable-length-strings.html
 */
/**
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSUInteger idx = [indexPath row];
	BaseStop *refStop = [[self stopGroup] stopAtIndex:idx];
		
	CGFloat result = 44.0f;
	NSString *text = [refStop getDescription];
	CGFloat width = 0;
	CGFloat tableViewWidth;
	CGRect bounds = [UIScreen mainScreen].bounds;
	
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
		tableViewWidth = bounds.size.width;
	} else {
		tableViewWidth = bounds.size.height;
	}
	width = tableViewWidth - 110;		// fudge factor
	
	if (text) {
		// The notes can be of any height
		// This needs to work for both portrait and landscape orientations.
		// Calls to the table view to get the current cell and the rect for the 
		// current row are recursive and call back this method.
		CGSize textSize = { width, 20000.0f };		// width and height of text area
		CGSize size = [text sizeWithFont:[UIFont systemFontOfSize:17.0f] constrainedToSize:textSize lineBreakMode:UILineBreakModeWordWrap];
		
		size.height += 29.0f;			// top and bottom margin
		result = MAX(size.height, 44.0f);	// at least one row
	}
	
	NSLog(@"Calculated row height of %.0f for text: %@", result, text);
	
	return result;
}
 **/

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	// Stop any audio or video
	if (autoplayTimer) {
		[autoplayTimer invalidate];
		autoplayTimer = nil;
	}
	[self stopAudio];
	[self stopVideo];
	
	// Take action for selection
	NSUInteger idx = [indexPath indexAtPosition:1];
	BaseStop *refStop = [[self stopGroup] stopAtIndex:idx];
	if ([refStop isKindOfClass:[VideoStop class]] &&
		[(VideoStop *)refStop isAudio]) {
		VideoStop *audioStop = (VideoStop *)refStop;
		if ([self audioStopIsVideo:audioStop]) {
			[(TourController *)[self navigationController] loadStop:audioStop];
		}
		else {
			NSString *audioSrc = [audioStop getSourcePath];
			[self playAudio:audioSrc];
			[self showControls];
		}
	}
	else {
		[self hideControls];
		[(TourController *)[self navigationController] loadStop:refStop];
	}
}

@end
