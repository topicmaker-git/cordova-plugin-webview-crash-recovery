# Cordova WebView Crash Recovery Plugin

このCordovaプラグインは、iOS WKWebViewがバックグラウンドで強制終了された後の「白画面」問題を解決します。長時間のバックグラウンド状態やメモリ不足によりWKWebViewプロセスが終了した場合に、自動的に検出して回復する機能を提供します。

[English version](README.md)

## 背景

iOS版Cordovaアプリにおいて、WKWebViewが10分程度バックグラウンドに放置されると、フォアグラウンド復帰時に白画面（クラッシュ）になる深刻な問題が発生することがあります。これは以下の原因によります：

1. **WKWebViewプロセスの独立性**: WKWebViewは別プロセスで動作するため、メインアプリとは独立してkillされる
2. **iOSのメモリ管理**: バックグラウンド時にiOSがWKWebContentプロセスを強制終了
3. **クラッシュリカバリーの欠如**: Cordova iOS 6.0以降、WKWebViewが本体統合されたが、重要なクラッシュリカバリー機能が実装されていない

このプラグインは、WKWebViewのクラッシュを複数の方法で検出し、自動的に回復させる機能を提供します。

## 特徴

- **多層防御戦略**: 複数の方法でWKWebViewクラッシュを検出
  - 公式API `webViewWebContentProcessDidTerminate` の利用
  - バックグラウンド復帰時の健全性チェック
  - 定期的な監視による検出
- **安全な回復メカニズム**: 無限ループ防止、状態保存、選択的回復
- **WebView完全再作成機能**: 必要に応じてWebViewを再構築（Cordova WebViewEngineの完全再初期化）
- **状態復元機能**: URL、スクロール位置、LocalStorageの保存と復元
- **JavaScript API**: 手動回復、健全性チェック、イベントリスナー
- **デバッグ機能**: デバッグモード、ログ出力、アラート表示

## インストール

```bash
cordova plugin add cordova-plugin-webview-crash-recovery
```

## 設定オプション

`config.xml` で以下の設定が可能です：

```xml
<!-- 基本設定 -->
<preference name="CrashRecoveryEnabled" value="true" />
<preference name="CrashRecoveryMethod" value="recreate" /> <!-- reload | recreate -->
<preference name="HealthCheckInterval" value="10" />
<preference name="RecoveryDelay" value="1.0" />
<preference name="BackupLocalStorage" value="false" /> <!-- LocalStorageのバックアップと復元 -->

<!-- デバッグ設定 -->
<preference name="CrashRecoveryDebugMode" value="false" />
<preference name="CrashRecoveryDebugLevel" value="basic" /> <!-- silent | basic | verbose -->
<preference name="ShowDebugAlerts" value="false" />
<preference name="LogToJavaScript" value="false" />
```

## JavaScript API

### 手動回復トリガー

```javascript
cordova.plugins.crashRecovery.recover(function() {
    console.log('Recovery successful');
}, function(error) {
    console.error('Recovery failed', error);
});
```

### 健全性チェック

```javascript
cordova.plugins.crashRecovery.checkHealth(function(isHealthy) {
    console.log('WebView health status:', isHealthy ? 'healthy' : 'unhealthy');
    if (!isHealthy) {
        // 回復処理
        cordova.plugins.crashRecovery.recover();
    }
});
```

### テスト用API

```javascript
// 回復プロセスをテスト（クラッシュをシミュレート）
cordova.plugins.crashRecovery.testRecovery();

// WebView状態の継続的モニタリング
cordova.plugins.crashRecovery.startMonitoring(function(status) {
    console.log('WebView status:', status);
});
```

### イベントリスナー

```javascript
// WebViewがクラッシュした時
document.addEventListener('webviewcrashed', function(event) {
    console.log('WebView crashed, reason:', event.detail.reason);
});

// 回復プロセス開始時
document.addEventListener('webviewwillrecover', function() {
    console.log('WebView recovery starting');
});

// 回復プロセス完了時
document.addEventListener('webviewdidrecover', function() {
    console.log('WebView recovery completed');
});

// 回復プロセス失敗時
document.addEventListener('webviewrecoveryfailed', function(event) {
    console.error('WebView recovery failed:', event.detail.error);
});
```

## デバッグ

デバッグモードを有効にすると、ネイティブからJavaScriptにデバッグ情報が送信されます：

```javascript
// デバッグメッセージのカスタムハンドラ
cordova.plugins.crashRecovery.onDebugMessage = function(message) {
    console.log('[CrashRecovery]', message);
    
    // デバッグ情報をUI表示
    var debugOutput = document.getElementById('debug-output');
    if (debugOutput) {
        debugOutput.innerHTML += message + '<br>';
    }
};
```

## 状態保存と復元

バックグラウンド移行時やクラッシュ検出時に、以下の状態が自動的に保存されます：

1. **現在のURL**: WebViewが表示しているページのURL
2. **スクロール位置**: 現在のページのスクロール位置
3. **LocalStorage**: `BackupLocalStorage`が有効な場合、LocalStorageの内容も保存（※大量のデータがある場合はパフォーマンスに影響する可能性があります）

復旧時に、これらの状態が自動的に復元されます。

## 互換性

- iOS 12.0以降
- Cordova iOS 6.0以降
- Cordova CLI 12.x以降

## テスト

このプラグインは実機での動作検証が必要です。以下のシナリオでテストしてください：

1. アプリ起動 → 10分バックグラウンド → フォアグラウンド復帰
2. メモリ不足状態でのカメラプラグイン使用
3. 大容量ファイル読み込み中のバックグラウンド移行

## トラブルシューティング

### デバッグモードの有効化

問題が発生した場合は、デバッグモードを有効にすることで詳細な情報が得られます：

```xml
<preference name="CrashRecoveryDebugMode" value="true" />
<preference name="CrashRecoveryDebugLevel" value="verbose" />
<preference name="ShowDebugAlerts" value="true" />
<preference name="LogToJavaScript" value="true" />
```

### 回復方法の切り替え

クラッシュが頻繁に発生する場合、`recreate`モードを使用してください：

```xml
<preference name="CrashRecoveryMethod" value="recreate" />
```

このモードでは、WebViewを完全に再作成し、Cordovaエンジンも再初期化します。

## ライセンス

MIT