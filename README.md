# Cordova WebView Crash Recovery Plugin

This Cordova plugin solves the "white screen" issue that occurs after iOS WKWebView processes are terminated in the background. It provides automatic detection and recovery when WKWebView processes terminate due to extended background state or memory pressure.

[日本語版](README.ja.md)

## Background

iOS Cordova applications can experience a serious issue where WKWebView shows a white screen (crash) when returning to the foreground after being in the background for about 10 minutes. This occurs due to:

1. **WKWebView process independence**: WKWebView runs in a separate process that can be killed independently from the main app
2. **iOS memory management**: iOS may terminate WKWebContent processes when in the background
3. **Lack of crash recovery**: While Cordova iOS 6.0+ integrates WKWebView, it lacks critical crash recovery functionality

This plugin detects WKWebView crashes through multiple methods and provides automatic recovery.

## Features

- **Multi-layered detection strategy**: Detects WKWebView crashes through multiple methods
  - Official API `webViewWebContentProcessDidTerminate`
  - Health checks on background-to-foreground transitions
  - Periodic monitoring
- **Safe recovery mechanisms**: Infinite loop prevention, state preservation, selective recovery
- **Complete WebView recreation**: Rebuilds WebView when necessary (complete re-initialization of Cordova WebViewEngine)
- **State restoration**: Preserves and restores URL, scroll position, and LocalStorage
- **JavaScript API**: Manual recovery triggers, health checks, and event listeners
- **Debugging capabilities**: Debug mode, logging, and alert displays

## Installation

```bash
cordova plugin add cordova-plugin-webview-crash-recovery
```

## Configuration Options

Configure in `config.xml`:

```xml
<!-- Basic Settings -->
<preference name="CrashRecoveryEnabled" value="true" />
<preference name="CrashRecoveryMethod" value="recreate" /> <!-- reload | recreate -->
<preference name="HealthCheckInterval" value="10" />
<preference name="RecoveryDelay" value="1.0" />
<preference name="BackupLocalStorage" value="false" /> <!-- Backup and restore LocalStorage -->

<!-- Debug Settings -->
<preference name="CrashRecoveryDebugMode" value="false" />
<preference name="CrashRecoveryDebugLevel" value="basic" /> <!-- silent | basic | verbose -->
<preference name="ShowDebugAlerts" value="false" />
<preference name="LogToJavaScript" value="false" />
```

## JavaScript API

### Manual Recovery Trigger

```javascript
cordova.plugins.crashRecovery.recover(function() {
    console.log('Recovery successful');
}, function(error) {
    console.error('Recovery failed', error);
});
```

### Health Check

```javascript
cordova.plugins.crashRecovery.checkHealth(function(isHealthy) {
    console.log('WebView health status:', isHealthy ? 'healthy' : 'unhealthy');
    if (!isHealthy) {
        // Initiate recovery
        cordova.plugins.crashRecovery.recover();
    }
});
```

### Test API

```javascript
// Test recovery process (simulate crash)
cordova.plugins.crashRecovery.testRecovery();

// Continuous monitoring of WebView state
cordova.plugins.crashRecovery.startMonitoring(function(status) {
    console.log('WebView status:', status);
});
```

### Event Listeners

```javascript
// When WebView crashes
document.addEventListener('webviewcrashed', function(event) {
    console.log('WebView crashed, reason:', event.detail.reason);
});

// When recovery process starts
document.addEventListener('webviewwillrecover', function() {
    console.log('WebView recovery starting');
});

// When recovery process completes
document.addEventListener('webviewdidrecover', function() {
    console.log('WebView recovery completed');
});

// When recovery process fails
document.addEventListener('webviewrecoveryfailed', function(event) {
    console.error('WebView recovery failed:', event.detail.error);
});
```

## Debugging

When debug mode is enabled, debug information is sent from native to JavaScript:

```javascript
// Custom handler for debug messages
cordova.plugins.crashRecovery.onDebugMessage = function(message) {
    console.log('[CrashRecovery]', message);
    
    // Display debug info in UI
    var debugOutput = document.getElementById('debug-output');
    if (debugOutput) {
        debugOutput.innerHTML += message + '<br>';
    }
};
```

## State Preservation and Restoration

The following states are automatically saved when transitioning to background or detecting a crash:

1. **Current URL**: The URL displayed in the WebView
2. **Scroll position**: Current page scroll position
3. **LocalStorage**: If `BackupLocalStorage` is enabled, LocalStorage contents are also saved (Note: may impact performance if large amounts of data are stored)

These states are automatically restored during recovery.

## Compatibility

- iOS 12.0+
- Cordova iOS 6.0+
- Cordova CLI 12.x+

## Testing

This plugin requires physical device testing. Test with these scenarios:

1. App launch → 10 minutes in background → foreground return
2. Camera plugin usage under low memory conditions
3. Background transition during large file loading

## Troubleshooting

### Enable Debug Mode

For detailed information when issues occur, enable debug mode:

```xml
<preference name="CrashRecoveryDebugMode" value="true" />
<preference name="CrashRecoveryDebugLevel" value="verbose" />
<preference name="ShowDebugAlerts" value="true" />
<preference name="LogToJavaScript" value="true" />
```

### Switch Recovery Method

If crashes occur frequently, use the `recreate` mode:

```xml
<preference name="CrashRecoveryMethod" value="recreate" />
```

This mode completely recreates the WebView and reinitializes the Cordova engine.

## License

MIT