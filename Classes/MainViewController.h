//
//  MainViewController.h
//  RogueHTTP
//
//  Created by Courtney Holmes on 7/6/11.
//  Copyright 2011 Unemployed. All rights reserved.
//

#import "FlipsideViewController.h"

@interface MainViewController : UIViewController <FlipsideViewControllerDelegate> {
	long hitCounter;
}

- (IBAction)showInfo:(id)sender;
- (IBAction)goToSite:(id)sender;

@end
