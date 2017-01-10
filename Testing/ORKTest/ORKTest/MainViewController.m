/*
 Copyright (c) 2015, Apple Inc. All rights reserved.
 Copyright (c) 2015, Bruce Duncan.
 Copyright (c) 2015-2016, Ricardo Sánchez-Sáez.
 Copyright (c) 2016, Sage Bionetworks

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3.  Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "MainViewController.h"

#import "AppDelegate.h"

#import "TaskFactory.h"

#import "DynamicTask.h"

@import ResearchKit;

@import AVFoundation;


@interface SectionHeader: UICollectionReusableView

- (void)configureHeaderWithTitle:(NSString *)title;

@end


@implementation SectionHeader {
    UILabel *_title;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self sharedInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self sharedInit];
    }
    return self;
}

static UIColor *HeaderColor() {
    return [UIColor colorWithWhite:0.97 alpha:1.0];
}
static const CGFloat HeaderSideLayoutMargin = 16.0;

- (void)sharedInit {
    self.layoutMargins = UIEdgeInsetsMake(0, HeaderSideLayoutMargin, 0, HeaderSideLayoutMargin);
    self.backgroundColor = HeaderColor();
    _title = [UILabel new];
    _title.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]; // Table view header font
    [self addSubview:_title];
    
    _title.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = @{@"title": _title};
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[title]-|"
                                                                 options:NSLayoutFormatDirectionLeadingToTrailing
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[title]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
}

- (void)configureHeaderWithTitle:(NSString *)title {
    _title.text = title;
}

@end


@interface ButtonCell: UICollectionViewCell

- (void)configureButtonWithTitle:(NSString *)title target:(id)target selector:(SEL)selector;

@end


@implementation ButtonCell {
    UIButton *_button;
}

- (void)setUpButton {
    [_button removeFromSuperview];
    _button = [UIButton buttonWithType:UIButtonTypeSystem];
    _button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    _button.contentEdgeInsets = UIEdgeInsetsMake(0.0, HeaderSideLayoutMargin, 0.0, 0.0);
    [self.contentView addSubview:_button];
    
    _button.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = @{@"button": _button};
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[button]|"
                                                                             options:NSLayoutFormatDirectionLeadingToTrailing
                                                                             metrics:nil
                                                                               views:views]];
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[button]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
}

- (void)configureButtonWithTitle:(NSString *)title target:(id)target selector:(SEL)selector {
    [self setUpButton];
    [_button setTitle:title forState:UIControlStateNormal];
    [_button addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];
}

@end


@interface MainViewController () <ORKTaskViewControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, ORKPasscodeDelegate> {
    id<ORKTaskResultSource> _lastRouteResult;
    
    NSMutableDictionary<NSString *, NSData *> *_savedViewControllers;     // Maps task identifiers to task view controller restoration data
    
    UICollectionView *_collectionView;
    NSArray<NSString *> *_buttonSectionNames;
    NSArray<NSArray<NSString *> *> *_buttonTitles;
}

@property (nonatomic, strong) ORKTaskViewController *taskViewController;

@end


@implementation MainViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.restorationIdentifier = @"main";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _savedViewControllers = [NSMutableDictionary new];
    
    UICollectionViewFlowLayout *flowLayout = [UICollectionViewFlowLayout new];
    _collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:flowLayout];
    _collectionView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_collectionView];
    
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    [_collectionView registerClass:[SectionHeader class]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:CollectionViewHeaderReuseIdentifier];
    [_collectionView registerClass:[ButtonCell class]
        forCellWithReuseIdentifier:CollectionViewCellReuseIdentifier];
    
    UIView *statusBarBackground = [UIView new];
    statusBarBackground.backgroundColor = HeaderColor();
    [self.view addSubview:statusBarBackground];

    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    statusBarBackground.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = @{@"collectionView": _collectionView,
                            @"statusBarBackground": statusBarBackground,
                            @"topLayoutGuide": self.topLayoutGuide};
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[statusBarBackground]|"
                                                                      options:NSLayoutFormatDirectionLeadingToTrailing
                                                                      metrics:nil
                                                                        views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[statusBarBackground]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:statusBarBackground
                                                          attribute:NSLayoutAttributeBottom
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.topLayoutGuide
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1.0
                                                           constant:0.0]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[collectionView]|"
                                                                      options:NSLayoutFormatDirectionLeadingToTrailing
                                                                      metrics:nil
                                                                        views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[topLayoutGuide][collectionView]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    
    _buttonSectionNames = @[
                            @"Onboarding",
                            @"Question Steps",
                            @"Active Tasks",
                            @"Passcode",
                            @"Review Step",
                            @"Miscellaneous",
                            ];
    _buttonTitles = @[ @[ // Onboarding
                           @"Consent",
                           @"Consent Review",
                           @"Eligibility Form",
                           @"Eligibility Survey",
                           @"Login",
                           @"Registration",
                           @"Verification",
                           ],
                       @[ // Question Steps
                           @"Date Pickers",
                           @"Image Capture",
                           @"Video Capture",
                           @"Image Choices",
                           @"Location",
                           @"Scale",
                           @"Scale Color Gradient",
                           @"Mini Form",
                           @"Optional Form",
                           @"Selection Survey",
                           ],
                       @[ // Active Tasks
                           @"Active Step Task",
                           @"Audio Task",
                           @"Fitness Task",
                           @"GAIT Task",
                           @"Hole Peg Test Task",
                           @"Memory Game Task",
                           @"PSAT Task",
                           @"Reaction Time Task",
                           @"Timed Walk Task",
                           @"Tone Audiometry Task",
                           @"Tower Of Hanoi Task",
                           @"Two Finger Tapping Task",
                           @"Walk And Turn Task",
                           @"Hand Tremor Task",
                           @"Right Hand Tremor Task",
                           ],
                       @[ // Passcode
                           @"Authenticate Passcode",
                           @"Create Passcode",
                           @"Edit Passcode",
                           @"Remove Passcode",
                           ],
                       @[ // Review Step
                           @"Embedded Review Task",
                           @"Standalone Review Task",
                           ],
                       @[ // Miscellaneous
                           @"Custom Navigation Item",
                           @"Dynamic Task",
                           @"Interruptible Task",
                           @"Navigable Ordered Task",
                           @"Navigable Loop Task",
                           @"Predicate Tests",
                           @"Test Charts",
                           @"Test Charts Performance",
                           @"Toggle Tint Color",
                           @"Wait Task",
                           @"Step Will Disappear",
                           @"Confirmation Form Item",
                           @"Continue Button",
                           @"Instantiate Custom VC",
                           @"Table Step",
                           @"Signature Step",
                           @"Auxillary Image",
                           @"Icon Image",
                           ],
                       ];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [_collectionView reloadData];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return CGSizeMake(self.view.bounds.size.width, 22.0);  // Table view header height
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat viewWidth = self.view.bounds.size.width;
    NSUInteger numberOfColums = 2;
    if (viewWidth >= 667.0) {
        numberOfColums = 3;
    }
    CGFloat width = viewWidth / numberOfColums;
    return CGSizeMake(width, 44.0);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return _buttonSectionNames.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return ((NSArray *)_buttonTitles[section]).count;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    SectionHeader *sectionHeader = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:CollectionViewHeaderReuseIdentifier forIndexPath:indexPath];
    [sectionHeader configureHeaderWithTitle:_buttonSectionNames[indexPath.section]];
    return sectionHeader;
}

- (SEL)selectorFromButtonTitle:(NSString *)buttonTitle {
    // "THIS FOO baR title" is converted to the "thisFooBarTitleButtonTapped:" selector
    buttonTitle = buttonTitle.capitalizedString;
    NSMutableArray *titleTokens = [[buttonTitle componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] mutableCopy];
    titleTokens[0] = ((NSString *)titleTokens[0]).lowercaseString;
    NSString *selectorString = [NSString stringWithFormat:@"%@ButtonTapped:", [titleTokens componentsJoinedByString:@""]];
    return NSSelectorFromString(selectorString);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ButtonCell *buttonCell = [collectionView dequeueReusableCellWithReuseIdentifier:CollectionViewCellReuseIdentifier forIndexPath:indexPath];
    NSString *buttonTitle = _buttonTitles[indexPath.section][indexPath.row];
    SEL buttonSelector = [self selectorFromButtonTitle:buttonTitle];
    [buttonCell configureButtonWithTitle:buttonTitle target:self selector:buttonSelector];
    return buttonCell;
}

/*
 Creates a task and presents it with a task view controller.
 */
