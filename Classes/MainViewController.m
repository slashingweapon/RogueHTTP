//
//  MainViewController.m
//  RogueHTTP
//
//  Created by Courtney Holmes on 7/6/11.
//  Copyright 2011 Unemployed. All rights reserved.
//

#import "MainViewController.h"
#import "RogueHTTPAppDelegate.h"
#import "SocketServer.h"

@implementation MainViewController


- (void)dealloc {
    [super dealloc];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	hitCounter = -1;

	UILabel *portLabel = (UILabel*) [self.view viewWithTag:101];
	if ([portLabel isKindOfClass:[UILabel class]]) {
		SocketServer *server = [SocketServer singleton];
		long port = [server.port longValue];
		portLabel.text = [NSString stringWithFormat:@"Port: %ld", port];
	}
	
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[SocketServer singleton] addObserver:self
							   forKeyPath:@"port"
								  options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial 
								  context:nil];
	[[SocketServer singleton] addObserver:self
							   forKeyPath:@"hits"
								  options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial 
								  context:nil];
	
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[SocketServer singleton] removeObserver:self forKeyPath:@"port"];
	[[SocketServer singleton] removeObserver:self forKeyPath:@"hits"];
	
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	NSNumber *newValue = [change valueForKey:NSKeyValueChangeNewKey];
	UILabel *label = nil;
	NSString *format;
	
	if ([keyPath isEqualToString:@"hits"]) {
		label = (UILabel*)[self.view viewWithTag:100];
		format = @"Hits: %ld";
	} else if ([keyPath isEqualToString:@"port"]) {
		label = (UILabel*)[self.view viewWithTag:101];
		format = @"Port: %ld";
	}
	
	if ([newValue isKindOfClass:[NSNumber class]] && [label isKindOfClass:[UILabel class]]) {
		label.text = [NSString stringWithFormat:format, [newValue longValue]];
	}
}

- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller {
    
	[self dismissModalViewControllerAnimated:YES];
}


- (IBAction)showInfo:(id)sender {    
	
	FlipsideViewController *controller = [[FlipsideViewController alloc] initWithNibName:@"FlipsideView" bundle:nil];
	controller.delegate = self;
	
	controller.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
	[self presentModalViewController:controller animated:YES];
	
	[controller release];
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc. that aren't in use.
}


- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations.
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (IBAction)goToSite:(id)sender {
	SocketServer *server = [SocketServer singleton];
	
	NSString *urlString = [NSString stringWithFormat:@"http://localhost:%d/",
						   [server.port integerValue]];
	NSURL *url = [NSURL URLWithString:urlString];
	
	[[UIApplication sharedApplication] openURL:url];
}

@end
