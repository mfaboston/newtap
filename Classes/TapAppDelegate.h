//
//  Created by Charles Moad <cmoad@imamuseum.org>.
//  Copyright Indianapolis Museum of Art 2009.
//  See LICENCE file included with source.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

#import "BackgroundUpdater.h"
#import "TourMLUtils.h"
#import "Analytics.h"
#import "MenuController.h"
#import "TourController.h"

#import "MFAVideoPlayerControllerViewController.h"

#define UPDATE_INTERVAL 5
#define UPDATE_GROUPS 120

@interface TapAppDelegate : NSObject <BackgroundUpdaterDelegate, UIApplicationDelegate, UIAlertViewDelegate>
{
	IBOutlet UIWindow *window;
	IBOutlet MenuController *menuController;
	
	BackgroundUpdater *backgroundUpdater;
	
	TourController *currentTourController;
	
	UIAlertView *alertView;
	
	CFURLRef clickFileURLRef;
    SystemSoundID clickFileObject;
	CFURLRef errorFileURLRef;
    SystemSoundID errorFileObject;
    
    MFAVideoPlayerControllerViewController * singleMainMfaVidController;
}

@property (nonatomic, retain) MFAVideoPlayerControllerViewController * singleMainMfaVidController;
@property (nonatomic, retain) IBOutlet MenuController *menuController;

@property (nonatomic, retain) BackgroundUpdater *backgroundUpdater;

@property (nonatomic, retain) TourController *currentTourController;

@property (readwrite) CFURLRef clickFileURLRef;
@property (readonly) SystemSoundID clickFileObject;
@property (readwrite) CFURLRef errorFileURLRef;
@property (readonly) SystemSoundID errorFileObject;

- (MFAVideoPlayerControllerViewController *) getSingleMainMfaVidController;
- (void)playClick;
- (void)playError;

- (BOOL)loadTourWithBundleName:(NSString *)bundleName;
- (void)closeTourAndShowUpdater;

- (void) setCCInDefaults:(BOOL)cc;
- (BOOL) ccFromDefaults;


@end