- (void)beginTaskWithIdentifier:(NSString *)identifier {
    /*
     This is our implementation of restoration after saving during a task.
     If the user saved their work on a previous run of a task with the same
     identifier, we attempt to restore the view controller here.
     
     Since unarchiving can throw an exception, in a real application we would
     need to attempt to catch that exception here.
     */

    id<ORKTask> task = [[TaskFactory sharedInstance] makeTaskWithIdentifier:identifier];
    
    if (_savedViewControllers[identifier]) {
        NSData *data = _savedViewControllers[identifier];
        self.taskViewController = [[ORKTaskViewController alloc] initWithTask:task restorationData:data delegate:self];
    } else {
        // No saved data, just create the task and the corresponding task view controller.
        self.taskViewController = [[ORKTaskViewController alloc] initWithTask:task taskRunUUID:[NSUUID UUID]];
    }
    
    // If we have stored data then data will contain the stored data.
    // If we don't, data will be nil (and the task will be opened up as a 'new' task.
    NSData *data = _savedViewControllers[identifier];
    self.taskViewController = [[ORKTaskViewController alloc] initWithTask:task restorationData:data delegate:self];
    
    [self beginTask];
}

/*
 Actually presents the task view controller.
 */
- (void)beginTask {
    id<ORKTask> task = self.taskViewController.task;
    self.taskViewController.delegate = self;
    
    if (_taskViewController.outputDirectory == nil) {
        // Sets an output directory in Documents, using the `taskRunUUID` in the path.
        NSURL *documents =  [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        NSURL *outputDir = [documents URLByAppendingPathComponent:self.taskViewController.taskRunUUID.UUIDString];
        [[NSFileManager defaultManager] createDirectoryAtURL:outputDir withIntermediateDirectories:YES attributes:nil error:nil];
        self.taskViewController.outputDirectory = outputDir;
    }
    
    /*
     For the dynamic task, we remember the last result and use it as a source
     of default values for any optional questions.
     */
    if ([task isKindOfClass:[DynamicTask class]]) {
        self.taskViewController.defaultResultSource = _lastRouteResult;
    }
    
    /*
     We set a restoration identifier so that UI state restoration is enabled
     for the task view controller. We don't need to do anything else to prepare
     for state restoration of a ResearchKit framework task VC.
     */
    _taskViewController.restorationIdentifier = [task identifier];
    
    if ([[task identifier] isEqualToString:CustomNavigationItemTaskIdentifier]) {
        _taskViewController.showsProgressInNavigationBar = NO;
    }
    
    [self presentViewController:_taskViewController animated:YES completion:nil];
}


- (void)datePickersButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:DatePickingTaskIdentifier];
}

