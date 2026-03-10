#import "BasicsDemoRepository.h"
#import "../../../Core/Domain/Models/MRRDemoCategory.h"
#import "../../../Core/Domain/Models/MRRDemoDetail.h"
#import "../../../Core/Domain/Models/MRRDemoSection.h"
#import "../../../Core/Domain/Models/MRRDemoSummary.h"

@interface BasicsDemoRepository ()

@property (nonatomic, retain) NSArray<MRRDemoCategory *> *categories;
@property (nonatomic, retain) NSDictionary<NSString *, NSArray<MRRDemoSummary *> *> *summariesByCategoryIdentifier;
@property (nonatomic, retain) NSDictionary<NSString *, MRRDemoDetail *> *detailsByIdentifier;

@end

@implementation BasicsDemoRepository

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
    MRRDemoCategory *basics = [[[MRRDemoCategory alloc] initWithIdentifier:MRRDemoCategoryIdentifierBasics
                                                                     title:@"Basics"
                                                               summaryText:@"Ownership rules, retain/release balance, and property semantics."] autorelease];
    return [NSArray arrayWithObject:basics];
}

- (NSDictionary<NSString *, NSArray<MRRDemoSummary *> *> *)buildSummaries {
    NSArray<MRRDemoSummary *> *basics = [NSArray arrayWithObjects:
                                         [[[MRRDemoSummary alloc] initWithDemoIdentifier:@"basics.retain-release"
                                                                                  title:@"Retain / Release Balance"
                                                                            summaryText:@"Track ownership changes created by alloc, retain, and autorelease."] autorelease],
                                         [[[MRRDemoSummary alloc] initWithDemoIdentifier:@"basics.autorelease-pool"
                                                                                  title:@"Autorelease Pools"
                                                                            summaryText:@"Use autorelease for handoff and keep explicit pools scoped."] autorelease],
                                         [[[MRRDemoSummary alloc] initWithDemoIdentifier:@"basics.property-semantics"
                                                                                  title:@"Property Semantics"
                                                                            summaryText:@"Choose retain, assign, or copy based on ownership guarantees."] autorelease],
                                         nil];

    return [NSDictionary dictionaryWithObject:basics forKey:MRRDemoCategoryIdentifierBasics];
}

- (NSDictionary<NSString *, MRRDemoDetail *> *)buildDetails {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [self detailForRetainRelease], @"basics.retain-release",
            [self detailForAutoreleasePool], @"basics.autorelease-pool",
            [self detailForPropertySemantics], @"basics.property-semantics",
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

- (MRRDemoDetail *)detailForRetainRelease {
    NSArray *sections = [NSArray arrayWithObjects:
                         [self sectionWithTitle:@"Rule"
                                       bodyText:@"Anything created with alloc, new, copy, or mutableCopy gives you ownership. Balance that ownership before the current scope is finished."
                                 checklistItems:[NSArray arrayWithObjects:@"Retain only when you need to extend lifetime.", @"Release every owned object exactly once.", @"Do not release objects you never owned.", nil]],
                         [self sectionWithTitle:@"Review Prompt"
                                       bodyText:@"When reading a method, highlight each ownership gain and verify where the matching release happens."
                                 checklistItems:[NSArray arrayWithObjects:@"Look for retained properties assigned from +1 objects.", @"Check early returns for leaked ownership.", nil]],
                         nil];
    return [self detailWithIdentifier:@"basics.retain-release"
                                title:@"Retain / Release Balance"
                             subtitle:@"The foundation of MRR is explicit ownership accounting."
                             sections:sections];
}

- (MRRDemoDetail *)detailForAutoreleasePool {
    NSArray *sections = [NSArray arrayWithObjects:
                         [self sectionWithTitle:@"Rule"
                                       bodyText:@"Autorelease lets a method hand back an object without forcing the caller to release it immediately. Pools drain later, so do not abuse them in tight loops."
                                 checklistItems:[NSArray arrayWithObjects:@"Return autoreleased objects from convenience methods.", @"Create local pools for heavy temporary work.", @"Prefer explicit release when no delayed lifetime is needed.", nil]],
                         [self sectionWithTitle:@"Review Prompt"
                                       bodyText:@"Spot code that creates many temporaries. If they rely on a distant pool drain, memory spikes will follow."
                                 checklistItems:[NSArray arrayWithObjects:@"Audit loops that build temporary strings or arrays.", @"Ensure any explicit pool is drained on every path.", nil]],
                         nil];
    return [self detailWithIdentifier:@"basics.autorelease-pool"
                                title:@"Autorelease Pools"
                             subtitle:@"Autorelease is a delayed release, not free memory management."
                             sections:sections];
}

- (MRRDemoDetail *)detailForPropertySemantics {
    NSArray *sections = [NSArray arrayWithObjects:
                         [self sectionWithTitle:@"Rule"
                                       bodyText:@"retain owns an object reference, copy owns an immutable snapshot, and assign is for primitives or non-owning back references."
                                 checklistItems:[NSArray arrayWithObjects:@"Use copy for NSString and blocks when mutation would be unsafe.", @"Use assign for delegates under MRR.", @"Release every retained or copied ivar in dealloc.", nil]],
                         [self sectionWithTitle:@"Review Prompt"
                                       bodyText:@"The property attribute should match the semantic promise the object makes to the rest of the app."
                                 checklistItems:[NSArray arrayWithObjects:@"Check that mutable input is copied when required.", @"Check that delegates are not retained.", nil]],
                         nil];
    return [self detailWithIdentifier:@"basics.property-semantics"
                                title:@"Property Semantics"
                             subtitle:@"Property attributes document and enforce ownership policy."
                             sections:sections];
}

@end
