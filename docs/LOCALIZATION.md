# 界面语言维护

本分支提供英文和简体中文，在「设置 → 通用 → 界面语言」中选择跟随系统、English 或简体中文。选择保存在 `interface.language`，重启后生效；语言切换不会修改其他设置、书签或快捷键标识。

- `Sources/SearcheXtra/Resources/Translations.json` 保存两套界面文案。每个稳定键都必须包含 `en` 和 `zh-Hans`。
- Swift 界面、AppKit 菜单和提示统一使用 `L10n.text`。动态内容使用 `{0}`、`{1}` 等占位符，传入内容只替换一次，避免用户文本被再次解释。
- 网页标题、书签名称、扩展名称、存储键、协议标识和网址保留原始内容，不作为界面文案翻译。
- `Localization/en.lproj/InfoPlist.strings` 和 `Localization/zh-Hans.lproj/InfoPlist.strings` 保存系统权限说明。
- `build.sh` 同时打包 SwiftPM 资源 bundle 和两种语言的权限资源。切换语言通过应用自己的 `AppleLanguages` 偏好影响系统菜单，不修改 macOS 全局语言。
- GitHub Actions 的 `Bilingual interface checks` 检查语言选择、英文回退、动态文本格式及 ARM64 应用资源。现有 Release 工作流也会构建包含两套翻译的安装包。

新增功能时使用明确的新翻译键，并同时填写英文与中文。不要根据用户输入生成翻译键，也不要改动已发布的键以免误用旧翻译。