- (void)selectionSurveyButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:SelectionSurveyTaskIdentifier];
}

- (void)activeStepTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:ActiveStepTaskIdentifier];
}

- (void)consentReviewButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:ConsentReviewTaskIdentifier];
}

- (void)consentButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:ConsentTaskIdentifier];
}

- (void)eligibilityFormButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:EligibilityFormTaskIdentifier];
}

- (void)eligibilitySurveyButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:EligibilitySurveyTaskIdentifier];
}

- (IBAction)loginButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:LoginTaskIdentifier];
}

- (IBAction)registrationButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:RegistrationTaskIdentifier];
}


- (IBAction)verificationButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:VerificationTaskIdentifier];
}

- (void)miniFormButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:MiniFormTaskIdentifier];
}

- (void)optionalFormButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:OptionalFormTaskIdentifier];
}

- (void)predicateTestsButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:PredicateTestsTaskIdentifier];
}

#pragma mark - Active tasks

- (void)fitnessTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:FitnessTaskIdentifier];
}

- (void)gaitTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:GaitTaskIdentifier];
}

- (void)memoryGameTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:MemoryTaskIdentifier];
}

- (IBAction)waitTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:WaitTaskIdentifier];
}

- (void)audioTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:AudioTaskIdentifier];
}

- (void)toneAudiometryTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:ToneAudiometryTaskIdentifier];
}

- (void)twoFingerTappingTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:TwoFingerTapTaskIdentifier];
}

- (void)reactionTimeTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:ReactionTimeTaskIdentifier];
}

- (void)towerOfHanoiTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:TowerOfHanoiTaskIdentifier];
}

- (void)timedWalkTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:TimedWalkTaskIdentifier];
}

- (void)psatTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:PSATTaskIdentifier];
}

- (void)holePegTestTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:HolePegTestTaskIdentifier];
}

- (void)walkAndTurnTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:WalkBackAndForthTaskIdentifier];
}

