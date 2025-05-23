#import "WebViewCrashRecovery.h"
#import <Cordova/CDVViewController.h>

@implementation WebViewCrashRecovery

#pragma mark - Plugin Lifecycle

- (void)pluginInitialize {
    NSLog(@"WebViewCrashRecovery: Plugin initializing");
    
    // 少し遅延させて初期化を行う（UIの準備ができた後に）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self delayedPluginInitialize];
    });
}

- (void)delayedPluginInitialize {
    @try {
        // Get plugin preferences from config.xml using helper methods
        self.debugModeEnabled = [self getBoolSetting:@"CrashRecoveryDebugMode" defaultValue:NO];
        self.debugLevel = [self getStringSetting:@"CrashRecoveryDebugLevel" defaultValue:@"basic"];
        self.showDebugAlerts = [self getBoolSetting:@"ShowDebugAlerts" defaultValue:NO];
        self.logToJavaScript = [self getBoolSetting:@"LogToJavaScript" defaultValue:NO];
        self.healthCheckInterval = [self getDoubleSetting:@"HealthCheckInterval" defaultValue:10.0];
        self.recoveryDelay = [self getDoubleSetting:@"RecoveryDelay" defaultValue:1.0];
        self.recoveryMethod = [self getStringSetting:@"CrashRecoveryMethod" defaultValue:@"reload"];
        
        BOOL recoveryEnabled = [self getBoolSetting:@"CrashRecoveryEnabled" defaultValue:YES];
        
        NSLog(@"WebViewCrashRecovery: Plugin initialized with settings: recoveryEnabled=%@, debugMode=%@, debugLevel=%@, showAlerts=%@, logToJS=%@, healthInterval=%f, recoveryDelay=%f, recoveryMethod=%@", 
             recoveryEnabled ? @"YES" : @"NO",
             self.debugModeEnabled ? @"YES" : @"NO",
             self.debugLevel,
             self.showDebugAlerts ? @"YES" : @"NO",
             self.logToJavaScript ? @"YES" : @"NO",
             self.healthCheckInterval,
             self.recoveryDelay,
             self.recoveryMethod);
        
        if (!recoveryEnabled) {
            NSLog(@"WebViewCrashRecovery: Crash recovery is disabled in config.xml. Plugin will not monitor WebView.");
            return;
        }
        
        // Get reference to the WKWebView using Cordova's built-in reference
        self.wkWebView = (WKWebView*)self.webView;
        
        if (!self.wkWebView || ![self.wkWebView isKindOfClass:[WKWebView class]]) {
            NSLog(@"WebViewCrashRecovery: ERROR: WebView is not a WKWebView instance. Recovery will not work.");
            return;
        }
    } @catch (NSException *exception) {
        NSLog(@"WebViewCrashRecovery: Exception during initialization: %@", exception.reason);
        return;
    }
    
    // Save original delegate and set self as delegate
    self.originalNavigationDelegate = self.wkWebView.navigationDelegate;
    self.wkWebView.navigationDelegate = self;
    
    [self logDebug:@"Successfully got reference to WKWebView"];
    
    // Start monitoring
    [self setupMonitoring];
}

- (void)onReset {
    [self logDebug:@"Plugin reset - reinitializing monitoring"];
    [self stopMonitoring];
    
    // Re-establish the WebView reference
    self.wkWebView = (WKWebView*)self.webView;
    
    if (self.wkWebView) {
        // Re-establish delegate
        self.originalNavigationDelegate = self.wkWebView.navigationDelegate;
        self.wkWebView.navigationDelegate = self;
        
        [self setupMonitoring];
    }
}

- (void)onAppTerminate {
    [self stopMonitoring];
}

#pragma mark - Setup Methods

- (void)setupMonitoring {
    @try {
        // Register for app lifecycle notifications
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleAppWillEnterForeground:) 
                                                     name:UIApplicationWillEnterForegroundNotification 
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleAppDidBecomeActive:) 
                                                     name:UIApplicationDidBecomeActiveNotification 
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleAppWillResignActive:) 
                                                     name:UIApplicationWillResignActiveNotification 
                                                   object:nil];
        
        // 少し遅延させてからヘルスチェックを開始する
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self startHealthMonitoring];
        });
        
        NSLog(@"WebViewCrashRecovery: WebView monitoring setup complete");
    } @catch (NSException *exception) {
        NSLog(@"WebViewCrashRecovery: Exception during setup monitoring: %@", exception.reason);
    }
}

