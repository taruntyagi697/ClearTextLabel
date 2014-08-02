//
//  CTLDViewController.m
//  CTLabelDemo
//
//  Created by Tarun Tyagi on 08/07/14.
//  Copyright (c) 2014 Tarun Tyagi. All rights reserved.
//

#import "CTLDViewController.h"

@interface CTLDViewController ()

@end

@implementation CTLDViewController

-(void)viewDidLoad
{
    [super viewDidLoad];
	
    ClearTextLabel* objCTLbl = [[ClearTextLabel alloc] initWithFrame:CGRectMake(20, 100, 280, 368)];
    objCTLbl.text = @"Hey ! Did you notice that text is see through, how is that ? That must be ClearTextLabel  :)";
    objCTLbl.font = [UIFont fontWithName:@"Arial Rounded MT Bold" size:37.0f];
    objCTLbl.textAlignment = NSTextAlignmentCenter;
    objCTLbl.numberOfLines = 0;
    objCTLbl.layer.cornerRadius = 10.0f;
    [self.view addSubview:objCTLbl];
}

-(void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