- (void)handTremorTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:TremorTaskIdentifier];
}

- (void)rightHandTremorTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:TremorRightHandTaskIdentifier];
}

#pragma mark - Dynamic task

/*
 See the `DynamicTask` class for a definition of this task.
 */
- (void)dynamicTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:DynamicTaskIdentifier];
}

- (void)interruptibleTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:InterruptibleTaskIdentifier];
}

- (void)scaleButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:ScalesTaskIdentifier];
}

- (void)scaleColorGradientButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:ColorScalesTaskIdentifier];
}

- (void)imageChoicesButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:ImageChoicesTaskIdentifier];
}

- (void)imageCaptureButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:ImageCaptureTaskIdentifier];
}

- (void)videoCaptureButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:VideoCaptureTaskIdentifier];
}

- (void)navigableOrderedTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:NavigableOrderedTaskIdentifier];
}

- (void)navigableLoopTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:NavigableLoopTaskIdentifier];
}

- (void)toggleTintColorButtonTapped:(id)sender {
    static UIColor *defaultTintColor = nil;
    if (!defaultTintColor) {
        defaultTintColor = self.view.tintColor;
    }
    if ([[UIView appearance].tintColor isEqual:[UIColor redColor]]) {
        [UIView appearance].tintColor = defaultTintColor;
    } else {
        [UIView appearance].tintColor = [UIColor redColor];
    }
    // Update appearance
    UIView *superview = self.view.superview;
    [self.view removeFromSuperview];
    [superview addSubview:self.view];
}

- (void)customNavigationItemButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:CustomNavigationItemTaskIdentifier];
}

#pragma mark - Passcode step and view controllers

- (void)createPasscodeButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:CreatePasscodeTaskIdentifier];
}

- (void)removePasscodeButtonTapped:(id)sender {
    if ([ORKPasscodeViewController isPasscodeStoredInKeychain]) {
        if ([ORKPasscodeViewController removePasscodeFromKeychain]) {
            [self showAlertWithTitle:@"Success" message:@"Passcode removed."];
        } else {
            [self showAlertWithTitle:@"Error" message:@"Passcode could not be removed."];
        }
    } else {
        [self showAlertWithTitle:@"Error" message:@"There is no passcode stored in the keychain."];
    }
}

- (void)authenticatePasscodeButtonTapped:(id)sender {
    if ([ORKPasscodeViewController isPasscodeStoredInKeychain]) {
        ORKPasscodeViewController *viewController = [ORKPasscodeViewController
                                                     passcodeAuthenticationViewControllerWithText:@"Authenticate your passcode in order to proceed."
                                                     delegate:self];
        [self presentViewController:viewController animated:YES completion:nil];
    } else {
        [self showAlertWithTitle:@"Error" message:@"A passcode must be created before you can authenticate it."];
    }
}

- (void)editPasscodeButtonTapped:(id)sender {
    if ([ORKPasscodeViewController isPasscodeStoredInKeychain]) {
        ORKPasscodeViewController *viewController = [ORKPasscodeViewController passcodeEditingViewControllerWithText:nil
                                                                                                            delegate:self
                                                                                                        passcodeType:ORKPasscodeType6Digit];
        [self presentViewController:viewController animated:YES completion:nil];
    } else {
        [self showAlertWithTitle:@"Error" message:@"A passcode must be created before you can edit it."];
    }
}

#pragma mark - Passcode delegate

- (void)passcodeViewControllerDidFailAuthentication:(UIViewController *)viewController {
    NSLog(@"Passcode authentication failed.");
    [self showAlertWithTitle:@"Error" message:@"Passcode authentication failed"];
}

- (void)passcodeViewControllerDidFinishWithSuccess:(UIViewController *)viewController {
    NSLog(@"New passcode saved.");
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)passcodeViewControllerDidCancel:(UIViewController *)viewController {
    NSLog(@"User tapped the cancel button.");
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)passcodeViewControllerForgotPasscodeTapped:(UIViewController *)viewController {
    NSLog(@"Forgot Passcode tapped.");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Forgot Passcode"
                                                                   message:@"Forgot Passcode tapped."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [viewController presentViewController:alert animated:YES completion:nil];
}

- (IBAction)embeddedReviewTaskButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:EmbeddedReviewTaskIdentifier];
}