- (void)stopMonitoring {
    // Unregister from notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Stop timer
    [self.monitorTimer invalidate];
    self.monitorTimer = nil;
    
    [self logDebug:@"WebView monitoring stopped"];
}

#pragma mark - WKNavigationDelegate Methods

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    [self logDebug:@"WKWebView process terminated, initiating recovery..."];
    
    // Call our delegate method
    [self webViewProcessDidTerminate:webView];
}

// Forward delegate methods to original delegate
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // Forward to original delegate
    if (self.originalNavigationDelegate && 
        [self.originalNavigationDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [self.originalNavigationDelegate webView:webView didFinishNavigation:navigation];
    }
    
    // Own processing
    [self logDebug:@"WebView navigation finished"];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    // Forward to original delegate
    if (self.originalNavigationDelegate && 
        [self.originalNavigationDelegate respondsToSelector:@selector(webView:didFailNavigation:withError:)]) {
        [self.originalNavigationDelegate webView:webView didFailNavigation:navigation withError:error];
    }
    
    // Own processing
    [self logDebug:[NSString stringWithFormat:@"WebView navigation failed: %@", error.localizedDescription]];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    // Forward to original delegate
    if (self.originalNavigationDelegate && 
        [self.originalNavigationDelegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
        [self.originalNavigationDelegate webView:webView didStartProvisionalNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    // Forward to original delegate
    if (self.originalNavigationDelegate && 
        [self.originalNavigationDelegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)]) {
        [self.originalNavigationDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
    }
    
    [self logDebug:[NSString stringWithFormat:@"WebView provisional navigation failed: %@", error.localizedDescription]];
}

#pragma mark - CDVWebViewRecoveryDelegate Methods

- (void)webViewProcessDidTerminate:(WKWebView *)webView {
    [self fireJavaScriptEvent:@"webviewcrashed" withData:@{@"reason": @"processTerminated"}];
    
    [self performSelectorOnMainThread:@selector(safeWebViewRecovery) 
                           withObject:nil 
                        waitUntilDone:NO];
}

- (void)webViewHealthCheckFailed:(WKWebView *)webView {
    [self fireJavaScriptEvent:@"webviewcrashed" withData:@{@"reason": @"healthCheckFailed"}];
    
    [self performSelectorOnMainThread:@selector(safeWebViewRecovery) 
                           withObject:nil 
                        waitUntilDone:NO];
}

- (void)webViewWillRecover:(WKWebView *)webView {
    [self fireJavaScriptEvent:@"webviewwillrecover" withData:@{}];
}

- (void)webViewDidRecover:(WKWebView *)webView {
    [self fireJavaScriptEvent:@"webviewdidrecover" withData:@{}];
}

- (void)webViewRecoveryFailed:(WKWebView *)webView error:(NSError *)error {
    [self fireJavaScriptEvent:@"webviewrecoveryfailed" withData:@{
        @"error": error.localizedDescription ?: @"Unknown error"
    }];
}

#pragma mark - App Lifecycle Handlers

- (void)handleAppWillEnterForeground:(NSNotification*)notification {
    [self logDebug:@"App will enter foreground"];
}

- (void)handleAppDidBecomeActive:(NSNotification*)notification {
    [self logDebug:@"App did become active - scheduling health check"];
    
    // When app becomes active, check WebView health after a short delay
    [self performSelector:@selector(checkWebViewHealth) 
               withObject:nil 
               afterDelay:self.recoveryDelay];
}

- (void)handleAppWillResignActive:(NSNotification*)notification {
    [self logDebug:@"App will resign active"];
    
    // App is going to background, take a snapshot of important state
    [self backupWebViewState];
}

#pragma mark - Health Monitoring

- (void)startHealthMonitoring {
    @try {
        [self.monitorTimer invalidate];
        self.monitorTimer = nil;
        
        // タイマーの前に一度手動でヘルスチェックを実行する（初回はエラーを無視）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                // 初回のヘルスチェックを静かに実行
                [self checkWebViewHealthSilently];
                
                // その後、通常のタイマーを開始する
                self.monitorTimer = [NSTimer scheduledTimerWithTimeInterval:self.healthCheckInterval
                                                                    target:self
                                                                  selector:@selector(checkWebViewHealth)
                                                                  userInfo:nil
                                                                   repeats:YES];
                
                NSLog(@"WebViewCrashRecovery: Health monitoring started with interval: %f seconds", self.healthCheckInterval);
            } @catch (NSException *exception) {
                NSLog(@"WebViewCrashRecovery: Exception during initial health check: %@", exception.reason);
            }
        });
    } @catch (NSException *exception) {
        NSLog(@"WebViewCrashRecovery: Exception during health monitoring start: %@", exception.reason);
    }
}

