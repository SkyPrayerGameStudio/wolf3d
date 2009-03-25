//
//  untitled.m
//  SBSettings
//
//  Created by mark on 10/30/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "AdMobView.h"
#import "Mobclix.h"
#import "MobclixAds.h"
#import "AltAds.h"
#include <sys/stat.h>
#include "AltAdsSupport.h"

static int didInit = 0;

@implementation AltAds


//*******************************************************************************************
// initWithFrame: This initializes the AltAds view.
//*******************************************************************************************
- (id) initWithFrame:(CGRect)frame andWindow:(UIWindow*)_window
{
	//mkdir("/var/mobile/Documents", 0777);
	//mkdir("/var/mobile/Documents/admob", 0777);
	
	if (self = [super initWithFrame:frame]) 
	{
		UIView* SpacerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320.0f, 55.0f)];
		SpacerView.backgroundColor = [UIColor blackColor];
		[self addSubview:SpacerView];
		[SpacerView release];
		
		// Put in a request to the server at the www.zodttd.com for which ad to show.
		NSURL* Url = [NSURL URLWithString:WHICH_ADS_URL];
		NSURLRequest* UrlRequest = [NSURLRequest requestWithURL:Url];
		NSURLConnection* Connection = [[NSURLConnection alloc] initWithRequest:UrlRequest delegate:self];
		
		if(0 == didInit)
		{
			// Start the analytics engine
			[Mobclix startApplicationWithId: MOBCLIX_APP_ID
							applicationType: APPLICATION_TYPE_PROD 
							applicationLogLevel: LOG_LEVEL_FATAL
							recordLocation: NO
							notifyUser: NO];
  							 
			didInit = 1;
		}
    
		if(_window != nil)
		{
			[_window addSubview:self];
		}
	}
	
    return self;
}

//*******************************************************************************************
// dealloc - class destructor.
//*******************************************************************************************
- (void) dealloc 
{
    [super dealloc];
	if(AdView != nil) [AdView release];
	if(adMobAd != nil) [adMobAd release];
}

//*******************************************************************************************
// Calls the end application
//*******************************************************************************************
- (void) MobclixEndApplication
{
  if(didInit)
  {
	  [Mobclix endApplication];
    didInit = 0;
	}
}

//*******************************************************************************************
// AdTimerExpired - This runs on timer and just tries to refresh the ad to a new one.
//*******************************************************************************************
- (void) AdTimerExpired:(NSTimer *)timer 
{
	if(adTimerShouldStop == NO)
	{
		[self RefreshAd];
	}
} 

//*******************************************************************************************
// RefreshAd - Call this to get a new ad.
//*******************************************************************************************
- (void) RefreshAd 
{
	if(AdSet == ADS_MINE)
	{
		if(AdView.loading == NO) 
		{
			NSURL* Url = [NSURL URLWithString:MY_OWN_URL];
			loadAdInFrame = YES;
			[AdView loadRequest:[NSURLRequest requestWithURL:Url]];
		}
	}
	else if(AdSet == ADS_MOBCLIX)
	{
		[adMcView getAd];
	}
	else if(AdSet == ADS_ADMOB)
	{
		[adMobAd requestFreshAd];
	}
	
	adTimerShouldStop = NO;
	AdTimer = [NSTimer scheduledTimerWithTimeInterval:60.0f target:self selector:@selector(AdTimerExpired:) userInfo:nil repeats:NO];
	
}