- (IBAction)standaloneReviewTaskButtonTapped:(id)sender {
    if ([TaskFactory sharedInstance].embeddedReviewTaskResult != nil) {
        [self beginTaskWithIdentifier:StandaloneReviewTaskIdentifier];
    } else {
        [self showAlertWithTitle:@"Alert" message:@"Please run embedded review task first"];
    }
}

#pragma mark - Helpers

/*
 Shows an alert.
 
 Used to display an alert with the provided title and message.
 
 @param title       The title text for the alert.
 @param message     The message text for the alert.
 */
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Managing the task view controller

/*
 Dismisses the task view controller.
 */
- (void)dismissTaskViewController:(ORKTaskViewController *)taskViewController removeOutputDirectory:(BOOL)removeOutputDirectory {
    [TaskFactory sharedInstance].currentConsentDocument = nil;
    
    NSURL *outputDirectoryURL = taskViewController.outputDirectory;
    [self dismissViewControllerAnimated:YES completion:^{
        if (outputDirectoryURL && removeOutputDirectory)
        {
            /*
             We attempt to clean up the output directory.
             
             This is only useful for a test app, where we don't care about the
             data after the test is complete. In a real application, only
             delete your data when you've processed it or sent it to a server.
             */
            NSError *err = nil;
            if (![[NSFileManager defaultManager] removeItemAtURL:outputDirectoryURL error:&err]) {
                NSLog(@"Error removing %@: %@", outputDirectoryURL, err);
            }
        }
    }];
}

#pragma mark - ORKTaskViewControllerDelegate

/*
 Any step can have "Learn More" content.
 
 For testing, we return YES only for instruction steps, except on the active
 tasks.
 */
- (BOOL)taskViewController:(ORKTaskViewController *)taskViewController hasLearnMoreForStep:(ORKStep *)step {
    NSString *task_identifier = taskViewController.task.identifier;

    return ([step isKindOfClass:[ORKInstructionStep class]]
            && NO == [@[AudioTaskIdentifier, FitnessTaskIdentifier, GaitTaskIdentifier, TwoFingerTapTaskIdentifier, NavigableOrderedTaskIdentifier, NavigableLoopTaskIdentifier] containsObject:task_identifier]);
}

/*
 When the user taps on "Learn More" on a step, respond on this delegate callback.
 In this test app, we just print to the console.
 */
- (void)taskViewController:(ORKTaskViewController *)taskViewController learnMoreForStep:(ORKStepViewController *)stepViewController {
    NSLog(@"Learn more tapped for step %@", stepViewController.step.identifier);
}

- (BOOL)taskViewController:(ORKTaskViewController *)taskViewController shouldPresentStep:(ORKStep *)step {
    if ([ step.identifier isEqualToString:@"itid_002"]) {
        /*
         Tests interrupting navigation from the task view controller delegate.
         
         This is an example of preventing a user from proceeding if they don't
         enter a valid answer.
         */
        
        ORKQuestionResult *questionResult = (ORKQuestionResult *)[[[taskViewController result] stepResultForStepIdentifier:@"itid_001"] firstResult];
        if (questionResult == nil || [(NSNumber *)questionResult.answer integerValue] < 18) {
            UIAlertController *alertViewController =
            [UIAlertController alertControllerWithTitle:@"Warning"
                                                message:@"You can't participate if you are under 18."
                                         preferredStyle:UIAlertControllerStyleAlert];
            
            
            UIAlertAction *ok = [UIAlertAction
                                 actionWithTitle:@"OK"
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action)
                                 {
                                     [alertViewController dismissViewControllerAnimated:YES completion:nil];
                                 }];
            
            
            [alertViewController addAction:ok];
            
            [taskViewController presentViewController:alertViewController animated:NO completion:nil];
            return NO;
        }
    }
    return YES;
}

/*
 In `stepViewControllerWillAppear:`, it is possible to significantly customize
 the behavior of the step view controller. In this test app, we do a few funny
 things to push the limits of this customization.
 */