// 静かにヘルスチェックを実行する（エラーを報告しない）
- (void)checkWebViewHealthSilently {
    if (self.isRecovering) {
        return;
    }
    
    // 基本的なヘルスチェック（エラー報告なし）
    if (!self.wkWebView) {
        NSLog(@"WebViewCrashRecovery: Silent health check: WebView is nil");
        return;
    } 
    
    if (!self.wkWebView.URL) {
        NSLog(@"WebViewCrashRecovery: Silent health check: WebView has no URL");
        return;
    }
    
    if ([self.wkWebView.URL.absoluteString isEqualToString:@"about:blank"]) {
        NSLog(@"WebViewCrashRecovery: Silent health check: WebView showing about:blank");
        return;
    }
    
    NSLog(@"WebViewCrashRecovery: Silent health check passed");
}

- (void)checkWebViewHealth {
    if (self.isRecovering) {
        [self logDebug:@"Recovery in progress, skipping health check"];
        return;
    }
    
    [self logDebug:@"Performing WebView health check"];
    
    // Basic health checks
    BOOL isHealthy = YES;
    
    // 1. Check if WebView is nil
    if (!self.wkWebView) {
        [self logDebug:@"Health check failed: WebView is nil"];
        isHealthy = NO;
    } 
    // 2. Check if WebView has a valid URL
    else if (!self.wkWebView.URL) {
        [self logDebug:@"Health check failed: WebView has no URL"];
        isHealthy = NO;
    }
    // 3. Check if WebView is responsive
    else if ([self.wkWebView.URL.absoluteString isEqualToString:@"about:blank"]) {
        [self logDebug:@"Health check failed: WebView showing about:blank"];
        isHealthy = NO;
    }
    
    // Only report health check failure if we're not in middle of loading
    if (!isHealthy && !self.wkWebView.isLoading) {
        [self webViewHealthCheckFailed:self.wkWebView];
    } else {
        [self logDebug:@"WebView health check passed"];
    }
}

#pragma mark - Recovery Methods

- (void)safeWebViewRecovery {
    if (self.isRecovering) {
        [self logDebug:@"Recovery already in progress, skipping..."];
        return;
    }
    
    // Prevent rapid recovery attempts
    static NSTimeInterval lastRecoveryTime = 0;
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    if (currentTime - lastRecoveryTime < 5.0) {
        [self logDebug:@"Recovery attempt too soon, skipping..."];
        return;
    }
    lastRecoveryTime = currentTime;
    
    self.isRecovering = YES;
    
    [self logDebug:@"Starting WebView recovery process"];
    [self webViewWillRecover:self.wkWebView];
    
    @try {
        // State backup already done on background, but ensure we have latest
        [self backupWebViewState];
        
        // Choose recovery method
        if ([self shouldRecreateWebView]) {
            [self logDebug:@"Using 'recreate' recovery method"];
            [self recreateWebView];
        } else {
            [self logDebug:@"Using 'reload' recovery method"];
            [self.wkWebView reload];
        }
        
        [self webViewDidRecover:self.wkWebView];
    }
    @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"WebViewCrashRecovery" 
                                             code:500 
                                         userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Unknown recovery error"}];
        
        [self logDebug:[NSString stringWithFormat:@"Recovery failed with error: %@", exception.reason]];
        [self webViewRecoveryFailed:self.wkWebView error:error];
    }
    @finally {
        self.isRecovering = NO;
    }
}

- (BOOL)shouldRecreateWebView {
    // If explicitly specified in config, use that
    if ([self.recoveryMethod isEqualToString:@"recreate"]) {
        return YES;
    }
    
    if ([self.recoveryMethod isEqualToString:@"reload"]) {
        return NO;
    }
    
    // Auto decision: recreate if the WebView seems completely unresponsive
    return (self.wkWebView == nil || [self.wkWebView.URL.absoluteString isEqualToString:@"about:blank"]);
}

