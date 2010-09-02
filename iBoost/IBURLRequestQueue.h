//
// Copyright 2009-2010 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class IBURLRequest;

@interface IBURLRequestQueue : NSObject {
  NSMutableDictionary*  _loaders;
  NSMutableArray*       _loaderQueue;
  NSTimer*              _loaderQueueTimer;
  NSInteger             _totalLoading;
  NSUInteger            _maxContentLength;
  NSString*             _userAgent;
  CGFloat               _imageCompressionQuality;
  BOOL                  _suspended;
}

/**
 * Gets the flag that determines if new load requests are allowed to reach the network.
 *
 * Because network requests tend to slow down performance, this property can be used to
 * temporarily delay them.  All requests made while suspended are queued, and when 
 * suspended becomes false again they are executed.
 */
@property(nonatomic) BOOL suspended;

/**
 * The maximum size of a download that is allowed.
 *
 * If a response reports a content length greater than the max, the download will be
 * cancelled. This is helpful for preventing excessive memory usage. Setting this to 
 * zero will allow all downloads regardless of size.
 *
 * @default 150000 bytes
 */
@property(nonatomic) NSUInteger maxContentLength;

/**
 * The user-agent string that is sent with all HTTP requests.
 *
 * @default Mozilla/5.0 (iPhone; U; CPU iPhone OS 2_2 like Mac OS X;\
 *          en-us) AppleWebKit/525.181 (KHTML, like Gecko) Version/3.1.1 Mobile/5H11 Safari/525.20
 */
@property(nonatomic,copy) NSString* userAgent;

/**
 * The compression quality used for encoding images sent with HTTP posts.
 *
 * @default 0.75
 */
@property(nonatomic) CGFloat imageCompressionQuality;

/**
 * Get the shared cache singleton used across the application.
 */
+ (IBURLRequestQueue*)mainQueue;

/**
 * Set the shared cache singleton used across the application.
 */
+ (void)setMainQueue:(IBURLRequestQueue*)queue;

/**
 * Load a request from the cache or the network if it is not in the cache.
 *
 * @return YES if the request was loaded synchronously from the cache.
 */
- (BOOL)sendRequest:(IBURLRequest*)request;

/**
 * Synchronously load a request from the cache or the network if it is not in the cache.
 *
 * @return YES if the request was loaded from the cache.
 */
- (BOOL)sendSynchronousRequest:(IBURLRequest*)request;

/**
 * Cancel a request that is in progress.
 */
- (void)cancelRequest:(IBURLRequest*)request;

/**
 * Cancel all active or pending requests whose delegate or response is an object.
 *
 * This is useful for when an object is about to be destroyed and you want to remove pointers
 * to it from active requests to prevent crashes when those pointers are later referenced.
 */
- (void)cancelRequestsWithDelegate:(id)delegate;

/**
 * Cancel all active or pending requests.
 */
- (void)cancelAllRequests;

/**
 * Create a Cocoa URL request from a Three20 URL request.
 */
- (NSURLRequest*)createNSURLRequest:(IBURLRequest*)request URL:(NSURL*)URL;

@end