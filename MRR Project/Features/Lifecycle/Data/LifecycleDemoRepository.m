#import "LifecycleDemoRepository.h"
#import "../../../Core/Domain/Models/MRRDemoCategory.h"
#import "../../../Core/Domain/Models/MRRDemoDetail.h"
#import "../../../Core/Domain/Models/MRRDemoSection.h"
#import "../../../Core/Domain/Models/MRRDemoSummary.h"

@interface LifecycleDemoRepository ()

@property (nonatomic, retain) NSArray<MRRDemoCategory *> *categories;
@property (nonatomic, retain) NSDictionary<NSString *, NSArray<MRRDemoSummary *> *> *summariesByCategoryIdentifier;
@property (nonatomic, retain) NSDictionary<NSString *, MRRDemoDetail *> *detailsByIdentifier;

@end

@implementation LifecycleDemoRepository

- (instancetype)init {
    self = [super init];
    if (self) {
        self.categories = [self buildCategories];
        self.summariesByCategoryIdentifier = [self buildSummaries];
        self.detailsByIdentifier = [self buildDetails];
    }

    return self;
}

- (void)dealloc {
    [_categories release];
    [_summariesByCategoryIdentifier release];
    [_detailsByIdentifier release];
    [super dealloc];
}

- (NSArray<MRRDemoCategory *> *)fetchCategories {
    return _categories;
}

- (NSArray<MRRDemoSummary *> *)fetchDemoSummariesForCategoryIdentifier:(NSString *)categoryIdentifier {
    NSArray<MRRDemoSummary *> *summaries = [_summariesByCategoryIdentifier objectForKey:categoryIdentifier];
    return summaries != nil ? summaries : [NSArray array];
}

- (MRRDemoDetail *)fetchDemoDetailForIdentifier:(NSString *)demoIdentifier {
    return [_detailsByIdentifier objectForKey:demoIdentifier];
}

- (NSArray<MRRDemoCategory *> *)buildCategories {
    MRRDemoCategory *lifecycle = [[[MRRDemoCategory alloc] initWithIdentifier:MRRDemoCategoryIdentifierLifecycle
                                                                        title:@"Lifecycle"
                                                                  summaryText:@"dealloc sequencing, observer cleanup, and timer invalidation."] autorelease];
    return [NSArray arrayWithObject:lifecycle];
}

- (NSDictionary<NSString *, NSArray<MRRDemoSummary *> *> *)buildSummaries {
    NSArray<MRRDemoSummary *> *lifecycle = [NSArray arrayWithObjects:
                                            [[[MRRDemoSummary alloc] initWithDemoIdentifier:@"lifecycle.dealloc-order"
                                                                                     title:@"dealloc Order"
                                                                               summaryText:@"Release retained ivars first and call [super dealloc] last."] autorelease],
                                            [[[MRRDemoSummary alloc] initWithDemoIdentifier:@"lifecycle.observer-cleanup"
                                                                                     title:@"Observer Cleanup"
                                                                               summaryText:@"Remove observers before objects disappear to avoid dangling callbacks."] autorelease],
                                            [[[MRRDemoSummary alloc] initWithDemoIdentifier:@"lifecycle.timer-cleanup"
                                                                                     title:@"Timer Cleanup"
                                                                               summaryText:@"Invalidate timers before teardown so they stop messaging released targets."] autorelease],
                                            nil];

    return [NSDictionary dictionaryWithObject:lifecycle forKey:MRRDemoCategoryIdentifierLifecycle];
}

- (NSDictionary<NSString *, MRRDemoDetail *> *)buildDetails {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [self detailForDeallocOrder], @"lifecycle.dealloc-order",
            [self detailForObserverCleanup], @"lifecycle.observer-cleanup",
            [self detailForTimerCleanup], @"lifecycle.timer-cleanup",
            nil];
}

