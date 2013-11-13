#import "VideoStop.h"

#import "KeypadController.h"
#import "LandscapeMoviePlayerViewController.h"
#import "SplashController.h"
#import "StopGroupController.h"
#import "TapAppDelegate.h"
#import "MFAVideoPlayerControllerViewController.h"

@implementation VideoStop

@synthesize isAudio;

- (NSString*)getSourcePath
{
	for (xmlNodePtr child = stopNode->children; child != NULL; child = child->next) {
		if (xmlStrEqual(child->name, (xmlChar*)"Source")) {
			char *src = (char*)xmlNodeGetContent(child);
			NSString *result = [[NSString stringWithUTF8String:src] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			free(src);
			return result;
		}
	}
	
	return nil;
}

#pragma mark -
#pragma mark BaseStop

- (NSString *)getIconPath
{
	if (isAudio) {
		return [[NSBundle mainBundle] pathForResource:@"icon-audio" ofType:@"png"];
	}
	return [[NSBundle mainBundle] pathForResource:@"icon-video" ofType:@"png"];
}

- (NSArray *)getAllFiles
{
	return [NSArray arrayWithObject:[self getSourcePath]];
}

- (BOOL)providesViewController
{
	return NO;
}

- (BOOL)loadStopView
{	
	// Get path to video from bundle
	NSBundle *tourBundle = [[(TapAppDelegate *)[[UIApplication sharedApplication] delegate] currentTourController] tourBundle];
	NSString *videoSrc = [self getSourcePath];
	NSString *videoPath = [tourBundle pathForResource:[[videoSrc lastPathComponent] stringByDeletingPathExtension]
											   ofType:[[videoSrc lastPathComponent] pathExtension]
										  inDirectory:[videoSrc stringByDeletingLastPathComponent]];
	if (!videoPath) {
		return NO;
	}
	NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
	
	// Create new view controller
    
    BOOL useOriginalPlayer = YES;
    NSString * ext = [[videoSrc lastPathComponent] pathExtension];
    useOriginalPlayer =  (!([ext isEqualToString:@"mov"] || [ext isEqualToString:@"m4v"]));
    
    if (useOriginalPlayer) {
        LandscapeMoviePlayerViewController *moviePlayerController = [[LandscapeMoviePlayerViewController alloc] initWithContentURL:videoURL];
	
        // Add finished observer
        [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(moviePlayBackDidFinish:)
												 name:MPMoviePlayerPlaybackDidFinishNotification
											   object:[moviePlayerController moviePlayer]];
        [[(TapAppDelegate*)[[UIApplication sharedApplication] delegate] currentTourController] presentMoviePlayerViewControllerAnimated:moviePlayerController];
        [[moviePlayerController moviePlayer] play];
        [moviePlayerController release];
	} else {
        // New Player
        MFAVideoPlayerControllerViewController * mfaVidController = [[MFAVideoPlayerControllerViewController alloc] init];
        mfaVidController.fileUrl = videoURL;
        [mfaVidController loadAssetFromFile:NULL];

        [[(TapAppDelegate*)[[UIApplication sharedApplication] delegate] currentTourController] presentModalViewController:mfaVidController animated:NO];

        
//        UIViewController * topController = [(TapAppDelegate*)[[UIApplication sharedApplication] delegate] currentTourController];
//        UIView * topView = topController.view;
//        [topView setWantsLayer:YES];

//        [topView addSubview:mfaVidController.view];
//        [topView addSubview:mfaVidController.view];

    }
    
    
	// Present the controller modally since MPMoviePlayerController doesn't auto-takeover anymore
//	TourController *tourController = [(TapAppDelegate*)[[UIApplication sharedApplication] delegate] currentTourController];
//	if ([tourController parentViewController]) {
//		[tourController presentMoviePlayerViewControllerAnimated:moviePlayerController];
//	}
//	else {
//		SplashController *splashController = (SplashController *)[[(TapAppDelegate *)[[UIApplication sharedApplication] delegate] menuController] modalViewController];
//		[splashController presentMoviePlayerViewControllerAnimated:moviePlayerController];
//	}
    
    
	
	// Retain self to stay around for moviePlayBackDidFinish
	[self retain];
	
	return YES;
}

- (void)moviePlayBackDidFinish:(NSNotification *)notification
{	
	// Remove observer
	MPMoviePlayerController *moviePlayer = [notification object];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:MPMoviePlayerPlaybackDidFinishNotification
												  object:moviePlayer];
	// Dismiss video
	TourController *tourController = [(TapAppDelegate*)[[UIApplication sharedApplication] delegate] currentTourController];
	if ([tourController parentViewController]) {
		[tourController dismissMoviePlayerViewControllerAnimated];
	}
	else {
		SplashController *splashController = (SplashController *)[[(TapAppDelegate *)[[UIApplication sharedApplication] delegate] menuController] modalViewController];
		[splashController dismissMoviePlayerViewControllerAnimated];
	}
	
	// Remove highlight from stop if in a stop group
	if ([[[tourController navigationController] visibleViewController] isKindOfClass:[StopGroupController class]]) {
		UITableView *stopTable = [(StopGroupController*)[[tourController navigationController] visibleViewController] stopTable];
		[stopTable deselectRowAtIndexPath:[stopTable indexPathForSelectedRow] animated:YES];
	}
	
	// Clear the code if in a keypad
	else if ([[[tourController navigationController] visibleViewController] isKindOfClass:[KeypadController class]]) {
		[(KeypadController*)[[tourController navigationController] visibleViewController] clearCode];
	}
	
	// Track in analytics
	[Analytics trackAction:@"movie-stop" forStop:[self getStopId]];
	
	// Release self now that moviePlayBackDidFinish is done
	[self release];
}

@end
