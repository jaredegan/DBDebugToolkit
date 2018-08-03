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

#import "DBRequestModel.h"
#import "DBRequestDataHandler.h"

static const NSInteger DBRequestModelBodyStreamBufferSize = 4096;

@interface DBRequestModel () <DBRequestDataHandlerDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) NSURLRequestCachePolicy cachePolicy;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, copy) NSString *httpMethod;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *allRequestHTTPHeaderFields;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, strong) NSDate *sendingDate;
@property (nonatomic, strong) NSDate *receivingDate;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, strong) DBRequestDataHandler *requestDataHandler;
@property (nonatomic, strong) DBRequestDataHandler *responseDataHandler;

@end

@implementation DBRequestModel

#pragma mark - Initialization

- (instancetype)initWithRequest:(NSURLRequest *)request {
    self = [super init];
    if (self) {
        _url = request.URL;
        self.cachePolicy = request.cachePolicy;
        self.timeoutInterval = request.timeoutInterval;
        _httpMethod = request.HTTPMethod;
        _allRequestHTTPHeaderFields = request.allHTTPHeaderFields;
        _sendingDate = [NSDate date];
    }
    
    return self;
}

+ (instancetype)requestModelWithRequest:(NSURLRequest *)request {
    return [[self alloc] initWithRequest:request];
}

#pragma mark - Saving body

- (void)saveBodyWithData:(NSData *)body inputStream:(NSInputStream *)bodyStream {
    NSData *bodyData = body;
    if ([bodyData length] == 0) {
        bodyData = [self dataFromInputStream:bodyStream];
    }
    
    [self saveRequestBody:bodyData];
}

- (NSData *)dataFromInputStream:(NSInputStream *)inputStream {
    uint8_t byteBuffer[DBRequestModelBodyStreamBufferSize];
    NSMutableData *mutableData = [NSMutableData data];
    [inputStream open];
    while (inputStream.hasBytesAvailable) {
        NSInteger bytesRead = [inputStream read:byteBuffer maxLength:sizeof(byteBuffer)];
        if (bytesRead == 0) {
            break;
        }
        [mutableData appendBytes:byteBuffer length:bytesRead];
    }
    return [mutableData copy];
}

#pragma mark - Saving outcome

- (void)saveOutcome:(DBRequestOutcome *)requestOutcome {
    if (requestOutcome.error != nil) {
        [self saveError:requestOutcome.error];
    } else {
        [self saveResponse:requestOutcome.response data:requestOutcome.data];
    }
}

- (void)saveError:(NSError *)error {
    [self finish];
    self.error = error;
}

- (void)saveResponse:(NSURLResponse *)response data:(NSData *)data {
    [self finish];
    self.response = response;
    [self saveResponseBody:data];
}

- (void)finish {
    self.finished = true;
    self.receivingDate = [NSDate date];
    self.duration = [self.receivingDate timeIntervalSinceDate:self.sendingDate];
}

#pragma mark - Saving body

- (NSString *)urlStringByRemovingSchemeFromURL:(NSURL *)url {
    NSRange dividerRange = [url.absoluteString rangeOfString:@"://"];
    return dividerRange.length == 0 ? url.absoluteString : [url.absoluteString substringFromIndex:NSMaxRange(dividerRange)];
}

- (NSString *)requestBodyFilename {
    return [NSString stringWithFormat:@"Request/%@_%@", [self urlStringByRemovingSchemeFromURL:self.url], @(self.sendingDate.timeIntervalSince1970)];
}

- (NSString *)responseBodyFilename {
    return [NSString stringWithFormat:@"Response/%@_%@", [self urlStringByRemovingSchemeFromURL:self.url], @(self.receivingDate.timeIntervalSince1970)];
}

- (void)saveRequestBody:(NSData *)data {
    self.requestDataHandler = [DBRequestDataHandler dataHandlerWithFilename:[self requestBodyFilename] data:data shouldGenerateThumbnail:NO];
    self.requestDataHandler.delegate = self;
}

- (void)saveResponseBody:(NSData *)data {
    self.responseDataHandler = [DBRequestDataHandler dataHandlerWithFilename:[self responseBodyFilename] data:data shouldGenerateThumbnail:YES];
    self.responseDataHandler.delegate = self;
}

#pragma mark - Accessing saved body

- (void)readRequestBodyWithCompletion:(void (^)(NSData *))completion {
    [self.requestDataHandler readWithCompletion:completion];
}

- (void)readResponseBodyWithCompletion:(void (^)(NSData *))completion {
    [self.responseDataHandler readWithCompletion:completion];
}

#pragma mark - Request properties 

- (NSInteger)requestBodyLength {
    return self.requestDataHandler.dataLength;
}

- (DBRequestModelBodyType)requestBodyType {
    return self.requestDataHandler.dataType;
}

- (DBRequestModelBodySynchronizationStatus)requestBodySynchronizationStatus {
    return self.requestDataHandler.synchronizationStatus;
}

#pragma mark - Response properties

- (NSInteger)responseBodyLength {
    return self.responseDataHandler.dataLength;
}

- (DBRequestModelBodyType)responseBodyType {
    return self.responseDataHandler.dataType;
}

- (NSHTTPURLResponse *)httpURLResponse {
    if ([self.response isKindOfClass:[NSHTTPURLResponse class]]) {
        return (NSHTTPURLResponse *)self.response;
    }
    return nil;
}

- (NSString *)MIMEType {
    return self.response.MIMEType;
}

- (NSString *)textEncodingName {
    return self.response.textEncodingName;
}

- (NSNumber *)statusCode {
    NSHTTPURLResponse *httpResponse = [self httpURLResponse];
    return httpResponse == nil ? nil : @(httpResponse.statusCode);
}

