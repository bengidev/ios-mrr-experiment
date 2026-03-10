//
//  AppDelegate.m
//  MRR Project
//
//  Created for MRR Learning
//

#import "AppDelegate.h"
#include <UIKit/UIKit.h>
#import "../Features/Basics/Data/BasicsDemoRepository.h"
#import "../Features/Basics/Domain/UseCases/BasicsLoadDemoDetailUseCase.h"
#import "../Features/Basics/Domain/UseCases/BasicsLoadDemoListUseCase.h"
#import "../Features/Basics/Presentation/Factories/BasicsScreenFactory.h"
#import "../Features/Basics/Presentation/ViewControllers/BasicsListViewController.h"
#import "../Features/Lifecycle/Data/LifecycleDemoRepository.h"
#import "../Features/Lifecycle/Domain/UseCases/LifecycleLoadDemoDetailUseCase.h"
#import "../Features/Lifecycle/Domain/UseCases/LifecycleLoadDemoListUseCase.h"
#import "../Features/Lifecycle/Presentation/Factories/LifecycleScreenFactory.h"
#import "../Features/Lifecycle/Presentation/ViewControllers/LifecycleListViewController.h"
#import "../Features/Relationships/Data/RelationshipsDemoRepository.h"
#import "../Features/Relationships/Domain/UseCases/RelationshipsLoadDemoDetailUseCase.h"
#import "../Features/Relationships/Domain/UseCases/RelationshipsLoadDemoListUseCase.h"
#import "../Features/Relationships/Presentation/Factories/RelationshipsScreenFactory.h"
#import "../Features/Relationships/Presentation/ViewControllers/RelationshipsListViewController.h"

@implementation AppDelegate

#pragma mark - Memory Management

- (void)dealloc {
    [_window release];
    [super dealloc];
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    self.window.rootViewController = [self buildLearningExperienceTabBarControllerSelectingIndex:0];
    [self.window makeKeyAndVisible];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, etc.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate
}

- (UITabBarController *)buildLearningExperienceTabBarControllerSelectingIndex:(NSUInteger)selectedIndex {
    BasicsDemoRepository *basicsRepository = [[[BasicsDemoRepository alloc] init] autorelease];
    BasicsLoadDemoListUseCase *basicsListUseCase = [[[BasicsLoadDemoListUseCase alloc] initWithRepository:basicsRepository] autorelease];
    BasicsLoadDemoDetailUseCase *basicsDetailUseCase = [[[BasicsLoadDemoDetailUseCase alloc] initWithRepository:basicsRepository] autorelease];
    BasicsScreenFactory *basicsScreenFactory = [[[BasicsScreenFactory alloc] initWithDetailUseCase:basicsDetailUseCase] autorelease];

    RelationshipsDemoRepository *relationshipsRepository = [[[RelationshipsDemoRepository alloc] init] autorelease];
    RelationshipsLoadDemoListUseCase *relationshipsListUseCase = [[[RelationshipsLoadDemoListUseCase alloc] initWithRepository:relationshipsRepository] autorelease];
    RelationshipsLoadDemoDetailUseCase *relationshipsDetailUseCase = [[[RelationshipsLoadDemoDetailUseCase alloc] initWithRepository:relationshipsRepository] autorelease];
    RelationshipsScreenFactory *relationshipsScreenFactory = [[[RelationshipsScreenFactory alloc] initWithDetailUseCase:relationshipsDetailUseCase] autorelease];

    LifecycleDemoRepository *lifecycleRepository = [[[LifecycleDemoRepository alloc] init] autorelease];
    LifecycleLoadDemoListUseCase *lifecycleListUseCase = [[[LifecycleLoadDemoListUseCase alloc] initWithRepository:lifecycleRepository] autorelease];
    LifecycleLoadDemoDetailUseCase *lifecycleDetailUseCase = [[[LifecycleLoadDemoDetailUseCase alloc] initWithRepository:lifecycleRepository] autorelease];
    LifecycleScreenFactory *lifecycleScreenFactory = [[[LifecycleScreenFactory alloc] initWithDetailUseCase:lifecycleDetailUseCase] autorelease];

    BasicsListViewController *basicsController = [[[BasicsListViewController alloc] initWithListUseCase:basicsListUseCase
                                                                                            screenFactory:basicsScreenFactory] autorelease];
    RelationshipsListViewController *relationshipsController = [[[RelationshipsListViewController alloc] initWithListUseCase:relationshipsListUseCase
                                                                                                                 screenFactory:relationshipsScreenFactory] autorelease];
    LifecycleListViewController *lifecycleController = [[[LifecycleListViewController alloc] initWithListUseCase:lifecycleListUseCase
                                                                                                      screenFactory:lifecycleScreenFactory] autorelease];

    UINavigationController *basicsNavigationController = [[[UINavigationController alloc] initWithRootViewController:basicsController] autorelease];
    UINavigationController *relationshipsNavigationController = [[[UINavigationController alloc] initWithRootViewController:relationshipsController] autorelease];
    UINavigationController *lifecycleNavigationController = [[[UINavigationController alloc] initWithRootViewController:lifecycleController] autorelease];

    basicsNavigationController.tabBarItem = [[[UITabBarItem alloc] initWithTitle:@"Basics" image:nil selectedImage:nil] autorelease];
    relationshipsNavigationController.tabBarItem = [[[UITabBarItem alloc] initWithTitle:@"Relationships" image:nil selectedImage:nil] autorelease];
    lifecycleNavigationController.tabBarItem = [[[UITabBarItem alloc] initWithTitle:@"Lifecycle" image:nil selectedImage:nil] autorelease];

    UITabBarController *tabBarController = [[[UITabBarController alloc] init] autorelease];
    tabBarController.viewControllers = [NSArray arrayWithObjects:
                                        basicsNavigationController,
                                        relationshipsNavigationController,
                                        lifecycleNavigationController,
                                        nil];

    if (selectedIndex < tabBarController.viewControllers.count) {
        tabBarController.selectedIndex = selectedIndex;
    }

    return tabBarController;
}

@end
