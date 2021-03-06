// Copyright 2017 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FirebaseStorageInternal/Sources/FIRStorageMetadata_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageUpdateMetadataTask.h"
#import "FirebaseStorageInternal/Tests/Unit/FIRStorageTestHelpers.h"

@interface FIRStorageUpdateMetadataTests : XCTestCase

@property(strong, nonatomic) GTMSessionFetcherService *fetcherService;
@property(nonatomic) dispatch_queue_t dispatchQueue;
@property(strong, nonatomic) FIRIMPLStorageMetadata *metadata;
@property(strong, nonatomic) FIRIMPLStorage *storage;
@property(strong, nonatomic) id mockApp;

@end

@implementation FIRStorageUpdateMetadataTests

- (void)setUp {
  [super setUp];

  NSDictionary *metadataDict = @{@"bucket" : @"bucket", @"name" : @"path/to/object"};
  self.metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metadataDict];

  self.fetcherService = [[GTMSessionFetcherService alloc] init];
  self.fetcherService.authorizer =
      [[FIRStorageTokenAuthorizer alloc] initWithGoogleAppID:@"dummyAppID"
                                              fetcherService:self.fetcherService
                                                authProvider:nil
                                                    appCheck:nil];

  self.dispatchQueue = dispatch_queue_create("Test dispatch queue", DISPATCH_QUEUE_SERIAL);
  self.storage = [FIRStorageTestHelpers storageWithMockedApp];
}

- (void)tearDown {
  self.fetcherService = nil;
  self.storage = nil;
  self.mockApp = nil;
  [super tearDown];
}

- (void)testFetcherConfiguration {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testSuccessfulFetch"];

  self.fetcherService.testBlock =
      ^(GTMSessionFetcher *fetcher, GTMSessionFetcherTestResponse response) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        XCTAssertEqualObjects(fetcher.request.URL, [FIRStorageTestHelpers objectURL]);
        XCTAssertEqualObjects(fetcher.request.HTTPMethod, @"PATCH");
        NSData *bodyData = [NSData frs_dataFromJSONDictionary:[self.metadata updatedMetadata]];
        XCTAssertEqualObjects(fetcher.request.HTTPBody, bodyData);
        NSDictionary *HTTPHeaders = fetcher.request.allHTTPHeaderFields;
        XCTAssertEqualObjects(HTTPHeaders[@"Content-Type"], @"application/json; charset=UTF-8");
        XCTAssertEqualObjects(HTTPHeaders[@"Content-Length"], [@(bodyData.length) stringValue]);
#pragma clang diagnostic pop
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:fetcher.request.URL
                                                                      statusCode:200
                                                                     HTTPVersion:kHTTPVersion
                                                                    headerFields:nil];
        response(httpResponse, nil, nil);
        self.fetcherService.testBlock = nil;
      };

  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageUpdateMetadataTask *task = [[FIRStorageUpdateMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               metadata:self.metadata
             completion:^(FIRIMPLStorageMetadata *_Nullable metadata, NSError *_Nullable error) {
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testSuccessfulFetch {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testSuccessfulFetch"];

  self.fetcherService.testBlock = [FIRStorageTestHelpers successBlockWithMetadata:self.metadata];
  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageUpdateMetadataTask *task = [[FIRStorageUpdateMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               metadata:self.metadata
             completion:^(FIRIMPLStorageMetadata *_Nullable metadata, NSError *_Nullable error) {
               XCTAssertEqualObjects(self.metadata.bucket, metadata.bucket);
               XCTAssertEqualObjects(self.metadata.name, metadata.name);
               XCTAssertNil(error);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testUnsuccessfulFetchUnauthenticated {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnsuccessfulFetchUnauthenticated"];

  self.fetcherService.testBlock = [FIRStorageTestHelpers unauthenticatedBlock];
  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageUpdateMetadataTask *task = [[FIRStorageUpdateMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               metadata:self.metadata
             completion:^(FIRIMPLStorageMetadata *_Nullable metadata, NSError *_Nullable error) {
               XCTAssertNil(metadata);
               XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeUnauthenticated);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testUnsuccessfulFetchUnauthorized {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnsuccessfulFetchUnauthorized"];

  self.fetcherService.testBlock = [FIRStorageTestHelpers unauthorizedBlock];
  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageUpdateMetadataTask *task = [[FIRStorageUpdateMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               metadata:self.metadata
             completion:^(FIRIMPLStorageMetadata *_Nullable metadata, NSError *_Nullable error) {
               XCTAssertNil(metadata);
               XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeUnauthorized);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testUnsuccessfulFetchObjectDoesntExist {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnsuccessfulFetchObjectDoesntExist"];

  self.fetcherService.testBlock = [FIRStorageTestHelpers notFoundBlock];
  FIRStoragePath *path = [FIRStorageTestHelpers notFoundPath];
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageUpdateMetadataTask *task = [[FIRStorageUpdateMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               metadata:self.metadata
             completion:^(FIRIMPLStorageMetadata *_Nullable metadata, NSError *_Nullable error) {
               XCTAssertNil(metadata);
               XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeObjectNotFound);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testUnsuccessfulFetchBadJSON {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnsuccessfulFetchBadJSON"];

  self.fetcherService.testBlock = [FIRStorageTestHelpers invalidJSONBlock];
  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageUpdateMetadataTask *task = [[FIRStorageUpdateMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               metadata:self.metadata
             completion:^(FIRIMPLStorageMetadata *_Nullable metadata, NSError *_Nullable error) {
               XCTAssertNil(metadata);
               XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeUnknown);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

@end
