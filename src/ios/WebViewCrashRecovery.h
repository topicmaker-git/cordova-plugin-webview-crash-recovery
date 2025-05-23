#import <Cordova/CDVPlugin.h>
#import <WebKit/WebKit.h>
#import "CDVWebViewRecoveryDelegate.h"

@interface WebViewCrashRecovery : CDVPlugin <WKNavigationDelegate, CDVWebViewRecoveryDelegate>

@property (nonatomic, strong) WKWebView *wkWebView;
@property (nonatomic, weak) id<WKNavigationDelegate> originalNavigationDelegate;
@property (nonatomic, strong) NSTimer *monitorTimer;
@property (nonatomic, assign) BOOL isRecovering;
@property (nonatomic, assign) BOOL debugModeEnabled;
@property (nonatomic, copy) NSString *debugLevel;
@property (nonatomic, assign) BOOL showDebugAlerts;
@property (nonatomic, assign) BOOL logToJavaScript;
@property (nonatomic, assign) NSTimeInterval healthCheckInterval;
@property (nonatomic, assign) NSTimeInterval recoveryDelay;
@property (nonatomic, copy) NSString *recoveryMethod;

// Plugin JavaScript API methods
- (void)recover:(CDVInvokedUrlCommand*)command;
- (void)checkHealth:(CDVInvokedUrlCommand*)command;
- (void)testRecovery:(CDVInvokedUrlCommand*)command;
- (void)startMonitoring:(CDVInvokedUrlCommand*)command;

// WebView recovery methods
- (void)safeWebViewRecovery;
- (void)checkWebViewHealth;
- (BOOL)shouldRecreateWebView;
- (void)recreateWebView;
- (void)recreateWebViewFallback;
- (void)backupWebViewState;
- (void)restoreWebViewState;

// Configuration helpers
- (BOOL)getBoolSetting:(NSString *)key defaultValue:(BOOL)defaultValue;
- (double)getDoubleSetting:(NSString *)key defaultValue:(double)defaultValue;
- (NSString *)getStringSetting:(NSString *)key defaultValue:(NSString *)defaultValue;

// Debug methods
- (void)logDebug:(NSString*)message;
- (void)showDebugAlert:(NSString*)message;
- (void)reportWebViewStatus;
- (BOOL)isDebugModeEnabled;

@end