- (void)taskViewController:(ORKTaskViewController *)taskViewController
stepViewControllerWillAppear:(ORKStepViewController *)stepViewController {
    
    if ([stepViewController.step.identifier isEqualToString:@"aid_001c"]) {
        /*
         Tests adding a custom view to a view controller for an active step, without
         subclassing.
         
         This is possible, but not recommended. A better choice would be to create
         a custom active step subclass and a matching active step view controller
         subclass, so you completely own the view controller and its appearance.
         */
        
        UIView *customView = [UIView new];
        customView.backgroundColor = [UIColor cyanColor];
        
        // Have the custom view request the space it needs.
        // A little tricky because we need to let it size to fit if there's not enough space.
        customView.translatesAutoresizingMaskIntoConstraints = NO;
        NSArray *verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[c(>=160)]"
                                                                               options:(NSLayoutFormatOptions)0
                                                                               metrics:nil
                                                                                 views:@{@"c":customView}];
        for (NSLayoutConstraint *constraint in verticalConstraints)
        {
            constraint.priority = UILayoutPriorityFittingSizeLevel;
        }
        [NSLayoutConstraint activateConstraints:verticalConstraints];
        [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[c(>=280)]"
                                                                                        options:(NSLayoutFormatOptions)0
                                                                                        metrics:nil
                                                                                          views:@{@"c":customView}]];
        
        [(ORKActiveStepViewController *)stepViewController setCustomView:customView];
        
        // Set custom button on navigation bar
        stepViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Custom button"
                                                                                               style:UIBarButtonItemStylePlain
                                                                                              target:nil
                                                                                              action:nil];
    } else if ([stepViewController.step.identifier hasPrefix:@"question_"]
               && ![stepViewController.step.identifier hasSuffix:@"6"]) {
        /*
         Tests customizing continue button ("some of the time").
         */
        stepViewController.continueButtonTitle = @"Next Question";
    } else if ([stepViewController.step.identifier isEqualToString:@"mini_form_001"]) {
        /*
         Tests customizing continue and learn more buttons.
         */
        stepViewController.continueButtonTitle = @"Try Mini Form";
        stepViewController.learnMoreButtonTitle = @"Learn more about this survey";
    } else if ([stepViewController.step.identifier isEqualToString: @"qid_001"]) {
        /*
         Example of customizing the back and cancel buttons in a way that's
         visibly obvious.
         */
        stepViewController.backButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back1"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:stepViewController.backButtonItem.target
                                                                            action:stepViewController.backButtonItem.action];
        stepViewController.cancelButtonItem.title = @"Cancel1";
    } else if ([stepViewController.step.identifier isEqualToString:@"customNavigationItemTask.step1"]) {
        stepViewController.navigationItem.title = @"Custom title";
    } else if ([stepViewController.step.identifier isEqualToString:@"customNavigationItemTask.step2"]) {
        NSMutableArray *items = [[NSMutableArray alloc] init];
        [items addObject:@"Item1"];
        [items addObject:@"Item2"];
        [items addObject:@"Item3"];
        stepViewController.navigationItem.titleView = [[UISegmentedControl alloc] initWithItems:items];
    } else if ([stepViewController.step.identifier isEqualToString:@"waitTask.step2"]) {
        // Indeterminate step
        [((ORKWaitStepViewController *)stepViewController) performSelector:@selector(updateText:) withObject:@"Updated text" afterDelay:2.0];
        [((ORKWaitStepViewController *)stepViewController) performSelector:@selector(goForward) withObject:nil afterDelay:5.0];
    } else if ([stepViewController.step.identifier isEqualToString:@"waitTask.step4"]) {
        // Determinate step
        [self updateProgress:0.0 waitStepViewController:((ORKWaitStepViewController *)stepViewController)];
    }

}

/*
 We support save and restore on all of the tasks in this test app.
 
 In a real app, not all tasks necessarily ought to support saving -- for example,
 active tasks that can't usefully be restarted after a significant time gap
 should not support save at all.
 */
- (BOOL)taskViewControllerSupportsSaveAndRestore:(ORKTaskViewController *)taskViewController {
    return YES;
}

/*
 In almost all cases, we want to dismiss the task view controller.
 
 In this test app, we don't dismiss on a fail (we just log it).
 */
