//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DWActionsStackView.h"

#import "DWAlertInternalConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface DWActionsStackView () <DWAlertViewActionButtonDelegate>

@property (nullable, strong, nonatomic) DWAlertViewActionButton *cancelButton;
@property (null_resettable, strong, nonatomic) UISelectionFeedbackGenerator *feedbackGenerator;
@property (nullable, strong, nonatomic) DWAlertViewActionButton *highlightedButton;

@end

@implementation DWActionsStackView

@dynamic arrangedSubviews;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.axis = UILayoutConstraintAxisHorizontal;
        self.alignment = UIStackViewAlignmentFill;
        self.distribution = UIStackViewDistributionFillEqually;
        self.spacing = DWAlertViewSeparatorSize();

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(contentSizeCategoryDidChangeNotification:)
                                                     name:UIContentSizeCategoryDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)addActionButton:(DWAlertViewActionButton *)button {
    NSAssert([button isKindOfClass:DWAlertViewActionButton.class], @"Invalid button type");

    button.delegate = self;
    if (button.alertAction.style == DWAlertActionStyleCancel) {
        self.cancelButton = button;
    }
    [self addArrangedSubview:button];

    [self updatePreferredAction];
    [self updateButtonsLayout];
}

- (void)resetActionsState {
    [self resetHighlightedButton];
}

- (void)setPreferredAction:(nullable DWAlertAction *)preferredAction {
    _preferredAction = preferredAction;
    [self updatePreferredAction];
}

- (void)removeAllActions {
    [self resetHighlightedButton];
    
    NSArray <DWAlertViewActionButton *> *actions = [self.arrangedSubviews copy];
    for (DWAlertViewActionButton *button in actions) {
        button.delegate = nil;
        [self removeArrangedSubview:button];
    }
    
    _preferredAction = nil;
    self.cancelButton = nil;
}

#pragma mark - DWAlertViewActionButtonDelegate

- (void)actionButton:(DWAlertViewActionButton *)actionButton touchBegan:(UITouch *)touch {
    if (actionButton.alertAction.enabled) {
        actionButton.highlighted = YES;
        [self.delegate actionsStackView:self highlightActionAtRect:actionButton.frame];
        self.highlightedButton = actionButton;
    }

    [self.feedbackGenerator prepare];
}

- (void)actionButton:(DWAlertViewActionButton *)actionButton touchMoved:(UITouch *)touch {
    CGRect highlightedRect = CGRectZero;
    DWAlertViewActionButton *highlightedButton = nil;
    for (DWAlertViewActionButton *button in self.arrangedSubviews) {
        CGRect bounds = button.bounds;
        CGPoint point = [touch locationInView:button];
        if (button.alertAction.enabled && CGRectContainsPoint(bounds, point)) {
            button.highlighted = YES;
            highlightedRect = button.frame;
            highlightedButton = button;
        }
        else {
            button.highlighted = NO;
        }
    }
    [self.delegate actionsStackView:self highlightActionAtRect:highlightedRect];
    if (!!highlightedButton && highlightedButton != self.highlightedButton) {
        [self.feedbackGenerator selectionChanged];
        [self.feedbackGenerator prepare];
    }
    self.highlightedButton = highlightedButton;
}

- (void)actionButton:(DWAlertViewActionButton *)actionButton touchEnded:(UITouch *)touch {
    for (DWAlertViewActionButton *button in self.arrangedSubviews) {
        CGRect bounds = button.bounds;
        CGPoint point = [touch locationInView:button];
        if (button.alertAction.enabled && CGRectContainsPoint(bounds, point)) {
            [self.delegate actionsStackView:self didAction:button.alertAction];
        }
    }
    [self resetHighlightedButton];
}

- (void)actionButton:(DWAlertViewActionButton *)actionButton touchCancelled:(UITouch *)touch {
    [self resetHighlightedButton];
}

#pragma mark - Private

- (UISelectionFeedbackGenerator *)feedbackGenerator {
    if (!_feedbackGenerator) {
        _feedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
    }
    return _feedbackGenerator;
}

- (void)resetHighlightedButton {
    for (DWAlertViewActionButton *button in self.arrangedSubviews) {
        button.highlighted = NO;
    }
    [self.delegate actionsStackView:self highlightActionAtRect:CGRectZero];
    self.feedbackGenerator = nil;
    self.highlightedButton = nil;
}

- (void)updatePreferredAction {
    if (!self.preferredAction) {
        self.cancelButton.preferred = YES;

        return;
    }

    for (DWAlertViewActionButton *button in self.arrangedSubviews) {
        button.preferred = (button.alertAction == self.preferredAction);
    }
}

- (void)updateButtonsLayout {
    NSArray<DWAlertViewActionButton *> *buttons = self.arrangedSubviews;
    NSUInteger buttonsCount = buttons.count;
    if (buttonsCount < 2) {
        self.axis = UILayoutConstraintAxisHorizontal;
    }
    else if (buttonsCount == 2) {
        BOOL shouldBeVertical = NO;
        CGFloat actionWidth = DWAlertViewWidth / 2.0 - DWAlertViewSeparatorSize(); // only 2 horizontal buttons are allowed
        for (UIView *button in buttons) {
            CGSize size = [button sizeThatFits:CGSizeMake(DWAlertViewWidth, DWAlertViewActionButtonHeight)];
            if (size.width > actionWidth) {
                shouldBeVertical = YES;
                break;
            }
        }

        self.axis = shouldBeVertical ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    }
    else {
        self.axis = UILayoutConstraintAxisVertical;
    }

    DWAlertViewActionButton *cancelButton = self.cancelButton;
    if (cancelButton && buttons.count > 1) {
        if (self.axis == UILayoutConstraintAxisHorizontal) {
            // Cancel always on the left
            if (buttons.firstObject != cancelButton) {
                [self removeArrangedSubview:cancelButton];
                [self insertArrangedSubview:cancelButton atIndex:0];
            }
        }
        else {
            // Cancel always last
            if (buttons.lastObject != cancelButton) {
                [self removeArrangedSubview:cancelButton];
                [self addArrangedSubview:cancelButton];
            }
        }
    }

    [self.delegate actionsStackViewDidUpdateLayout:self];
}

- (void)contentSizeCategoryDidChangeNotification:(NSNotification *)notification {
    for (DWAlertViewActionButton *button in self.arrangedSubviews) {
        [button updateForCurrentContentSizeCategory];
    }

    [self updateButtonsLayout];
}

@end

NS_ASSUME_NONNULL_END