//
//  main.m
//  MRR Project
//
//  Created for MRR Learning
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char *argv[]) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int retVal = UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));

  [pool release];
  return retVal;
}
