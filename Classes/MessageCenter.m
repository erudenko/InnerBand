//
//  MessageCenter.m
//  Message
//
//  Created by John Blanco on 3/5/10.
//  Copyright 2010 Effective UI. All rights reserved.
//

#import "MessageCenter.h"
#import "DispatchMessage.h"
#import "MessageProcessor.h"
#import "NSObject+Boost.h"

@interface MessageCenter (private)

+ (NSMutableArray *)getTargetActionsForMessageName:(NSString *)name source:(NSObject *)source;
+ (NSMutableArray *)getTargetActionsForMessageName:(NSString *)name sourceDescription:(NSString *)sourceDescription;

@end

// (Source: MemAddr|Null) -> (Name) -> ([Target/Actions])
static NSMutableDictionary *_messageListeners = nil;

// debugging
static BOOL _debuggingEnabled = NO;

NSString *getSourceIdentifier(NSObject *obj) {
	return [NSString stringWithFormat:@"%p", obj];
}

@implementation MessageCenter

+ (NSInteger)getCountOfListeningSources {
	return [_messageListeners count];
}

+ (void)setDebuggingEnabled:(BOOL)enabled {
	_debuggingEnabled = enabled;
}

+ (BOOL)isDebuggingEnabled {
	return _debuggingEnabled;
}

#pragma mark -

+ (void)initialize {
	_messageListeners = [[NSMutableDictionary alloc] init];
}

#pragma mark -

+ (void)addGlobalMessageListener:(NSString *)name target:(NSObject *)target action:(SEL)action {
	[MessageCenter addMessageListener:name source:nil target:target action:action];
}

+ (void)addMessageListener:(NSString *)name source:(NSObject *)source target:(NSObject *)target action:(SEL)action {
	// remove existing listener (avoids duplication)
	[MessageCenter removeMessageListener:name source:source target:target action:action];
	
	// add listener
	NSMutableArray *targetActions = [MessageCenter getTargetActionsForMessageName:name source:source];
	NSDictionary *targetAction = [NSDictionary dictionaryWithObjectsAndKeys:target, @"target", NSStringFromSelector(action), @"action", nil]; 
	[targetActions addObject:targetAction];
}

#pragma mark -

+ (void)removeMessageListener:(NSString *)name source:(NSObject *)source target:(NSObject *)target action:(SEL)action {
	NSMutableArray *targetActions = [MessageCenter getTargetActionsForMessageName:name source:source];
	
	// remove all matching target/action pairs
	for (NSInteger i = targetActions.count - 1; i >= 0; --i) {
		NSDictionary *iDictionary = (NSDictionary *)[targetActions objectAtIndex:i];
		NSObject *iTarget = (NSObject *)[iDictionary objectForKey:@"target"];
		
		// remove if matched
		if (iTarget == target) {
			SEL iAction = NSSelectorFromString((NSString *)[iDictionary objectForKey:@"action"]);
			
			if (iAction == action) {
				[targetActions removeObjectAtIndex:i];
			}
		}
	}
}

+ (void)removeMessageListener:(NSString *)name source:(NSObject *)source target:(NSObject *)target {
	NSMutableArray *targetActions = [MessageCenter getTargetActionsForMessageName:name source:source];
	
	// remove all matching targets
	for (NSInteger i = targetActions.count - 1; i >= 0; --i) {
		NSDictionary *iDictionary = (NSDictionary *)[targetActions objectAtIndex:i];
		NSObject *iTarget = (NSObject *)[iDictionary objectForKey:@"target"];
		
		// remove if matched
		if (iTarget == target) {
			[targetActions removeObjectAtIndex:i];
		}
	}
}

+ (void)removeMessageListener:(NSString *)name target:(NSObject *)target action:(SEL)action {
	for (NSMutableDictionary *iMessageNames in _messageListeners) {
		for (NSMutableArray *iTargetActions in iMessageNames) {
			// remove all matching target/action pairs
			for (NSInteger i = iTargetActions.count - 1; i >= 0; --i) {
				NSDictionary *iDictionary = (NSDictionary *)[iTargetActions objectAtIndex:i];
				NSObject *iTarget = (NSObject *)[iDictionary objectForKey:@"target"];
				
				// remove if matched
				if (iTarget == target) {
					SEL iAction = NSSelectorFromString((NSString *)[iDictionary objectForKey:@"action"]);
					
					if (iAction == action) {
						[iTargetActions removeObjectAtIndex:i];
					}
				}
			}
		}
	}
}