- (MRRDemoDetail *)detailWithIdentifier:(NSString *)identifier
                                  title:(NSString *)title
                               subtitle:(NSString *)subtitle
                               sections:(NSArray<MRRDemoSection *> *)sections {
    return [[[MRRDemoDetail alloc] initWithDemoIdentifier:identifier
                                                    title:title
                                             subtitleText:subtitle
                                                 sections:sections] autorelease];
}

- (MRRDemoSection *)sectionWithTitle:(NSString *)title
                            bodyText:(NSString *)bodyText
                      checklistItems:(NSArray<NSString *> *)checklistItems {
    return [[[MRRDemoSection alloc] initWithTitle:title bodyText:bodyText checklistItems:checklistItems] autorelease];
}

- (MRRDemoDetail *)detailForDeallocOrder {
    NSArray *sections = [NSArray arrayWithObjects:
                         [self sectionWithTitle:@"Rule"
                                       bodyText:@"Release retained ivars first, then call [super dealloc] last. There is no cleanup opportunity after super dealloc runs."
                                 checklistItems:[NSArray arrayWithObjects:@"Release every retained or copied ivar.", @"Do not send messages to self after [super dealloc].", @"Avoid setting ivars to nil unless it clarifies a live teardown path.", nil]],
                         [self sectionWithTitle:@"Review Prompt"
                                       bodyText:@"A clean dealloc method is short, explicit, and mirrors the ownership in the class interface."
                                 checklistItems:[NSArray arrayWithObjects:@"Compare retained properties to dealloc releases.", @"Check for superclass call ordering.", nil]],
                         nil];
    return [self detailWithIdentifier:@"lifecycle.dealloc-order"
                                title:@"dealloc Order"
                             subtitle:@"dealloc is the final ownership checkpoint in an MRR object."
                             sections:sections];
}

- (MRRDemoDetail *)detailForObserverCleanup {
    NSArray *sections = [NSArray arrayWithObjects:
                         [self sectionWithTitle:@"Rule"
                                       bodyText:@"Observers must be removed before an observed object or observer disappears, otherwise callbacks can target released memory."
                                 checklistItems:[NSArray arrayWithObjects:@"Unregister in dealloc or an earlier stop method.", @"Mirror every addObserver with a removeObserver.", @"Keep observer registration close to cleanup logic.", nil]],
                         [self sectionWithTitle:@"Review Prompt"
                                       bodyText:@"Notification and KVO cleanup often fail when registration is hidden in one method and teardown is forgotten elsewhere."
                                 checklistItems:[NSArray arrayWithObjects:@"Search for addObserver calls and match them.", @"Verify teardown runs on every lifecycle path.", nil]],
                         nil];
    return [self detailWithIdentifier:@"lifecycle.observer-cleanup"
                                title:@"Observer Cleanup"
                             subtitle:@"Temporary observation requires symmetrical cleanup."
                             sections:sections];
}

- (MRRDemoDetail *)detailForTimerCleanup {
    NSArray *sections = [NSArray arrayWithObjects:
                         [self sectionWithTitle:@"Rule"
                                       bodyText:@"NSTimer retains its target through the run loop. Invalidate the timer before the target is released."
                                 checklistItems:[NSArray arrayWithObjects:@"Invalidate timers in stop/dealloc paths.", @"Nil out timer ivars after invalidation when the object remains alive.", @"Avoid timers that outlive the owning controller or service.", nil]],
                         [self sectionWithTitle:@"Review Prompt"
                                       bodyText:@"Run-loop driven objects are easy to forget because no direct owner is visible at the call site."
                                 checklistItems:[NSArray arrayWithObjects:@"Check repeating timers first.", @"Check whether teardown runs before view controller disappearance.", nil]],
                         nil];
    return [self detailWithIdentifier:@"lifecycle.timer-cleanup"
                                title:@"Timer Cleanup"
                             subtitle:@"Time-based callbacks can outlive their UI unless invalidated explicitly."
                             sections:sections];
}

@end
