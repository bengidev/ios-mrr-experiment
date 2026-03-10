#import "RelationshipsDemoRepository.h"
#import "../../../Core/Domain/Models/MRRDemoCategory.h"
#import "../../../Core/Domain/Models/MRRDemoDetail.h"
#import "../../../Core/Domain/Models/MRRDemoSection.h"
#import "../../../Core/Domain/Models/MRRDemoSummary.h"

@interface RelationshipsDemoRepository ()

@property (nonatomic, retain) NSArray<MRRDemoCategory *> *categories;
@property (nonatomic, retain) NSDictionary<NSString *, NSArray<MRRDemoSummary *> *> *summariesByCategoryIdentifier;
@property (nonatomic, retain) NSDictionary<NSString *, MRRDemoDetail *> *detailsByIdentifier;

@end

@implementation RelationshipsDemoRepository

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
    MRRDemoCategory *relationships = [[[MRRDemoCategory alloc] initWithIdentifier:MRRDemoCategoryIdentifierRelationships
                                                                            title:@"Relationships"
                                                                      summaryText:@"Delegate references, parent-child ownership, and collection behavior."] autorelease];
    return [NSArray arrayWithObject:relationships];
}

- (NSDictionary<NSString *, NSArray<MRRDemoSummary *> *> *)buildSummaries {
    NSArray<MRRDemoSummary *> *relationships = [NSArray arrayWithObjects:
                                                [[[MRRDemoSummary alloc] initWithDemoIdentifier:@"relationships.delegate-ownership"
                                                                                         title:@"Delegate Ownership"
                                                                                   summaryText:@"Delegates must stay non-owning to avoid retain cycles."] autorelease],
                                                [[[MRRDemoSummary alloc] initWithDemoIdentifier:@"relationships.parent-child"
                                                                                         title:@"Parent / Child Flow"
                                                                                   summaryText:@"Parents own children; children point back with assign references."] autorelease],
                                                [[[MRRDemoSummary alloc] initWithDemoIdentifier:@"relationships.collection-behavior"
                                                                                         title:@"Collection Semantics"
                                                                                   summaryText:@"Collections retain inserted objects, so call sites must release correctly."] autorelease],
                                                nil];

    return [NSDictionary dictionaryWithObject:relationships forKey:MRRDemoCategoryIdentifierRelationships];
}

- (NSDictionary<NSString *, MRRDemoDetail *> *)buildDetails {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [self detailForDelegateOwnership], @"relationships.delegate-ownership",
            [self detailForParentChild], @"relationships.parent-child",
            [self detailForCollectionBehavior], @"relationships.collection-behavior",
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

- (MRRDemoDetail *)detailForDelegateOwnership {
    NSArray *sections = [NSArray arrayWithObjects:
                         [self sectionWithTitle:@"Rule"
                                       bodyText:@"A delegate should not own the object that delegates to it. Under MRR, that means assign instead of retain."
                                 checklistItems:[NSArray arrayWithObjects:@"Delegate properties stay assign.", @"Clear delegate references when either side tears down.", @"Never create a retain cycle between controller and service.", nil]],
                         [self sectionWithTitle:@"Review Prompt"
                                       bodyText:@"Follow both directions of the relationship. If each side retains the other, neither will deallocate."
                                 checklistItems:[NSArray arrayWithObjects:@"Inspect service-to-controller references.", @"Inspect parent-child callback references.", nil]],
                         nil];
    return [self detailWithIdentifier:@"relationships.delegate-ownership"
                                title:@"Delegate Ownership"
                             subtitle:@"Delegation should move messages, not ownership."
                             sections:sections];
}

- (MRRDemoDetail *)detailForParentChild {
    NSArray *sections = [NSArray arrayWithObjects:
                         [self sectionWithTitle:@"Rule"
                                       bodyText:@"The parent flow owns child objects that are active. Children point back with assign references only long enough to signal completion."
                                 checklistItems:[NSArray arrayWithObjects:@"Parent retains active children.", @"Child-to-parent references stay assign.", @"Remove finished children from retained collections.", nil]],
                         [self sectionWithTitle:@"Review Prompt"
                                       bodyText:@"This is the same ownership rule you would apply to nested controllers, services, or routers without needing a coordinator abstraction."
                                 checklistItems:[NSArray arrayWithObjects:@"Audit collections that hold children.", @"Check finish paths for remove-and-release behavior.", nil]],
                         nil];
    return [self detailWithIdentifier:@"relationships.parent-child"
                                title:@"Parent / Child Ownership"
                             subtitle:@"Ownership should flow in one direction through a hierarchy."
                             sections:sections];
}

- (MRRDemoDetail *)detailForCollectionBehavior {
    NSArray *sections = [NSArray arrayWithObjects:
                         [self sectionWithTitle:@"Rule"
                                       bodyText:@"Foundation collections retain inserted objects. After adding an owned object to a collection, the caller can usually release its own ownership."
                                 checklistItems:[NSArray arrayWithObjects:@"Release owned objects after inserting into retaining collections.", @"Copy collections only when isolation is required.", @"Audit removal paths for stale references.", nil]],
                         [self sectionWithTitle:@"Review Prompt"
                                       bodyText:@"Collection APIs often hide retains, so missing one release at the call site is a common source of leaks."
                                 checklistItems:[NSArray arrayWithObjects:@"Check init/addObject/release sequences.", @"Check copied collections for missing release calls.", nil]],
                         nil];
    return [self detailWithIdentifier:@"relationships.collection-behavior"
                                title:@"Collection Semantics"
                             subtitle:@"Collections participate in ownership whether or not your API spells it out."
                             sections:sections];
}

@end