+ (void)removeMessageListenersForTarget:(NSObject *)target {
	for (NSString *iSourceDescription in _messageListeners) {
		NSMutableDictionary *targetActionsByName = [_messageListeners objectForKey:iSourceDescription];
		for (NSString *iTargetActionName in targetActionsByName) {
			NSMutableArray *iTargetActions = [targetActionsByName objectForKey:iTargetActionName];
			
			// remove all matching target/action pairs
			for (NSInteger i = iTargetActions.count - 1; i >= 0; --i) {
				NSDictionary *iDictionary = (NSDictionary *)[iTargetActions objectAtIndex:i];
				NSObject *iTarget = (NSObject *)[iDictionary objectForKey:@"target"];
				
				// remove if matched
				if (iTarget == target) {
					[iTargetActions removeObjectAtIndex:i];
				}
			}
		}
	}
}

#pragma mark -

+ (void)sendGlobalMessageNamed:(NSString *)name {
	[MessageCenter sendMessageNamed:name forSource:nil];
}

+ (void)sendGlobalMessageNamed:(NSString *)name withUserInfo:(NSDictionary *)userInfo {
	[MessageCenter sendMessageNamed:name withUserInfo:userInfo forSource:nil];
}

+ (void)sendGlobalMessage:(DispatchMessage *)message {
	[MessageCenter sendMessage:message forSource:nil];
}

+ (void)sendMessageNamed:(NSString *)name forSource:(NSObject *)source {
	DispatchMessage *message = [DispatchMessage messageWithName:name userInfo:nil];
	
	// dispatch
	[MessageCenter sendMessage:message forSource:source];
}

+ (void)sendMessageNamed:(NSString *)name withUserInfo:(NSDictionary *)userInfo forSource:(NSObject *)source {
	DispatchMessage *message = [DispatchMessage messageWithName:name userInfo:userInfo];
	
	// dispatch
	[MessageCenter sendMessage:message forSource:source];
}

+ (void)sendMessage:(DispatchMessage *)message forSource:(NSObject *)source {
	// global or local delivery only
	NSArray *targetActions = [MessageCenter getTargetActionsForMessageName:message.name source:source];
	
	// process message (this object will autorelease itself when done)
	if (message.isAsynchronous) {
		MessageProcessor *processor = [[[MessageProcessor alloc] init] autorelease];

		[processor performSelectorInBackground:@selector(processInThread:targetActions:) withObject:message withObject:targetActions];
	} else {
		MessageProcessor *processor = [[MessageProcessor alloc] initWithMessage:message targetActions:targetActions];

		[processor process];
		[processor release];
	}
}


#pragma mark -

+ (NSMutableArray *)getTargetActionsForMessageName:(NSString *)name source:(NSObject *)source {
	// if no source given, treat as global listener (use self as key)
	if (!source) {
		source = [NSNull null];
	}
	
	return [self.class getTargetActionsForMessageName:name sourceDescription:getSourceIdentifier(source)];
}

+ (NSMutableArray *)getTargetActionsForMessageName:(NSString *)name sourceDescription:(NSString *)sourceDescription {
	NSMutableDictionary *messageNames = [_messageListeners objectForKey:sourceDescription];
	
	// add a new dictionary if there isn't one
	if (!messageNames) {
		[_messageListeners setObject:(messageNames = [NSMutableDictionary dictionary]) forKey:sourceDescription];
	}
	
	NSMutableArray *targetActions = [messageNames objectForKey:name];
	
	// add a new array if there isn't one
	if (!targetActions) {
		[messageNames setObject:(targetActions = [NSMutableArray array]) forKey:name];
	}
	
	return targetActions;
}

@end
