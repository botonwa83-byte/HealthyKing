# GitHub Pages 托管说明（隐私政策 / 用户协议 / 技术支持）

> 当前仓库未发现 `docs/` 静态页面。App Store Connect 提交前必须先让隐私政策 URL 可公开访问。

## 建议 URL

如果仓库名使用 `KingFit`，建议托管后使用：

| 用途 | 链接 |
|------|------|
| 首页 / 营销页 | `https://botonwa83-byte.github.io/KingFit/` |
| 隐私政策 | `https://botonwa83-byte.github.io/KingFit/privacy.html` |
| 用户协议 | `https://botonwa83-byte.github.io/KingFit/terms.html` |
| 技术支持 | `https://botonwa83-byte.github.io/KingFit/support.html` |

如果 GitHub 仓库实际名称不是 `KingFit`，请把 URL 中的路径改成真实仓库名，并保持 ASC、App 内链接和网页链接大小写一致。

## 建议创建的文件

```text
docs/
  index.html
  privacy.html
  terms.html
  support.html
```

内容来源：

- `privacy.html`：使用 `02_隐私政策_PrivacyPolicy.md` 的正文。
- `terms.html`：使用 `03_用户协议_EULA.md` 的正文。
- `support.html`：至少包含 App 名称、版本、联系邮箱、常见问题和 HealthKit 权限管理说明。
- `index.html`：可选，简短介绍 App，并链接隐私政策、用户协议、技术支持。

## GitHub Pages 启用步骤

1. 把 `docs/` 目录提交并推送到 GitHub 默认分支。
2. 打开仓库 Settings → Pages。
3. “Build and deployment” → Source 选 **Deploy from a branch**。
4. Branch 选默认分支（通常是 `main`），目录选 **/docs**。
5. 保存后等待 1-2 分钟构建完成。
6. 用浏览器或 `curl -I` 确认以下 URL 返回 200：

```sh
curl -I https://botonwa83-byte.github.io/KingFit/privacy.html
curl -I https://botonwa83-byte.github.io/KingFit/terms.html
curl -I https://botonwa83-byte.github.io/KingFit/support.html
```

## support.html 建议内容

```text
KingFit 技术支持

如需帮助，请联系：
botonwa83@gmail.com

常见问题：
1. 如何管理健康数据权限？
   打开 iOS 健康 App → 右上角头像 → App → KingFit，或在 KingFit 设置页点击“打开系统健康App隐私设置”。

2. 为什么没有数据显示？
   请确认设备支持 HealthKit，已授权读取相关数据，并且健康 App 中已有 Apple Watch 或其他来源记录的数据。部分指标需要连续积累多天后才会显示趋势。

3. App 是否提供医疗建议？
   不提供。本应用仅供一般健康与运动趋势参考，不用于诊断、治疗、治愈或预防任何疾病。

4. 是否收费？
   当前版本完全免费，无内购、无订阅。
```

## 提醒

- 隐私政策 URL 是 App Store Connect 必填项，不可填本地文件或不可访问页面。
- 健康类 App 的隐私政策必须明确 HealthKit 数据用途、是否上传、是否用于广告/营销、如何撤销权限。
- 如果未来改了仓库名或 Pages 路径，ASC 中的 URL 也要同步更新。