- (void)taskViewController:(ORKTaskViewController *)taskViewController didFinishWithReason:(ORKTaskViewControllerFinishReason)reason error:(NSError *)error {
    switch (reason) {
        case ORKTaskViewControllerFinishReasonCompleted:
            if ([taskViewController.task.identifier isEqualToString:EmbeddedReviewTaskIdentifier]) {
                [TaskFactory sharedInstance].embeddedReviewTaskResult = taskViewController.result;
            }
            [self taskViewControllerDidComplete:taskViewController];
            break;
        case ORKTaskViewControllerFinishReasonFailed:
            NSLog(@"Error on step %@: %@", taskViewController.currentStepViewController.step, error);
            break;
        case ORKTaskViewControllerFinishReasonDiscarded:
            if ([taskViewController.task.identifier isEqualToString:EmbeddedReviewTaskIdentifier]) {
                [TaskFactory sharedInstance].embeddedReviewTaskResult = nil;
            }
            [self dismissTaskViewController:taskViewController removeOutputDirectory:YES];
            break;
        case ORKTaskViewControllerFinishReasonSaved:
        {
            if ([taskViewController.task.identifier isEqualToString:EmbeddedReviewTaskIdentifier]) {
                [TaskFactory sharedInstance].embeddedReviewTaskResult = taskViewController.result;
            }
            /*
             Save the restoration data, dismiss the task VC, and do an early return
             so we don't clear the restoration data.
             */
            id<ORKTask> task = taskViewController.task;
            _savedViewControllers[task.identifier] = taskViewController.restorationData;
            [self dismissTaskViewController:taskViewController removeOutputDirectory:NO];
            return;
        }
            break;
            
        default:
            break;
    }
    
    [_savedViewControllers removeObjectForKey:taskViewController.task.identifier];
    _taskViewController = nil;
}

/*
 When a task completes, we pretty-print the result to the console.
 
 This is ok for testing, but if what you want to do is see the results of a task,
 the `ORKCatalog` Swift sample app might be a better choice, since it lets
 you navigate through the result structure.
 */
