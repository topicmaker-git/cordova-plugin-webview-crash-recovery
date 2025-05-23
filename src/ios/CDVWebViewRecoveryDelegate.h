#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@protocol CDVWebViewRecoveryDelegate <NSObject>

@required
- (void)webViewProcessDidTerminate:(WKWebView *)webView;
- (void)webViewHealthCheckFailed:(WKWebView *)webView;

@optional
- (void)webViewWillRecover:(WKWebView *)webView;
- (void)webViewDidRecover:(WKWebView *)webView;
- (void)webViewRecoveryFailed:(WKWebView *)webView error:(NSError *)error;

@end