- (void)recreateWebView {
    [self logDebug:@"Starting WebView recreation due to process termination"];
    
    // CDVWebViewEngineを通じた正式な再作成
    if ([self.viewController isKindOfClass:[CDVViewController class]]) {
        CDVViewController *cdvVC = (CDVViewController *)self.viewController;
        
        // 現在のURL、状態を保存
        NSString *currentURL = self.wkWebView.URL.absoluteString;
        
        // 既存のwebViewEngineを取得
        id webViewEngine = [cdvVC valueForKey:@"webViewEngine"];
        
        if (webViewEngine) {
            // エンジンクラスを取得
            Class engineClass = [webViewEngine class];
            
            // 新しいエンジンインスタンスを作成
            id newEngine = [[engineClass alloc] init];
            
            // 新しいエンジンを初期化
            if ([newEngine respondsToSelector:@selector(pluginInitialize)]) {
                [newEngine performSelector:@selector(pluginInitialize)];
                
                // 古いエンジンの削除（メモリリーク防止）
                if ([webViewEngine respondsToSelector:@selector(destroy)]) {
                    [webViewEngine performSelector:@selector(destroy)];
                }
                
                // 新しいエンジンを設定
                [cdvVC setValue:newEngine forKey:@"webViewEngine"];
                
                // 新しいWKWebViewの参照を取得
                if ([newEngine respondsToSelector:@selector(engineWebView)]) {
                    id engineWebView = [newEngine performSelector:@selector(engineWebView)];
                    if ([engineWebView isKindOfClass:[WKWebView class]]) {
                        self.wkWebView = (WKWebView *)engineWebView;
                        
                        // デリゲートを再設定
                        self.originalNavigationDelegate = self.wkWebView.navigationDelegate;
                        self.wkWebView.navigationDelegate = self;
                        
                        // 元のURLを復元
                        if (currentURL && ![currentURL isEqualToString:@"about:blank"]) {
                            [self.wkWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:currentURL]]];
                        } else {
                            // 保存されたURLから復元
                            [self restoreWebViewState];
                        }
                        
                        [self logDebug:@"WebView recreation completed successfully"];
                        return;
                    }
                }
            }
        }
    }
    
    // フォールバック: 従来の方法
    [self logDebug:@"Using fallback recreation method"];
    [self recreateWebViewFallback];
}

- (void)recreateWebViewFallback {
    // Get the original webview's parent view and frame
    UIView *parentView = self.wkWebView.superview;
    CGRect frame = self.wkWebView.frame;
    
    // Remove current webview
    [self.wkWebView removeFromSuperview];
    
    // Create new webview configuration
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    
    // Create new webview
    WKWebView *newWebView = [[WKWebView alloc] initWithFrame:frame configuration:config];
    
    // Keep the original delegate reference
    self.originalNavigationDelegate = newWebView.navigationDelegate;
    
    // Set self as delegate
    newWebView.navigationDelegate = self;
    
    // Add to parent view
    [parentView addSubview:newWebView];
    
    // Update our reference
    self.wkWebView = newWebView;
    
    // Restore state
    [self restoreWebViewState];
    
    [self logDebug:@"WebView recreated using fallback method"];
}

