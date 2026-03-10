#import "DemoListViewController.h"
#import "../../Domain/Models/MRRDemoCategory.h"
#import "../../Domain/Models/MRRDemoSummary.h"
#import "../Protocols/DemoListPresenting.h"
#import "../Protocols/DemoScreenBuilding.h"
#import "../Protocols/DemoListView.h"

@interface DemoListViewController () <DemoListView, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, retain) id<DemoListPresenting> presenter;
@property (nonatomic, retain) id<DemoScreenBuilding> screenFactory;
@property (nonatomic, retain) UILabel *headingLabel;
@property (nonatomic, retain) UILabel *summaryLabel;
@property (nonatomic, retain) UITableView *tableView;
@property (nonatomic, retain) NSArray<MRRDemoSummary *> *demos;

@end

@implementation DemoListViewController

- (instancetype)initWithPresenter:(id<DemoListPresenting>)presenter
                    screenFactory:(id<DemoScreenBuilding>)screenFactory {
    NSParameterAssert(presenter != nil);
    NSParameterAssert(screenFactory != nil);

    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _presenter = [presenter retain];
        _screenFactory = [screenFactory retain];
        self.title = @"MRR Demos";
    }

    return self;
}

- (void)dealloc {
    _tableView.dataSource = nil;
    _tableView.delegate = nil;

    [_presenter release];
    [_screenFactory release];
    [_headingLabel release];
    [_summaryLabel release];
    [_tableView release];
    [_demos release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];

    UILabel *headingLabel = [[[UILabel alloc] init] autorelease];
    headingLabel.font = [UIFont boldSystemFontOfSize:28.0];
    headingLabel.textColor = [UIColor blackColor];
    headingLabel.numberOfLines = 0;
    headingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:headingLabel];
    self.headingLabel = headingLabel;

    UILabel *summaryLabel = [[[UILabel alloc] init] autorelease];
    summaryLabel.font = [UIFont systemFontOfSize:16.0];
    summaryLabel.textColor = [UIColor darkGrayColor];
    summaryLabel.numberOfLines = 0;
    summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:summaryLabel];
    self.summaryLabel = summaryLabel;

    UITableView *tableView = [[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped] autorelease];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 72.0;
    tableView.tableFooterView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
    [self.view addSubview:tableView];
    self.tableView = tableView;

    [NSLayoutConstraint activateConstraints:@[
        [headingLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24.0],
        [headingLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [headingLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [summaryLabel.topAnchor constraintEqualToAnchor:headingLabel.bottomAnchor constant:8.0],
        [summaryLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [summaryLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [tableView.topAnchor constraintEqualToAnchor:summaryLabel.bottomAnchor constant:16.0],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self.presenter attachView:self];
    [self.presenter viewDidLoad];
}

- (void)displayCategory:(MRRDemoCategory *)category demos:(NSArray<MRRDemoSummary *> *)demos {
    self.title = category.title;
    self.headingLabel.text = category.title;
    self.summaryLabel.text = category.summaryText;
    self.demos = demos;
    [self.tableView reloadData];
}

- (void)displayListErrorMessage:(NSString *)message {
    self.headingLabel.text = @"Unavailable";
    self.summaryLabel.text = message;
    self.demos = [NSArray array];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.demos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const CellIdentifier = @"DemoSummaryCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
    }

    MRRDemoSummary *summary = [self.demos objectAtIndex:(NSUInteger)indexPath.row];
    cell.textLabel.text = summary.title;
    cell.detailTextLabel.text = summary.summaryText;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self selectDemoAtIndex:(NSUInteger)indexPath.row];
}

- (void)selectDemoAtIndex:(NSUInteger)index {
    if (index >= self.demos.count) {
        return;
    }

    MRRDemoSummary *summary = [self.demos objectAtIndex:index];
    UIViewController *detailController = [self.screenFactory detailViewControllerForDemoIdentifier:summary.demoIdentifier];
    [self.navigationController pushViewController:detailController animated:YES];
}

@end
