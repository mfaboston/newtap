#import "TapAppDelegate.h"

#import "BackgroundUpdater.h"
#import "FileSharingManager.h"
#import "KeypadController.h"
#import "SplashController.h"
#import "StopGroupController.h"
#import "TourController.h"

enum {
	kBackgroundUpdaterAlert = 1
};

@interface TapAppDelegate (PrivateMethods)

- (void)scheduleBackgroundUpdates;

@end

@implementation TapAppDelegate

@synthesize menuController, currentTourController, backgroundUpdater;

@synthesize clickFileURLRef;
@synthesize clickFileObject;
@synthesize errorFileURLRef;
@synthesize errorFileObject;

@synthesize singleMainMfaVidController;

- (BackgroundUpdater *)backgroundUpdater
{
	if (!backgroundUpdater) {
		backgroundUpdater = [[BackgroundUpdater alloc] init];
		[backgroundUpdater setDelegate:self];
	}
	return backgroundUpdater;
}

- (void)dealloc 
{
	[window release];
	[menuController release];
	[alertView release];
	
	[currentTourController release];
	
	AudioServicesDisposeSystemSoundID(clickFileObject);
    CFRelease(clickFileURLRef);
	AudioServicesDisposeSystemSoundID(errorFileObject);
    CFRelease(errorFileURLRef);
	
    [super dealloc];
}

#define kClosedCaptionsDefaultsKey @"closed_captions"
#define kClosedCaptionsYesValue @"y"

- (void) setCCInDefaults:(BOOL)cc {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:(cc ? kClosedCaptionsYesValue : @"n") forKey:kClosedCaptionsDefaultsKey];
};
- (BOOL) ccFromDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString * ccAsString = [defaults stringForKey:kClosedCaptionsDefaultsKey];
    if (ccAsString) {
        return([ccAsString isEqualToString:kClosedCaptionsYesValue]);
    } else {
        return NO;
    }
}

#pragma mark -
#pragma mark UI Sound Effects

- (void)playClick
{
	AudioServicesPlaySystemSound(clickFileObject);
}

- (void)playError
{
	AudioServicesPlaySystemSound(errorFileObject);
}

#pragma mark -
#pragma mark Tours