- (NSString *)localizedStatusCodeString {
    return [NSHTTPURLResponse localizedStringForStatusCode:self.statusCode.integerValue];
}

- (NSDictionary<NSString *, NSString *> *)allResponseHTTPHeaderFields {
    return [self httpURLResponse].allHeaderFields;
}

- (UIImage *)thumbnail {
    return self.responseDataHandler.thumbnail;
}

- (DBRequestModelBodySynchronizationStatus)responseBodySynchronizationStatus {
    return self.responseDataHandler.synchronizationStatus;
}

#pragma mark - Error properties

- (BOOL)didFinishWithError {
    return self.error != nil;
}

- (NSInteger)errorCode {
    return self.error.code;
}

- (NSString *)localizedErrorDescription {
    return self.error.localizedDescription;
}

#pragma mark - DBRequestDataHandlerDelegate

- (void)requestDataHandlerDidFinishSynchronization:(DBRequestDataHandler *)requestDataHandler {
    [self.delegate requestModelDidFinishSynchronization:self];
}

#pragma mark - Export
- (NSDictionary *)asDictionary {
    NSMutableDictionary *result = [@{} mutableCopy];

    result[@"url"] = self.url.absoluteString;
    NSString *cachePoliyString = @"";
    switch (self.cachePolicy) {
            case NSURLRequestUseProtocolCachePolicy:
            cachePoliyString = @"NSURLRequestUseProtocolCachePolicy";
            break;

            case NSURLRequestReloadIgnoringLocalCacheData:
            cachePoliyString = @"NSURLRequestReloadIgnoringLocalCacheData";
            break;

            case NSURLRequestReturnCacheDataElseLoad:
            cachePoliyString = @"NSURLRequestReturnCacheDataElseLoad";
            break;

            case NSURLRequestReturnCacheDataDontLoad:
            cachePoliyString = @"NSURLRequestReturnCacheDataDontLoad";
            break;

            case NSURLRequestReloadRevalidatingCacheData:
            cachePoliyString = @"NSURLRequestReloadRevalidatingCacheData";
            break;
    }
    result[@"cache_policy"] = cachePoliyString;

    result[@"timeout_interval"] = [[NSNumber numberWithDouble: self.timeoutInterval] stringValue];
    result[@"sending_date"] = [[NSNumber numberWithDouble: self.sendingDate.timeIntervalSince1970] stringValue];
    result[@"receiving_date"] = [[NSNumber numberWithDouble: self.receivingDate.timeIntervalSince1970] stringValue];
    result[@"http_method"] = self.httpMethod;
    result[@"http_headers"] = self.allRequestHTTPHeaderFields;
    result[@"request_body_length"] = [[NSNumber numberWithInt:self.requestBodyLength] stringValue];

    NSString *requestBodyType = @"";
    switch(self.requestBodyType) {
            case DBRequestModelBodyTypeJSON:
            requestBodyType = @"JSON";
            break;
            case DBRequestModelBodyTypeImage:
            requestBodyType = @"image";
            break;
            case DBRequestModelBodyTypeOther:
            requestBodyType = @"other";
            break;
    }
    result[@"request_body_type"] = requestBodyType;

    NSString *requestBodySynchronizationStatusString = @"";
    switch(self.requestBodySynchronizationStatus) {
            case DBRequestModelBodySynchronizationStatusNotStarted:
            requestBodySynchronizationStatusString = @"NotStarted";
            break;
            case DBRequestModelBodySynchronizationStatusStarted:
            requestBodySynchronizationStatusString = @"Started";
            break;
            case DBRequestModelBodySynchronizationStatusFinished:
            requestBodySynchronizationStatusString = @"Finished";
            break;
    }
    result[@"request_body_synchronization_status"] = requestBodyType;
    result[@"finished"] = self.finished ? @"true" : @"false";
    result[@"MIMEType"] = self.MIMEType;
    result[@"text_encoding_name"] = self.textEncodingName;
    result[@"duration"] = [[NSNumber numberWithDouble:self.duration] stringValue];
    result[@"status_code"] = [self.statusCode stringValue];
    result[@"localized_status_code"] = self.localizedStatusCodeString;
    result[@"response_http_headers"] = self.allResponseHTTPHeaderFields;
    result[@"response_body_length"] = [[NSNumber numberWithLong:self.responseBodyLength] stringValue];

    NSString *responseBodyTypeString = @"";
    switch(self.responseBodyType) {
            case DBRequestModelBodyTypeJSON:
            responseBodyTypeString = @"JSON";
            break;
            case DBRequestModelBodyTypeImage:
            responseBodyTypeString = @"image";
            break;
            case DBRequestModelBodyTypeOther:
            responseBodyTypeString = @"other";
            break;
    }
    result[@"response_body_type"] = responseBodyTypeString;

    NSString *responseBodySynchronizationStatusString = @"";
    switch(self.responseBodySynchronizationStatus) {
            case DBRequestModelBodySynchronizationStatusNotStarted:
            responseBodySynchronizationStatusString = @"NotStarted";
            break;
            case DBRequestModelBodySynchronizationStatusStarted:
            responseBodySynchronizationStatusString = @"Started";
            break;
            case DBRequestModelBodySynchronizationStatusFinished:
            responseBodySynchronizationStatusString = @"Finished";
            break;
    }
    result[@"response_body_synchronization_status"] = responseBodySynchronizationStatusString;

    result[@"did_finish_with_error"] = self.didFinishWithError ? @"true" : @"false";
    result[@"error_code"] = [[NSNumber numberWithLong:self.errorCode] stringValue];
    result[@"localized_error"] = self.localizedErrorDescription;

    return result;
}

@end