- (void)backupWebViewState {
    if (!self.wkWebView || !self.wkWebView.URL) {
        return;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Save current URL
    [defaults setObject:self.wkWebView.URL.absoluteString forKey:@"WebViewCrashRecovery_LastURL"];
    
    // Save scroll position
    [self.wkWebView evaluateJavaScript:@"window.pageYOffset" 
                     completionHandler:^(id result, NSError *error) {
        if (!error && result) {
            [defaults setObject:result forKey:@"WebViewCrashRecovery_ScrollY"];
        }
    }];
    
    // Save localStorage data if enabled
    if ([self getBoolSetting:@"BackupLocalStorage" defaultValue:NO]) {
        [self.wkWebView evaluateJavaScript:@"JSON.stringify(localStorage)" 
                        completionHandler:^(id result, NSError *error) {
            if (!error && result) {
                [defaults setObject:result forKey:@"WebViewCrashRecovery_LocalStorage"];
            }
        }];
    }
    
    [defaults synchronize];
    [self logDebug:@"WebView state backed up"];
}

- (void)restoreWebViewState {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Restore URL
    NSString *urlString = [defaults objectForKey:@"WebViewCrashRecovery_LastURL"];
    if (urlString) {
        NSURL *url = [NSURL URLWithString:urlString];
        [self.wkWebView loadRequest:[NSURLRequest requestWithURL:url]];
        
        // Restore scroll position after page load
        NSNumber *scrollY = [defaults objectForKey:@"WebViewCrashRecovery_ScrollY"];
        if (scrollY) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *js = [NSString stringWithFormat:@"window.scrollTo(0, %@);", scrollY];
                [self.wkWebView evaluateJavaScript:js completionHandler:nil];
            });
        }
        
        // Restore localStorage if it was backed up
        NSString *localStorageData = [defaults objectForKey:@"WebViewCrashRecovery_LocalStorage"];
        if (localStorageData && [self getBoolSetting:@"BackupLocalStorage" defaultValue:NO]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *js = [NSString stringWithFormat:@"try { const data = JSON.parse('%@'); for (const key in data) { localStorage.setItem(key, data[key]); } } catch(e) { console.error('Failed to restore localStorage', e); }", 
                                [localStorageData stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]];
                [self.wkWebView evaluateJavaScript:js completionHandler:nil];
            });
        }
        
        [self logDebug:[NSString stringWithFormat:@"WebView state restored: %@", urlString]];
    } else {
        // Fallback: try to load index.html
        NSString *wwwPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"www"];
        NSString *indexPath = [wwwPath stringByAppendingPathComponent:@"index.html"];
        NSURL *indexURL = [NSURL fileURLWithPath:indexPath];
        [self.wkWebView loadRequest:[NSURLRequest requestWithURL:indexURL]];
        
        [self logDebug:@"Loaded fallback index.html"];
    }
}

#pragma mark - Cordova API Methods

- (void)recover:(CDVInvokedUrlCommand*)command {
    [self logDebug:@"Manual recovery triggered from JavaScript"];
    
    [self.commandDelegate runInBackground:^{
        [self safeWebViewRecovery];
        
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

- (void)checkHealth:(CDVInvokedUrlCommand*)command {
    [self logDebug:@"Health check triggered from JavaScript"];
    
    [self.commandDelegate runInBackground:^{
        // Do a basic health check
        BOOL isHealthy = (self.wkWebView != nil && 
                          self.wkWebView.URL != nil && 
                          ![self.wkWebView.URL.absoluteString isEqualToString:@"about:blank"]);
        
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                       messageAsBool:isHealthy];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

- (void)testRecovery:(CDVInvokedUrlCommand*)command {
    [self logDebug:@"Test recovery triggered from JavaScript"];
    
    [self.commandDelegate runInBackground:^{
        // Simulate a crash and recovery
        [self webViewProcessDidTerminate:self.wkWebView];
        
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

- (void)startMonitoring:(CDVInvokedUrlCommand*)command {
    [self logDebug:@"Start monitoring with callback triggered from JavaScript"];
    
    // Keep the callback for continuous status updates
    NSString *callbackId = command.callbackId;
    
    __weak WebViewCrashRecovery *weakSelf = self;
    self.monitorTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        WebViewCrashRecovery *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        // Prepare status report
        NSDictionary *status = @{
            @"url": strongSelf.wkWebView.URL.absoluteString ?: @"",
            @"title": strongSelf.wkWebView.title ?: @"",
            @"isLoading": @(strongSelf.wkWebView.isLoading),
            @"canGoBack": @(strongSelf.wkWebView.canGoBack),
            @"timestamp": @([[NSDate date] timeIntervalSince1970])
        };
        
        // Send status update
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                 messageAsDictionary:status];
        [result setKeepCallbackAsBool:YES];
        [strongSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
    }];
}

#pragma mark - Helper Methods

- (void)fireJavaScriptEvent:(NSString *)eventName withData:(NSDictionary *)data {
    if (!eventName) {
        return;
    }
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data ?: @{} 
                                                       options:0 
                                                         error:&error];
    if (error) {
        [self logDebug:[NSString stringWithFormat:@"Error serializing event data: %@", error.localizedDescription]];
        return;
    }
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *js = [NSString stringWithFormat:@"document.dispatchEvent(new CustomEvent('%@', { detail: %@ }));", 
                    eventName, jsonString];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.wkWebView evaluateJavaScript:js completionHandler:nil];
    });
}

#pragma mark - Configuration Helper Methods

- (BOOL)getBoolSetting:(NSString *)key defaultValue:(BOOL)defaultValue {
    NSString *value = [self.commandDelegate.settings objectForKey:[key lowercaseString]];
    return value ? [value boolValue] : defaultValue;
}

- (double)getDoubleSetting:(NSString *)key defaultValue:(double)defaultValue {
    NSString *value = [self.commandDelegate.settings objectForKey:[key lowercaseString]];
    return value ? [value doubleValue] : defaultValue;
}

- (NSString *)getStringSetting:(NSString *)key defaultValue:(NSString *)defaultValue {
    NSString *value = [self.commandDelegate.settings objectForKey:[key lowercaseString]];
    return value ?: defaultValue;
}

#pragma mark - Debug Methods

- (BOOL)isDebugModeEnabled {
    return self.debugModeEnabled;
}

- (void)logDebug:(NSString*)message {
    NSLog(@"WebViewCrashRecovery: %@", message);
    
    // Send to JavaScript if enabled
    if (self.logToJavaScript) {
        NSString *escapedMessage = [message stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
        NSString *js = [NSString stringWithFormat:@"if (cordova && cordova.plugins && cordova.plugins.crashRecovery && typeof cordova.plugins.crashRecovery.onDebugMessage === 'function') { cordova.plugins.crashRecovery.onDebugMessage('%@'); }", escapedMessage];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.wkWebView evaluateJavaScript:js completionHandler:nil];
        });
    }
    
    // Show alert if enabled and it's not a routine message
    if (self.showDebugAlerts && ![self.debugLevel isEqualToString:@"silent"] && 
        ![message containsString:@"health check passed"]) {
        [self showDebugAlert:message];
    }
}