- (void)taskViewControllerDidComplete:(ORKTaskViewController *)taskViewController {
    
    NSLog(@"[ORKTest] task results: %@", taskViewController.result);
    
    if ([TaskFactory sharedInstance].currentConsentDocument) {
        /*
         This demonstrates how to take a signature result, apply it to a document,
         and then generate a PDF From the document that includes the signature.
         */
        
        // Search for the review step.
        NSArray *steps = [(ORKOrderedTask *)taskViewController.task steps];
        NSPredicate *predicate = [NSPredicate predicateWithFormat: @"self isKindOfClass: %@", [ORKConsentReviewStep class]];
        ORKStep *reviewStep = [[steps filteredArrayUsingPredicate:predicate] firstObject];
        ORKConsentSignatureResult *signatureResult = (ORKConsentSignatureResult *)[[[taskViewController result] stepResultForStepIdentifier:reviewStep.identifier] firstResult];
        
        [signatureResult applyToDocument:[TaskFactory sharedInstance].currentConsentDocument];
        
        [[TaskFactory sharedInstance].currentConsentDocument makePDFWithCompletionHandler:^(NSData *pdfData, NSError *error) {
            NSLog(@"Created PDF of size %lu (error = %@)", (unsigned long)pdfData.length, error);
            
            if (!error) {
                NSURL *documents = [NSURL fileURLWithPath:NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject];
                NSURL *outputUrl = [documents URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.pdf", taskViewController.taskRunUUID.UUIDString]];
                
                [pdfData writeToURL:outputUrl atomically:YES];
                NSLog(@"Wrote PDF to %@", [outputUrl path]);
            }
        }];
        
        [TaskFactory sharedInstance].currentConsentDocument = nil;
    }
    
    NSURL *dir = taskViewController.outputDirectory;
    [self dismissViewControllerAnimated:YES completion:^{
        if (dir)
        {
            NSError *err = nil;
            if (![[NSFileManager defaultManager] removeItemAtURL:dir error:&err]) {
                NSLog(@"Error removing %@: %@", dir, err);
            }
        }
    }];
}

/**
  When a task has completed it calls this method to post the result of the task to the delegate.
*/
- (void)taskViewController:(ORKTaskViewController *)taskViewController didChangeResult:(ORKTaskResult *)result {
    /*
     Upon creation of a Passcode by a user, the results of their creation
     are returned by getting it from ORKPasscodeResult in this delegate call.
     This is triggered upon completion/failure/or cancel
     */
    ORKStepResult *stepResult = (ORKStepResult *)[[result results] firstObject];
    if ([[[stepResult results] firstObject] isKindOfClass:[ORKPasscodeResult class]]) {
        ORKPasscodeResult *passcodeResult = (ORKPasscodeResult *)[[stepResult results] firstObject];
        NSLog(@"passcode saved: %d , Touch ID Enabled: %d", passcodeResult.passcodeSaved, passcodeResult.touchIdEnabled);

    }
}

- (void)taskViewController:(ORKTaskViewController *)taskViewController stepViewControllerWillDisappear:(ORKStepViewController *)stepViewController navigationDirection:(ORKStepViewControllerNavigationDirection)direction {
    if ([taskViewController.task.identifier isEqualToString:StepWillDisappearTaskIdentifier] &&
        [stepViewController.step.identifier isEqualToString:StepWillDisappearFirstStepIdentifier]) {
        taskViewController.view.tintColor = [UIColor magentaColor];
    }
}

#pragma mark - UI state restoration

/*
 UI state restoration code for the MainViewController.
 
 The MainViewController needs to be able to re-create the exact task that
 was being done, in order for the task view controller to restore correctly.
 
 In a real app implementation, this might mean that you would also need to save
 and restore the actual task; here, since we know the tasks don't change during
 testing, we just re-create the task.
 */
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    
    [coder encodeObject:_taskViewController forKey:@"taskVC"];
    [coder encodeObject:_lastRouteResult forKey:@"lastRouteResult"];
    [coder encodeObject:[TaskFactory sharedInstance].embeddedReviewTaskResult forKey:@"embeddedReviewTaskResult"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    
    _taskViewController = [coder decodeObjectOfClass:[UIViewController class] forKey:@"taskVC"];
    _lastRouteResult = [coder decodeObjectForKey:@"lastRouteResult"];
    
    // Need to give the task VC back a copy of its task, so it can restore itself.
    
    // Could save and restore the task's identifier separately, but the VC's
    // restoration identifier defaults to the task's identifier.
    id<ORKTask> taskForTaskViewController = [[TaskFactory sharedInstance] makeTaskWithIdentifier:_taskViewController.restorationIdentifier];
    
    _taskViewController.task = taskForTaskViewController;
    if ([_taskViewController.restorationIdentifier isEqualToString:@"DynamicTask01"])
    {
        _taskViewController.defaultResultSource = _lastRouteResult;
    }
    _taskViewController.delegate = self;
}

#pragma mark - Charts

- (void)testChartsButtonTapped:(id)sender {
    UIStoryboard *chartStoryboard = [UIStoryboard storyboardWithName:@"Charts" bundle:nil];
    UIViewController *chartListViewController = [chartStoryboard instantiateViewControllerWithIdentifier:@"ChartListViewController"];
    [self presentViewController:chartListViewController animated:YES completion:nil];
}

- (void)testChartsPerformanceButtonTapped:(id)sender {
    UIStoryboard *chartStoryboard = [UIStoryboard storyboardWithName:@"Charts" bundle:nil];
    UIViewController *chartListViewController = [chartStoryboard instantiateViewControllerWithIdentifier:@"ChartPerformanceListViewController"];
    [self presentViewController:chartListViewController animated:YES completion:nil];
}

#pragma mark - Wait Task

- (void)updateProgress:(CGFloat)progress waitStepViewController:(ORKWaitStepViewController *)waitStepviewController {
    if (progress <= 1.0) {
        [waitStepviewController setProgress:progress animated:true];
        double delayInSeconds = 0.1;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            [self updateProgress:(progress + 0.01) waitStepViewController:waitStepviewController];
            if (progress > 0.495 && progress < 0.505) {
                NSString *newText = @"Please wait while the data is downloaded.";
                [waitStepviewController updateText:newText];
            }
        });
    } else {
        [waitStepviewController goForward];
    }
}

- (IBAction)locationButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:LocationTaskIdentifier];
}

- (IBAction)stepWillDisappearButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:StepWillDisappearTaskIdentifier];
}

- (IBAction)confirmationFormItemButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:ConfirmationFormTaskIdentifier];
}

#pragma mark - Continue button

- (IBAction)continueButtonButtonTapped:(id)sender {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"ContinueButtonExample" bundle:nil];
    UIViewController *vc = [storyboard instantiateInitialViewController];
    [self presentViewController:vc animated:YES completion:nil];
}

- (IBAction)instantiateCustomVcButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:InstantiateCustomVCTaskIdentifier];
}

- (IBAction)tableStepButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:TableStepTaskIdentifier];
}

- (IBAction)signatureStepButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:SignatureStepTaskIdentifier];
}

- (IBAction)auxillaryImageButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:AuxillaryImageTaskIdentifier];
}

- (IBAction)iconImageButtonTapped:(id)sender {
    [self beginTaskWithIdentifier:IconImageTaskIdentifier];
}

@end
