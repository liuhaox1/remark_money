# 统一字体样式规范

## 字体配置

应用使用 **Noto Sans SC** 作为主字体，所有文本样式都通过 `Theme.of(context).textTheme` 访问。

## 文本样式映射

### 标题样式
- **headlineLarge** (28px, w800) - 超大标题，如金额显示
- **headlineMedium** (24px, w700) - 大标题
- **titleLarge** (18px, w700) - 页面主标题
- **titleMedium** (16px, w600) - 卡片标题、对话框标题
- **titleSmall** (14px, w500) - 小节标题

### 正文样式
- **bodyLarge** (14px, w500) - 正文大
- **bodyMedium** (12px, w500) - 正文中（默认）
- **bodySmall** (11px, w500) - 正文小、辅助文本

### 标签样式
- **labelLarge** (12px, w500) - 标签大
- **labelMedium** (11px, w500) - 标签中

## 使用方式

### 方式1：直接使用主题样式
```dart
Text(
  '标题',
  style: Theme.of(context).textTheme.titleMedium,
)
```

### 方式2：使用扩展方法（推荐）
```dart
import '../utils/text_style_extensions.dart';

Text(
  '标题',
  style: context.titleMediumStyle,
)
```

### 方式3：带颜色或字重调整
```dart
Text(
  '文本',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Colors.red,
    fontWeight: FontWeight.w600,
  ),
)
```

## 禁止事项

❌ **不要**硬编码字体大小和字重：
```dart
// 错误示例
Text('标题', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))
```

✅ **应该**使用主题样式：
```dart
// 正确示例
Text('标题', style: Theme.of(context).textTheme.titleMedium)
```

## 常见场景映射

| 场景 | 应使用的样式 |
|------|------------|
| 页面主标题 | `titleLarge` |
| 卡片标题 | `titleMedium` |
| 表单标签 | `bodyLarge` (w600) |
| 正文内容 | `bodyMedium` |
| 辅助说明 | `bodySmall` |
| 金额显示 | `headlineLarge` 或 `headlineMedium` |
| 按钮文本 | `bodyMedium` 或 `labelLarge` |

