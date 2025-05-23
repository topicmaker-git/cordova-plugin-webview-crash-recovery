/**
 * Cordova WebView Crash Recovery Plugin
 * Provides mechanisms to detect and recover from iOS WKWebView crashes
 */

var exec = require('cordova/exec');

/**
 * CrashRecovery plugin object
 */
var CrashRecovery = {
    
    /**
     * Manually trigger recovery process
     * 
     * @param {Function} [successCallback] - Called on successful recovery
     * @param {Function} [errorCallback] - Called if recovery fails
     */
    recover: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'WebViewCrashRecovery', 'recover', []);
    },
    
    /**
     * Check if the WebView is in a healthy state
     * 
     * @param {Function} callback - Called with boolean indicating health status
     */
    checkHealth: function(callback) {
        exec(callback, null, 'WebViewCrashRecovery', 'checkHealth', []);
    },
    
    /**
     * Trigger a test recovery (simulates crash and recovery)
     * 
     * @param {Function} [successCallback] - Called after test completes
     * @param {Function} [errorCallback] - Called if test fails
     */
    testRecovery: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'WebViewCrashRecovery', 'testRecovery', []);
    },
    
    /**
     * Start continuous monitoring with status updates
     * 
     * @param {Function} statusCallback - Called repeatedly with status updates
     */
    startMonitoring: function(statusCallback) {
        exec(statusCallback, null, 'WebViewCrashRecovery', 'startMonitoring', []);
    },
    
    /**
     * Debug message handler - used when LogToJavaScript=true in config
     * This can be overridden by the app to customize debug message handling
     * 
     * @param {string} message - Debug message from native side
     */
    onDebugMessage: function(message) {
        console.log('[CrashRecovery Debug]', message);
    }
};

// Auto-register crash event listener for convenience
document.addEventListener('DOMContentLoaded', function() {
    document.addEventListener('webviewcrashed', function(event) {
        console.warn('[CrashRecovery] WebView crashed: ' + (event.detail ? event.detail.reason : 'unknown reason'));
    });
    
    document.addEventListener('webviewwillrecover', function() {
        console.log('[CrashRecovery] WebView recovery starting');
    });
    
    document.addEventListener('webviewdidrecover', function() {
        console.log('[CrashRecovery] WebView recovered successfully');
    });
    
    document.addEventListener('webviewrecoveryfailed', function(event) {
        console.error('[CrashRecovery] WebView recovery failed: ' + 
                     (event.detail && event.detail.error ? event.detail.error : 'unknown error'));
    });
});

// Event documentation for TypeScript users
/**
 * WebView crashed event
 * @event webviewcrashed
 * @type {CustomEvent}
 * @property {Object} detail - Event details
 * @property {string} detail.reason - Reason for the crash (processTerminated, healthCheckFailed)
 */

/**
 * WebView will recover event
 * @event webviewwillrecover
 * @type {CustomEvent}
 */

/**
 * WebView did recover event
 * @event webviewdidrecover
 * @type {CustomEvent}
 */

/**
 * WebView recovery failed event
 * @event webviewrecoveryfailed
 * @type {CustomEvent}
 * @property {Object} detail - Event details
 * @property {string} detail.error - Error message
 */

module.exports = CrashRecovery;