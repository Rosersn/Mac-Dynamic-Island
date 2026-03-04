<p align="center">
  <img src="DynamicIsland/Assets.xcassets/logo.imageset/Notchi.png" alt="Notchi logo" width="120" />
</p>

<h1 align="center">Notchi · AI 优先的 macOS Dynamic Island</h1>

<p align="center">
  先是 AI 助手，再是系统信息中枢。让刘海从“显示区”变成“操作区”。
</p>

<p align="center">
  <a href="https://github.com/Rosersn/Mac-Dynamic-Island">GitHub 仓库</a>
  ·
  <a href="https://github.com/Rosersn/Mac-Dynamic-Island/releases">Releases</a>
  ·
  <a href="https://github.com/Rosersn/Mac-Dynamic-Island/issues">问题反馈</a>
</p>

## 核心定位

Notchi 的核心不是把 iPhone 的 Dynamic Island 复刻到 Mac，而是把它做成一个随时可唤起的 AI 工作入口。  
你可以在刘海里直接和模型对话，也可以用悬浮面板快速完成高频任务。

## Notchi AI（Muse）能力

### 1) 多模型与多提供商

- 内置支持：Gemini、OpenAI、Claude、DeepSeek
- 本地模型：Ollama
- 兼容端点：Custom OpenAI Compatible（GLM/Kimi/Groq/SiliconFlow 等）
- 每个提供商可选不同模型，并支持切换思考模式（Thinking）

### 2) 两种 AI 交互形态

- 刘海内 `Notchi AI` 标签页
- 独立悬浮面板（默认 `Option+Space`，可启用双击 Option）
- 两种形态共享同一会话与模型设置

### 3) 面向真实工作的输入方式

- 文本提问
- 快速提示词（Quick Prompts）
- 自定义系统提示词（System Prompt）
- 文件附件（文档/图片/音频/视频）
- 截图输入（区域 / 窗口 / 全屏）
- 语音录音输入（自动保存为音频附件）

### 4) Agent 体验

- 流式输出
- Thinking 过程展示
- 工具调用过程可见（参数、结果、错误状态）
- 支持手动中断生成

### 5) 内置工具（当前版本）

- `take_screenshot`：让模型主动触发截图（area/window/full）
- `current_time`：获取当前本地时间（ISO8601 + 本地格式）

### 6) 会话与本地数据

- 会话按 JSON 持久化到本地 `Documents/MuseConversations`
- 录音与截图分别保存到本地 `Documents/MuseAudio`、`Documents/MuseScreenshots`

## 60 秒上手 AI

1. 打开设置 `Notchi AI`，启用功能
2. 选择 Provider 和 Model
3. 填入对应 API Key（或设置本地 Ollama 端点）
4. 用 `Option+Space` 打开 AI 面板
5. 输入问题，或直接截图/录音后发送

## AI 之外的能力

Notchi 依然保留完整的 Dynamic Island 生态能力：

- Live Activities：音乐、专注模式、隐私指示、下载、电池状态
- 锁屏组件：音乐、计时器、电池、蓝牙、天气、提醒事项
- 系统 HUD/OSD：音量、亮度、键盘背光增强提示
- 常用工具：计时器、剪贴板、取色器、日历与提醒事项
- 第三方扩展：Live Activities、锁屏组件、Notch 体验接入

## 预览

| 场景 | 预览 |
| --- | --- |
| Minimalistic | ![Minimalistic](.github/assets/Minimalistic-v1.2.gif) |
| Lock Screen | ![Lock Screen](.github/assets/lockscreen-v1.2.gif) |
| Focus / DND | ![DND](.github/assets/DND-v1.2.gif) |

## 系统要求

- macOS 14.0 及以上（推荐 macOS 15+）
- 带刘海屏幕的 MacBook 设备
- Xcode 15+（源码构建）

## 安装

### 方式一：下载发布版本

1. 打开 Releases：<https://github.com/Rosersn/Mac-Dynamic-Island/releases>
2. 下载最新安装包
3. 将应用拖入 `Applications`

### 方式二：源码构建

```bash
git clone https://github.com/Rosersn/Mac-Dynamic-Island.git
cd Mac-Dynamic-Island
open DynamicIsland.xcodeproj
```

## 首次运行权限

根据功能开关，应用可能请求：

- 辅助功能（Accessibility）
- 屏幕录制（截图与录屏相关能力）
- 麦克风（语音录音输入）
- 日历 / 提醒事项
- 音乐媒体控制相关权限
- 蓝牙（设备连接与电量状态）

## 贡献

- Bug 反馈：<https://github.com/Rosersn/Mac-Dynamic-Island/issues>
- 代码贡献：Fork 后发起 Pull Request

## 许可证

本项目基于 GPL-3.0 协议发布，详见 `LICENSE`。

---

由 Rose 制作