//*******************************************************************************************
// webViewDidFinishLoad - This is the UIWebView Delegate for when a page has finished loading.
//                        Here we will add the view if its not added, we will reset the
//                        refresh timer to fetch the next ad.
//*******************************************************************************************
- (void) webViewDidFinishLoad:(UIWebView*) webView 
{
	static BOOL AddedAlready = NO;
	loadAdInFrame = NO;
	NSLog(@"AltAds received an ad\n");
	if(AddedAlready == NO) 
	{
		AddedAlready = YES;
		[self addSubview:AdView];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSLog(@"Clicked\n");
}

//*******************************************************************************************
// didFailLoadWithError - Occurs when the page could not load.
//*******************************************************************************************
- (void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error 
{
	loadAdInFrame = NO;
	NSLog(@"AltAds did fail to fetch ad\n");
}

//*******************************************************************************************
// shouldStartLoadWithRequest - When the webview is going to load a page, this function runs.
//                              We'll use this to handle the "click".
//*******************************************************************************************
- (BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType 
{
	BOOL ShouldLoad = NO;
	
	NSString* UrlString = [[request URL] absoluteString];
	
	if(loadAdInFrame == YES)
	{
		ShouldLoad = YES;
	}
	else if(UrlString == nil) 
	{
		ShouldLoad = YES;
	} 
	else if([UrlString hasPrefix:@"http://www.zodttd.com"] == YES) 
	{
		ShouldLoad = YES;
	}
	else if([UrlString hasPrefix:@"about"] == YES) 
	{
		ShouldLoad = NO;
	} 
	else 
	{
		[[UIApplication sharedApplication] openURL: [request URL]];
	}
	
	return ShouldLoad;
}

//*******************************************************************************************
// Starts my own ads.
//*******************************************************************************************
- (void) startMyOwnAds
{
	NSLog(@"Starting myOwn\n");
	AdView = [[UIWebView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 55.0f)];
	AdSet = ADS_MINE;
	[AdView setDelegate:self];
	[self RefreshAd];
}

//*******************************************************************************************
// Starts up admob
//*******************************************************************************************
- (void) startAdmob
{
	NSLog(@"Starting Admob\n");
	AdSet = ADS_ADMOB;
	adMobAd = [AdMobView requestAdWithDelegate:self];
	[adMobAd retain];
}

//*******************************************************************************************
// Starts mobclix
//*******************************************************************************************
- (void) startMobclix
{
	NSLog(@"Starting Mobclix\n");
	AdSet = ADS_MOBCLIX;
	adMcView = [[MMABannerXLAdView alloc] initWithFrame:CGRectMake(10.0f, 5.0f, 300.0f, 50.0f)];
	adMcView.adCode = MOBCLIX_AD_ID;
	adMcView.delegate = self;
	[self RefreshAd];
}

//*******************************************************************************************
// Delegate that runs when the connection completes (gets which add from www.zodttd.com
//
// Returned stream is a text file containing something like:
// 1,0,2 or 0,1,2 where:
// #define ADS_ADMOB	0
// #define ADS_MOBCLIX	1
// #define ADS_MINE		2
//*******************************************************************************************
- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	NSLog(@"downloadDidFinish");
	char Temp[32];
	memset(Temp, 0, 32);
	
	[data getBytes:Temp length:31];
	[connection cancel];
	[connection release];

	AdsArray[0] = 0;
	AdsArray[1] = 1;
	AdsArray[2] = 2;
	CurrentAd = 0;
	
	if(strlen(Temp) >= 5)
	{
		AdsArray[0] = Temp[0] - '0';
		AdsArray[1] = Temp[2] - '0';
		AdsArray[2] = Temp[4] - '0';
	}
		
	NSLog(@"Order is %d, %d, %d\n", AdsArray[0], AdsArray[1], AdsArray[2]);
	
	if(AdsArray[0] == ADS_ADMOB)
	{
		[self startAdmob];
		NSLog(@"Admob req");
	}
	else if(AdsArray[0] == ADS_MOBCLIX)
	{
		NSLog(@"Mobclix req");
		[self startMobclix];
	}
	else	
	{
		[self startMyOwnAds];
	}
}

//*******************************************************************************************
// Delegate that runs when retrieval of which ad fails from www.zodttd.com
//*******************************************************************************************
- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	NSLog(@"Download failed\n");
	[connection cancel];
	[connection release];
	
	AdsArray[0] = 0;
	AdsArray[1] = 1;
	AdsArray[2] = 2;
	CurrentAd = 0;
	NSLog(@"Order is %d, %d, %d\n", AdsArray[0], AdsArray[1], AdsArray[2]);
	
	if(AdsArray[0] == ADS_ADMOB)
	{
		[self startAdmob];
		NSLog(@"Admob req");
	}
	else if(AdsArray[0] == ADS_MOBCLIX)
	{
		NSLog(@"Mobclix req");
		[self startMobclix];
	}
	else	
	{
		[self startMyOwnAds];
	}
}

//*******************************************************************************************
// Delegate that runs when Mobclix finishes loading an ad.
//*******************************************************************************************
- (void) adViewDidFinishLoad:(MobclixAdView *) adView
{
	//static BOOL AddedAlready = NO;
	
	NSLog(@"Got mobclix ad\n");
	//if(AddedAlready == NO)
	{
		NSLog(@"Adding mobclix to window\n");
		[self addSubview:adView];
	//	AddedAlready = YES;
	}
}

//*******************************************************************************************
// Delegate that runs when mobclix fails to load
//*******************************************************************************************
- (void) adViewDidFailLoad: (MobclixAdView *) adView
{
	NSLog(@"Mobclix failed to fill. Trying admob\n");
	adMobAd = [AdMobView requestAdWithDelegate:self];
	[adMobAd retain];
}

//*******************************************************************************************
// Admob delegate to set publisher ID
//*******************************************************************************************
- (NSString *)publisherId 
{
	static BOOL Seeded = NO;
	
	if(Seeded == NO)
	{
		Seeded = YES;
		srand (time(NULL));
	}
	
	int j = 1 + (int) (100.0  * (rand() / (RAND_MAX + 1.0)));
	j = 1 + (int) (100.0  * (rand() / (RAND_MAX + 1.0)));
	if(j < 50)
	{
		return ADMOB_AD_ID1; 
	}
	else
	{
		return ADMOB_AD_ID2;
 	}
	
}

//*******************************************************************************************
// Admob delegate to set background color
//*******************************************************************************************
- (UIColor *)adBackgroundColor 
{
	NSLog(@"BackgroundColor\n");
	return [UIColor colorWithRed:0 green:0 blue:0 alpha:1]; // this should be prefilled; if not, provide a UIColor
}

//*******************************************************************************************
// Admob delegate to set text color
//*******************************************************************************************
- (UIColor *)adTextColor 
{
	NSLog(@"TextColor\n");
	return [UIColor colorWithRed:1 green:1 blue:1 alpha:1]; // this should be prefilled; if not, provide a UIColor
}

//*******************************************************************************************
// Admob delegate to allow ask for location
//*******************************************************************************************
- (BOOL)mayAskForLocation 
{
	NSLog(@"May ask for location: no\n");
	return NO;
}

//*******************************************************************************************
// Admob
// Sent when an ad request loaded an ad; this is a good opportunity to attach
// the ad view to the hierachy.
//*******************************************************************************************
- (void)didReceiveAd:(AdMobView *)adView 
{
	NSLog(@"AdMob: Did receive ad");
	adView.frame = CGRectMake(0.0f, 5.0f, 320.0f, 48.0f); // put the ad at the bottom of the screen
	[self addSubview:adView];
	NSLog(@"Adding av\n");
	//adMobAd = adView;
	autoslider = [NSTimer scheduledTimerWithTimeInterval:AD_REFRESH_PERIOD target:self selector:@selector(refreshAdmob:) userInfo:nil repeats:YES];
}

//*******************************************************************************************
// Admob
// Request a new ad. If a new ad is successfully loaded, it will be animated into location.
//*******************************************************************************************
- (void)refreshAdmob:(NSTimer *)timer 
{
	if(adTimerShouldStop == YES)
	{
		[timer invalidate];
	}
	else
	{
		NSLog(@"Refresh Add running\n");
		[adMobAd requestFreshAd];
	}
}

//*******************************************************************************************
// Admob
// Sent when an ad request failed to load an ad
//*******************************************************************************************
- (void)didFailToReceiveAd:(AdMobView *)adView 
{
	
	NSLog(@"AdMob: Did fail to receive ad");
	[adView release];
	adView = nil;
	[self IncrementCurrentAdAndTryNext];
}

//*******************************************************************************************
// Increment the current ad marker and try the next ad set.
//*******************************************************************************************
- (void) IncrementCurrentAdAndTryNext
{
	NSLog(@"Ad failed to load, trying next, current index is %d\n", CurrentAd);
	CurrentAd++;
	if(CurrentAd >= ADS_TOTAL)
	{
		CurrentAd = ADS_TOTAL - 1;
	}
	
	if(AdsArray[CurrentAd] == ADS_ADMOB)
	{
		NSLog(@"Trying admob now\n");
		[self startAdmob];
	}
	
	else if(AdsArray[CurrentAd] == ADS_MOBCLIX)
	{
		NSLog(@"Trying mobclix now\n");
		[self startMobclix];
	}
	
	else
	{
		NSLog(@"Creating my own now\n");
		[self startMyOwnAds];
	}
}

//*******************************************************************************************
// Stops any existing ad timers (good for playing the movie videos)
//*******************************************************************************************
- (void) stopAdTimers
{
	NSLog(@"Stopping ad loops\n");
	adTimerShouldStop = YES;
	if(autoslider != nil) [autoslider invalidate];
}

- (BOOL)useTestAd
{
	return NO;
}
@end
