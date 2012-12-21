//
//  IRRecurrenceMachine.m
//  IRRecurrenceMachine
//
//  Created by Evadne Wu on 11/4/11.
//  Copyright (c) 2011 Iridia Productions. All rights reserved.
//

#import "IRRecurrenceMachine.h"

@interface IRRecurrenceMachine ()

@property (nonatomic, readwrite, retain) NSOperationQueue *queue;
@property (nonatomic, readwrite, retain) NSArray *recurringOperations;
@property (nonatomic, readwrite, retain) NSTimer *timer;
@property (nonatomic, readwrite, assign) NSInteger postponingRequestCount;

@end


@implementation IRRecurrenceMachine

@synthesize queue, recurrenceInterval, recurringOperations, postponingRequestCount;
@synthesize timer;

- (id) init {
  
  return [self initWithQueue:nil];
  
}

- (id) initWithQueue:(NSOperationQueue *)aQueue {
  
  self = [super init];
  if (!self)
    return nil;
  
  queue = aQueue ? aQueue : [[NSOperationQueue alloc] init];
  recurrenceInterval = 30;
  recurringOperations = [NSArray array];
  
  [self timer];
  
  return self;
  
}

- (void) addRecurringOperation:(NSOperation<NSCopying> *)anOperation {
  
  NSParameterAssert(![self.recurringOperations containsObject:anOperation]);
  
  [[self mutableArrayValueForKey:@"recurringOperations"] addObject:anOperation];
  
}

- (void) setRecurrenceInterval:(NSTimeInterval)newInterval {
  
  if (recurrenceInterval == newInterval)
    return;
  
  [self willChangeValueForKey:@"recurrenceInterval"];
  
  recurrenceInterval = newInterval;
  
  [self didChangeValueForKey:@"recurrenceInterval"];
  
  [timer invalidate];
  timer = nil;
  
  if (![self isPostponingOperations])
    [self timer];
  
}

- (NSTimer *) timer {
  
  if (timer)
    return timer;
  
  timer = [NSTimer scheduledTimerWithTimeInterval:self.recurrenceInterval target:self selector:@selector(handleTimerFire:) userInfo:nil repeats:YES];
  
  return timer;
  
}

- (void) handleTimerFire:(NSTimer *)aTimer {
  
  NSParameterAssert(![self isPostponingOperations]);
  
  [self scheduleOperationsNow];
  
}

- (BOOL) scheduleOperationsNow {
  
  if (self.queue.operationCount)
    return NO;
  
  [self beginPostponingOperations];

  [self.recurringOperations enumerateObjectsUsingBlock: ^ (NSOperation *operationPrototype, NSUInteger idx, BOOL *stop) {
    
    NSOperation *operation = [operationPrototype copy];
    [queue addOperation:operation];
    
  }];

  __weak IRRecurrenceMachine *wSelf = self;
  NSOperation *tailOp = [NSBlockOperation blockOperationWithBlock:^{
    [wSelf endPostponingOperations];
  }];

  for (NSOperation *operation in queue.operations) {
    [tailOp addDependency:operation];
  }
  [queue addOperation:tailOp];
  
  return YES;
  
}

- (void) beginPostponingOperations {
  
  if (![NSThread isMainThread]) {
    __weak IRRecurrenceMachine *wSelf = self;
    dispatch_sync(dispatch_get_main_queue(), ^{
      [wSelf beginPostponingOperations];
    });
    return;
  }

  self.postponingRequestCount += 1;
  
  if (postponingRequestCount == 1) {
    
    [self.timer invalidate];
    self.timer = nil;
    
  }
  
}

- (void) endPostponingOperations {
  
  if (![NSThread isMainThread]) {
    __weak IRRecurrenceMachine *wSelf = self;
    dispatch_sync(dispatch_get_main_queue(), ^{
      [wSelf endPostponingOperations];
    });
    return;
  }
  
  NSParameterAssert(postponingRequestCount > 0);
  
  self.postponingRequestCount -= 1;
  
  if (!postponingRequestCount) {
    
    [self timer];
    
  }
  
}

- (BOOL) isPostponingOperations {
  
  return !!(self.postponingRequestCount);
  
}

@end