- (void)showDebugAlert:(NSString*)message {
    // Only show alerts in verbose mode or if explicitly requested
    if (!self.showDebugAlerts && ![self.debugLevel isEqualToString:@"verbose"]) {
        return;
    }
    
    // 初期化時やアプリ起動直後のアラート表示は避ける
    static BOOL isFirstAlert = YES;
    if (isFirstAlert) {
        isFirstAlert = NO;
        NSLog(@"WebViewCrashRecovery: Skipping first alert to prevent crash: %@", message);
        return;
    }
    
    // UIアプリケーションの状態チェック
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        NSLog(@"WebViewCrashRecovery: App not active, skipping alert: %@", message);
        return;
    }
    
    // 安全にアラートを表示
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIAlertController *alert = [UIAlertController 
                                       alertControllerWithTitle:@"WebView Recovery Debug" 
                                       message:message 
                                       preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *okAction = [UIAlertAction 
                                      actionWithTitle:@"OK" 
                                      style:UIAlertActionStyleDefault 
                                      handler:nil];
            
            [alert addAction:okAction];
            
            UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
            if (rootVC && !rootVC.presentedViewController) {
                [rootVC presentViewController:alert animated:YES completion:nil];
            } else {
                NSLog(@"WebViewCrashRecovery: Cannot present alert, no suitable view controller");
            }
        } @catch (NSException *exception) {
            NSLog(@"WebViewCrashRecovery: Exception while showing alert: %@", exception.reason);
        }
    });
}

- (void)reportWebViewStatus {
    if (!self.wkWebView) {
        [self logDebug:@"WebView status: NULL reference"];
        return;
    }
    
    NSMutableString *status = [[NSMutableString alloc] init];
    [status appendFormat:@"Title: %@\n", self.wkWebView.title ?: @"(null)"];
    [status appendFormat:@"URL: %@\n", self.wkWebView.URL.absoluteString ?: @"(null)"];
    [status appendFormat:@"Loading: %@\n", self.wkWebView.isLoading ? @"YES" : @"NO"];
    [status appendFormat:@"CanGoBack: %@\n", self.wkWebView.canGoBack ? @"YES" : @"NO"];
    
    [self logDebug:[NSString stringWithFormat:@"WebView status: %@", status]];
    
    if (self.showDebugAlerts) {
        [self showDebugAlert:status];
    }
}

@end