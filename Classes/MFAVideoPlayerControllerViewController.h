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

@interface MFAVideoPlayerControllerViewController : UIViewController

@property (nonatomic, retain) NSURL * fileUrl;

@property (nonatomic, retain) AVPlayer *player;
@property (nonatomic, retain) AVPlayerItem *playerItem;
//@property (nonatomic, weak) IBOutlet MFAVideoPlayerUIView *playerView;
//@property (nonatomic, weak) IBOutlet UIButton *playButton;
@property (nonatomic, retain) IBOutlet MFAVideoPlayerUIView *playerView;
@property (nonatomic, retain) IBOutlet UIButton *playButton;
- (IBAction)loadAssetFromFile:sender;
- (IBAction)play:sender;
- (void)syncUI;
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context;

@end
