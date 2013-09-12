//
//  UpdaterDataProvider.m
//  Test
//
//  Created by Robert Brecher on 9/16/10.
//  Copyright 2010 Genuine Interactive. All rights reserved.
//

#import "UpdaterDataProvider.h"
#import "ToursXMLParser.h"

#define kMfaGuideAllToursFileName @"all-tours"


enum {
	kLatestRequest = 1,
	kTourMLRequest = 2
};

@implementation UpdaterDataProvider

@synthesize delegate;

- (id)initWithDelegate:(id<UpdaterDataProviderDelegate>)theDelegate
{
	if ((self = [self init])) {
		self.delegate = theDelegate;
	}
	return self;
}

- (void)dealloc
{
	[delegate release];
	[urlConnection release];
	[webData release];
	[super dealloc];
}


+ (NSString *)getUpdaterAllToursUrl {
    return [NSString stringWithFormat:@"%@/%@", [self getUpdaterHostname], kMfaGuideAllToursFileName];
}

+ (NSString *)getUpdaterHostname {
    // return UPDATER_HOST;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults synchronize]; // pick up any changes
    NSString * hostname = [defaults stringForKey:@"hostname"];
    NSLog(@"Found Hostname: %@", hostname);
    return hostname;
    
}


#pragma mark -
#pragma mark Requests

- (void)getLatest
{
//    NSLog(@"UpdaterDataProvier#getLatest: %@", UPDATER_URL);
    NSString * updaterUrl = [UpdaterDataProvider getUpdaterAllToursUrl];
    NSLog(@"UpdaterDataProvider#getLatest: %@", updaterUrl);
	NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:updaterUrl]];
	urlConnection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self];
	if (urlConnection) {
		currentRequest = kLatestRequest;
		webData = [[NSMutableData alloc] init];
	}
	[urlRequest release];
}

- (void)getTourML:(NSURL *)tourMLUrl
{
    NSLog(@"UpdaterDataProvider#getTourML");
	NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:tourMLUrl];
	urlConnection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self];
	if (urlConnection) {
		currentRequest = kTourMLRequest;
		webData = [[NSMutableData alloc] init];
	}
	[urlRequest release];
}

- (void)cancel
{
	if (urlConnection) {
		[urlConnection cancel];
		[urlConnection release];
		urlConnection = nil;
	}
}

#pragma mark -
#pragma mark NSURLConnection Delegate Methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[webData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[webData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if ([delegate respondsToSelector:@selector(dataProvider:didFailWithError:)]) {
		[delegate dataProvider:self didFailWithError:error];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{	
	if (currentRequest == kLatestRequest) {
		NSArray *tours = [ToursXMLParser parseToursXML:webData];
		if ([delegate respondsToSelector:@selector(dataProvider:didRetrieveTours:)]) {
			[delegate dataProvider:self didRetrieveTours:tours];
		}
	}
	else if (currentRequest == kTourMLRequest) {
		xmlDocPtr tourDoc = xmlParseMemory([webData bytes], [webData length]);
		if (!tourDoc) {
			NSLog(@"Could not create xmlDocPtr from XML data");
			if ([delegate respondsToSelector:@selector(dataProvider:didFailWithError:)]) {
				[delegate dataProvider:self didFailWithError:nil];
			}
		}
		else {
			if ([delegate respondsToSelector:@selector(dataProvider:didRetrieveTourML:)]) {
				[delegate dataProvider:self didRetrieveTourML:tourDoc];
			}
			xmlFreeDoc(tourDoc);
		}
	}
	[webData release];
	webData = nil;
	[urlConnection release];
	urlConnection = nil;
}

@end