- (BOOL)loadTourWithBundleName:(NSString *)bundleName
{
	// Setup tour controller for later, also catch any errors now
	currentTourController = [[TourController alloc] init];
	[currentTourController loadBundle:bundleName];
	KeypadController *keypadController = [[KeypadController alloc] initWithNibName:@"Keypad" bundle:[NSBundle mainBundle]];
	[currentTourController pushViewController:keypadController animated:NO];
	[keypadController release];
	
	// Setup splash controller and present
	SplashController *splashController = [[SplashController alloc] initWithNibName:@"Splash" bundle:[NSBundle mainBundle]];
	[splashController setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
	[menuController presentModalViewController:splashController animated:YES];
	[splashController release];
	
	return YES;
}

- (MFAVideoPlayerControllerViewController *) getSingleMainMfaVidController {
    if (! self.singleMainMfaVidController) {
        self.singleMainMfaVidController = [[[MFAVideoPlayerControllerViewController alloc] init] autorelease];
    }
    return singleMainMfaVidController;
}


- (void)closeTour
{
	[menuController dismissModalViewControllerAnimated:YES];
	[currentTourController release];
	currentTourController = nil;
}

- (void)closeTourAndShowUpdater
{
	[menuController dismissModalViewControllerAnimated:NO];
	[menuController showUpdater];
	[currentTourController release];
	currentTourController = nil;
}

#pragma mark -
#pragma mark UIApplicationDelegate

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
	// Disable idle timer
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
	
	// Check documents directory to see if bundles have been manually added
	[FileSharingManager checkBundles];
	
    // Allocate the sounds
	CFBundleRef mainBundle = CFBundleGetMainBundle();
	clickFileURLRef = CFBundleCopyResourceURL(mainBundle, CFSTR("click"), CFSTR("aif"), NULL);
    AudioServicesCreateSystemSoundID(clickFileURLRef, &clickFileObject);
	errorFileURLRef = CFBundleCopyResourceURL(mainBundle, CFSTR("error"), CFSTR("aif"), NULL);
    AudioServicesCreateSystemSoundID(errorFileURLRef, &errorFileObject);
	
	// Add the navigation controller to the window
	[window addSubview:[menuController view]];
	
	// Slide
	UIImageView *splash = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Default.png"]];
	[window addSubview:splash];
	[UIView animateWithDuration:0.75f animations:^{
		[splash setFrame:CGRectMake(0, -480.0f, splash.frame.size.width, splash.frame.size.height)];
	} completion:^(BOOL finished){
		[splash removeFromSuperview];
		[splash release];
	}];
	
	// Record the launch event
	[Analytics trackAction:NSLocalizedString(@"launch - en", @"App starting") forStop:@"tap"];
	
	// Start updates
	[self scheduleBackgroundUpdates];
	
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    
    NSUserDefaults * def = [NSUserDefaults standardUserDefaults];
    [def setObject:version forKey:@"version_display"];
    [def synchronize];

    
    [window makeKeyAndVisible];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	if ([[self backgroundUpdater] isUpdating]) {
		[backgroundUpdater cancel];
	}
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Check documents directory to see if bundles have been manually added
	[FileSharingManager checkBundles];
	[menuController refresh];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
	if ([[[notification userInfo] objectForKey:@"action"] isEqualToString:@"update"]) {
		if (![[self backgroundUpdater] isUpdating]) {
			alertView = [[UIAlertView alloc] initWithTitle:@"Updating..." message:@"The app is currently updating, please do not turn off." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
			[alertView setTag:kBackgroundUpdaterAlert];
			[alertView show];
			[alertView release];
			[backgroundUpdater update];
		}
	}
}

#pragma mark -
#pragma mark Background Updater

- (void)scheduleBackgroundUpdates
{	
	[[UIApplication sharedApplication] cancelAllLocalNotifications];
	
	// generate a unique number using the device's UDID 
	NSScanner *scanner = [NSScanner scannerWithString:[[[UIDevice currentDevice] uniqueIdentifier] substringToIndex:6]];
	unsigned int value;
	[scanner scanHexInt:&value];
	
	// create date for recurring update check
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit | NSWeekdayCalendarUnit;
	NSDate *date = [NSDate date];
	NSDateComponents *dateComponents = [[NSCalendar currentCalendar] components:unitFlags fromDate:date];
	[dateComponents setHour:22];
	[dateComponents setMinute:0];
	NSDate *fireDate = [[NSCalendar currentCalendar] dateFromComponents:dateComponents];
	fireDate = [fireDate dateByAddingTimeInterval:60 * 60 * 24 * ((int)(value % 7) - [dateComponents weekday] + 1)];
	fireDate = [fireDate dateByAddingTimeInterval:60 * UPDATE_INTERVAL * (value % UPDATE_GROUPS)];
	
	// schedule local notification
	UILocalNotification *localNotification = [[UILocalNotification alloc] init];
	[localNotification setFireDate:fireDate];
	[localNotification setRepeatInterval:NSWeekCalendarUnit];
	[localNotification setAlertBody:@"Perform automatic update for MFA Tours?"];
	[localNotification setAlertAction:@"Update"];
	[localNotification setUserInfo:[NSDictionary dictionaryWithObject:@"update" forKey:@"action"]];
	[[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
	[localNotification release];
}

#pragma mark -
#pragma mark BackgroundUpdaterDelegate Methods

- (void)backgroundUpdaterDidFinishUpdating:(BackgroundUpdater *)backgroundUpdater
{
	[menuController refresh];
	[alertView dismissWithClickedButtonIndex:1 animated:YES];
}

- (void)backgroundUpdater:(BackgroundUpdater *)backgroundUpdater didFailWithError:(NSError *)error
{
	
}

#pragma mark -
#pragma mark UIAlertViewDelegate Methods

- (void)alertView:(UIAlertView *)theAlertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if ([theAlertView tag] == kBackgroundUpdaterAlert) {
		if (buttonIndex == 0) {
			[backgroundUpdater cancel];
		}
	}
}

@end
