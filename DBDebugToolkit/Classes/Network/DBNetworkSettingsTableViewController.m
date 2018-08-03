// The MIT License
//
// Copyright (c) 2016 Dariusz Bukowski
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "DBNetworkSettingsTableViewController.h"
#import "DBMenuSwitchTableViewCell.h"
#import "NSBundle+DBDebugToolkit.h"
#import "DBRequestModel.h"
#import <MessageUI/MessageUI.h>

static NSString *const DBNetworkSettingsTableViewControllerSwitchCellIdentifier = @"DBMenuSwitchTableViewCell";

@interface DBNetworkSettingsTableViewController () <DBMenuSwitchTableViewCellDelegate, MFMailComposeViewControllerDelegate>

@end

@implementation DBNetworkSettingsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSBundle *bundle = [NSBundle debugToolkitBundle];
    [self.tableView registerNib:[UINib nibWithNibName:@"DBMenuSwitchTableViewCell" bundle:bundle]
         forCellReuseIdentifier:DBNetworkSettingsTableViewControllerSwitchCellIdentifier];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithTitle: @"Export"
                                              style: UIBarButtonItemStylePlain
                                              target:self
                                              action:@selector(exportButtonPressed)];
}

#pragma mark - Private methods

- (void)exportButtonPressed {
    if (![MFMailComposeViewController canSendMail]) {
        // TODO: Show error message
        return;
    }

    NSMutableArray<NSDictionary *> *result = [[NSMutableArray<NSDictionary *> alloc] init];
    for (DBRequestModel *request in [[DBNetworkToolkit sharedInstance] savedRequests]) {
        [result addObject:[request asDictionary]];
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];

    if (!jsonData) {
        NSLog(@"Got an error: %@", error);
        return;
    }

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];

    MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
    mailViewController.mailComposeDelegate = self;
    [mailViewController setSubject:@"Network Activity Export"];

    NSString *filename = [NSString stringWithFormat:@"network-activity-%@.json", [[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] stringValue]];
    [mailViewController addAttachmentData:data
                                 mimeType:@"application/json"
                                 fileName:filename];

    [self presentViewController:mailViewController
                       animated:YES
                     completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DBMenuSwitchTableViewCell *switchTableViewCell = [tableView dequeueReusableCellWithIdentifier:DBNetworkSettingsTableViewControllerSwitchCellIdentifier];
    switchTableViewCell.titleLabel.text = @"Logging enabled";
    switchTableViewCell.valueSwitch.on = self.networkToolkit.loggingEnabled;
    switchTableViewCell.delegate = self;
    return switchTableViewCell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Logging requests may affect the memory usage.";
}

#pragma mark - DBMenuSwitchTableViewCellDelegate

- (void)menuSwitchTableViewCell:(DBMenuSwitchTableViewCell *)menuSwitchTableViewCell didSetOn:(BOOL)isOn {
    self.networkToolkit.loggingEnabled = isOn;
}

#pragma mark - MFMailComposeViewControllerDelegate
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(nullable NSError *)error {
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

@end
