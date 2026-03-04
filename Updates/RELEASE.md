# notchi 版本发布指南

本文档记录通过 Sparkle 框架发布 notchi 更新的完整流程。

## 前置条件

- macOS Keychain 中已存有 Sparkle EdDSA 私钥（首次由 `generate_keys` 生成）
- 已安装 Xcode 15+
- 有 `Rosersn/Mac-Dynamic-Island` 仓库的推送权限

## 密钥信息

| 项目 | 值 |
|---|---|
| 公钥（`SUPublicEDKey`） | `7dkF9xaNNFzaCs3flwM50rewNXMZwSYtXEjphqVf6Xs=` |
| 公钥位置 | `DynamicIsland/Info.plist` |
| 私钥位置 | macOS Keychain（自动读取） |
| 更新源 URL | `https://raw.githubusercontent.com/Rosersn/Mac-Dynamic-Island/main/Updates/appcast.xml` |

> 如果更换电脑，需要先从旧电脑的 Keychain 导出 Sparkle 私钥，再导入到新电脑。否则无法对 DMG 签名。

## Sparkle 工具路径

工具随 Sparkle SPM 依赖自动下载，位于 Xcode DerivedData 中：

```
~/Library/Developer/Xcode/DerivedData/DynamicIsland-<hash>/SourcePackages/artifacts/sparkle/Sparkle/bin/
```

主要用到两个工具：

- `generate_keys` — 生成 EdDSA 密钥对（仅首次使用）
- `sign_update` — 对 DMG 文件签名

## 发布流程

### 1. 更新版本号

编辑 `DynamicIsland.xcodeproj/project.pbxproj`，修改两处 `MARKETING_VERSION`（Debug 和 Release）：

```
MARKETING_VERSION = "1.4.0";
```

同时记下要递增的 `sparkle:version` 内部版本号（整数，当前最新为 `4`，下次用 `5`）。

### 2. 构建 Release

```bash
xcodebuild \
  -project DynamicIsland.xcodeproj \
  -scheme DynamicIsland \
  -configuration Release \
  -derivedDataPath /tmp/notchi-release \
  build
```

构建产物位于 `/tmp/notchi-release/Build/Products/Release/Notchi.app`。

### 3. 打包 DMG

```bash
hdiutil create \
  -volname "Notchi" \
  -srcfolder /tmp/notchi-release/Build/Products/Release/Notchi.app \
  -ov -format UDZO \
  Notchi.<版本号>.dmg
```

### 4. 签名 DMG

```bash
~/Library/Developer/Xcode/DerivedData/DynamicIsland-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update Notchi.<版本号>.dmg
```

输出示例：

```
sparkle:edSignature="CU5mJgb0rO2H..." length="5480837"
```

记录 `edSignature` 和 `length` 的值。

### 5. 更新 appcast.xml

在 `Updates/appcast.xml` 的 `<channel>` 内最顶部添加新 `<item>`：

```xml
<item>
    <title>1.4.0</title>
    <pubDate>Wed, 04 Mar 2026 12:00:00 +0800</pubDate>
    <sparkle:version>5</sparkle:version>
    <sparkle:shortVersionString>1.4.0</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>14.6</sparkle:minimumSystemVersion>
    <enclosure
        url="https://github.com/Rosersn/Mac-Dynamic-Island/releases/download/v1.4.0/Notchi.1.4.0.dmg"
        length="填入sign_update输出的length"
        type="application/octet-stream"
        sparkle:edSignature="填入sign_update输出的签名"/>
</item>
```

字段说明：

| 字段 | 含义 |
|---|---|
| `<title>` | 用户可见的版本名称 |
| `<pubDate>` | RFC 2822 格式的发布时间 |
| `sparkle:version` | 内部版本号（整数），每次发布必须递增，Sparkle 用此判断新旧 |
| `sparkle:shortVersionString` | 对外展示的版本号，与 `MARKETING_VERSION` 一致 |
| `sparkle:minimumSystemVersion` | 最低支持的 macOS 版本 |
| `enclosure url` | DMG 的下载地址，指向 GitHub Releases |
| `length` | DMG 文件大小（字节） |
| `sparkle:edSignature` | EdDSA 签名，由 `sign_update` 生成 |

### 6. 上传到 GitHub

1. 提交并推送代码（包括 `appcast.xml` 的更新）
2. 在 GitHub 仓库创建新 Release，tag 格式为 `v<版本号>`（如 `v1.4.0`）
3. 上传签名好的 DMG 文件作为 Release Asset

推送后 `appcast.xml` 会通过 `raw.githubusercontent.com` 自动生效，已安装的用户检查更新时即可获取新版本。

## 验证

发布后可在本地验证：

```bash
curl -s https://raw.githubusercontent.com/Rosersn/Mac-Dynamic-Island/main/Updates/appcast.xml
```

确认返回的 XML 包含最新版本的 item 且 URL、签名信息正确。

## 回滚

如果发现新版本有严重问题：

1. 从 `appcast.xml` 中删除或注释掉有问题的 `<item>`
2. 推送到 main 分支
3. 用户下次检查更新时会回退到上一个可用版本

## 版本历史

| 版本 | sparkle:version | 发布日期 | 备注 |
|---|---|---|---|
| 1.3.0-beta | 4 | 2026-01-31 | 首个 notchi 品牌版本，新 EdDSA 密钥 |
