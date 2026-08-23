# Cloudflare 验证绕过 — 需求、解决思路与备选方案

> 项目：`E:\Project\comic`（Flutter 漫画爬虫 App）
> 调试环境：真机 PLC110（Android 16 / API 36），Flutter 3.44.6，Dart 3.12.2，`webview_flutter` ^4.14.1
> 文档日期：2026-08-22

---

## 一、背景与需求

目标站开启了 Cloudflare 防护（Turnstile / "Just a moment" 拦截页，HTTP 层返回 `403` + `cf-mitigated: challenge`）。App 的本质工作是**抓取该站 HTML 并解析**（列表 / 详情 / 搜索 / 图片），因此必须绕过这道验证。

目标域名是一个 **IDN / punycode 域名**：

```
xn--ej1-mxgmxgcom-yp8ve33bkpevz1kpxq.mxgmxgcom.com
```

用户的明确需求（来自多轮反馈）：

1. **能抓到数据**：App 列表 / 详情 / 搜索 / 图片都能正常解析并展示。
2. **真机可验证**：在 Android 真机上，WebView 能完成人机验证；关闭后**页面上能看到数据**。
3. **不能无限循环**：验证失败/卡住时，不能反复弹 WebView 形成死循环。
4. **要有可用旁路**：当 WebView 在该环境下确实过不去时，提供"导入 `cf_clearance`"等办法让爬虫仍能用。
5. **状态可持久化**：验证得到的 clearance cookie 跨 App 重启仍有效，避免每次启动都验证。

---

## 二、排查过程与根因（7 个问题，层层递进）

| # | 现象 | 根因 | 修复 |
|---|------|------|------|
| 1 | WebView 一直循环验证、无法过去 | 该 IDN 域名下 Turnstile JS 抛 `SecurityError`（`replaceState` / `postMessage` origin 不匹配），渲染进程崩溃（`code -1`），WebRTC STUN `errorcode: -105` 失败 → `cf_clearance` 永远写不进去 | `_failedHosts` + 冷却 + 90s 兜底打断循环 |
| 2 | 验证"成功"关掉后仍没数据 | `cf_clearance` 是 **HttpOnly**，`document.cookie` 读不到 → `CloudflareCookieJar` 从未存到它 → Dart 请求缺 cookie 被拦 | 改用 `WebViewCookieManager().getCookies()` 读平台 cookie 仓库 |
| 3 | 9 秒兜底误抓挑战页 | `_check()` 在 `elapsed>8` 强制取数，但挑战页文本尚未渲染，`runJavaScriptReturningResult` 误判为"非挑战" → `fetch` 抓回 6KB 挑战页当数据 → 解析 `!` 崩溃 | 仅当确认取回**真实内容**才关闭 WebView |
| 4 | 列表/详情图片全空白 | 图片请求头只有 `referer`+`UA`，缺 `cf_clearance` → 同域图片被 Cloudflare 拦（403） | 新增 `imageHeadersFor()`，图片请求也附带 cookie |
| 5 | 首页 4 个 tab 互相挤掉 | `ComicChapter.initState` 并发发 4 个请求；首个触发验证时其余 3 个被 `_solving` 守卫直接返回 null → 抛异常 → 3 个 tab 显示"错误/重试" | `CloudflareSolver` 用 `_currentSolve` Completer 让并发请求**等待同一次验证、只复用 cookie** |
| 6 | 按返回键时崩溃 | `Get.showSnackbar` 在路由返回/转场时 GetX 全局 Overlay 缺失 → `No Overlay widget found` | 改用 `ScaffoldMessenger.of(context)` + `mounted` 守卫 |
| 7 | **整个 App 渲染不出来（致命）** | 为做"常驻 WebView 桥接"，把 `CloudflareBridgeOverlay` 的 `Stack` 包在 `GetMaterialApp` **外层** → `Stack` 缺 `Directionality`（由 MaterialApp 提供）→ 构建抛 `No Directionality widget found` → 整个 UI 树渲染失败，**首页请求根本没发出**（所以一条 `[CF]` 日志都没有，表现为"没数据"） | 把 overlay 移进 `GetMaterialApp` 的 `builder:` 内部 |

> **关键结论**：前面 1–6 都是"验证能弹但数据上不来"的表象，**真正让"页面完全没数据"的致命根因是 #7 的 `Directionality` 构建崩溃**。修复 #7 后，App 才正常渲染并触发首页请求、正确唤起验证。

关于 Dart 能否连上域名：实测 Dart HTTP 客户端**能正常连上该域名**（返回 `403 + cf-mitigated: challenge`），并非此前怀疑的"TLS 挂起"——之前设备日志里一条 `[CF]` 都没有，正是因为 App 根本没渲染出来（#7）。

---

## 三、最终解决方案：常驻 WebView 桥接架构

### 3.1 核心思路

Cloudflare 的 `cf_clearance` 与**客户端 TLS 指纹**绑定。Dart 的 HTTP 客户端（BoringSSL，指纹与 WebView 不同）用该 cookie 重放请求时，很可能被按请求重新挑战 —— 这正是"在 WebView 里验证成功、关掉后 Dart 请求仍拿不到数据"的本质。

**解法：让所有 API 请求都通过【同一个已验证的 WebView】的内部 `fetch` 去取数。** 这个 `fetch` 跑在 WebView 进程内，共享 WebView 的系统级 TLS 指纹 + `cf_clearance`，因此不会被重新挑战。

### 3.2 架构图

```
HTTP 请求 (api.dart → httpService.get)
        │
        ▼
_withCloudflare()  ── 检测到 Cloudflare 挑战页（403 + cf-mitigated:challenge）
        │
        ▼
CloudflareSolver.solve(uri)
        │  （并发请求等待同一次验证、只复用 cookie）
        ▼
CloudflareBridge.instance.solve(uri)   ← 常驻 WebView
        │  • 首次：加载目标 URL，展示验证页，轮询直到挑战页消失
        │  • 读 WebViewCookieManager 拿到含 HttpOnly 的 cf_clearance
        │  • _ready = true，WebView 退回隐藏但保持挂载
        ▼
request.dart 取数三路径：
   路径A：触发验证那条的 html 直接用
   路径B（关键）：CloudflareBridge.fetchHtml(url)  ← 通过 WebView 内部 fetch 取数
   路径C：Dart 携带 cookie 兜底重试一次（仍失败则标记 host 失败 + 提示导入旁路）
        │
        ▼
真实 HTML → api.dart 解析 → 页面渲染
```

### 3.3 关键文件职责

- **`lib/utils/cloudflare.dart`**
  - 常量：`kBrowserUserAgent`（HTTP 与 WebView 统一 UA）、`kTargetHost`（目标域名单一来源）、`kCloudflareChallengeCheckJs`（注入 WebView 判断挑战页的 JS，靠"挑战 UI 是否消失"判断，而非读 HttpOnly cookie）。
  - `CloudflareDetector`：`isChallenge(Response)` / `isHtmlChallengeString(String)` 两套检测。
  - `CloudflareCookieJar`：按 host 持久化 clearance cookie（`SharedPreferences`），提供 `parseRawCookie` / `importFromRawCookie` / `cookieHeaderFor` / `hasClearanceFor`。

- **`lib/utils/cloudflare_solver.dart`**
  - `CloudflareSolver.solve()`：单例 `_currentSolve` Completer 处理并发；`_failedHosts` + `_cooldownMs` 防止无限循环；移动端委托给 `CloudflareBridge`。

- **`lib/utils/cloudflare_bridge.dart`**（核心）
  - `CloudflareBridge`：全 App **唯一**的 `WebViewController`，`ChangeNotifier`。
    - `solve(uri)`：加载目标 URL → 轮询挑战页消失 → `_readCookies()`（经 `WebViewCookieManager`）→ `_ready = true`。
    - `fetchHtml(url)`：经 WebView 内部 `fetch`（`credentials:'include'`）取数，经 `cfFetch` JS channel 回传，25s 超时。
    - `injectImport(host, cookies)`：**导入旁路**——把 cookie 用 `document.cookie`（带 `secure; SameSite=None`）写入 WebView，直接置 `_ready = true`，无需走 Turnstile。
    - `reset()`：设置页"清除验证缓存"时调用。

- **`lib/utils/request.dart`**
  - `_withCloudflare()` 包裹所有 get/post：挑战 → 唤起验证 → 存 cookie → 路径 A/B/C。
  - `imageHeadersFor(url)`：图片请求也附带 cookie（修 #4）。
  - `httpClient.timeout = 20s` + 入口/完成诊断日志 `[CF]`，便于定位"没数据"。

- **`lib/main.dart`**
  - `CloudflareBridgeOverlay` 放在 `GetMaterialApp(builder:)` **内部**（修 #7），常驻隐藏 WebView；验证中显示全屏验证页，通过后在底部显示绿色状态条 `☁ Cloudflare 已通过 · 数据经桥接 WebView 加载`。
  - 返回键退出改用 `ScaffoldMessenger`（修 #6）。

- **`lib/view/info/setting.dart`**
  - 「导入 cf_clearance 绕过验证」：对话框粘贴（支持只粘值或整段 cookie 头）→ 同时持久化到 `CloudflareCookieJar` 与注入常驻 WebView → 清 `_failedHosts` → 下一请求即可取数。
  - 「清除 Cloudflare 验证缓存」：清 jar + 清失败记录 + `CloudflareBridge.reset()`。
  - 「自动过验证（打码平台）」：开关 + 服务商（2Captcha / Anti-Captcha）+ API Key 输入，持久化到 `CaptchaSettings`。

- **`lib/utils/turnstile_solver.dart`**（新增 · 2026-08-23）
  - `CaptchaSolver` 抽象 + `_HttpTurnstileSolver`（2Captcha / Anti-Captcha 的 AntiTurnstileTask 协议，仅用 `dart:io HttpClient`，无新依赖）。
  - `CaptchaSettings`：开关 / 服务商 / API Key 持久化；`CaptchaSolverFactory.solver` 在未配置时返回 null（调用方据此降级）。

---

### 3.4 自动过验证：打码平台解 Turnstile（三级自动降级）

针对「IDN 域名下纯 WebView 永远过不去交互式 Turnstile」这一死结，新增一条**全自动**路径，无需手动导入：

```
Web 请求触发验证 → CloudflareBridge.solve(uri)
   │
   ├─ 路径① managed 挑战免交互自动通过（原有，依赖站点给 managed）
   │
   └─ 卡在交互式 Turnstile（_detectTurnstile 命中）时自动降级：
        CloudflareBridge._escalateTurnstile(uri)
          │ 1. CaptchaSolverFactory.solver（未配置 Key → 返回 null，降级回导入旁路）
          │ 2. _extractTurnstileInfo：从挑战页 DOM 提取 sitekey / action / data
          │ 3. solver.solveTurnstile() → 打码平台用真实浏览器跑完 Turnstile，返回 token
          │ 4. _injectTurnstileToken(token)：回填隐藏字段 + 提交表单
          ▼
        Cloudflare 校验通过 → 签发 cf_clearance → 轮询检测到挑战页消失 → _ready=true
```

**关键点**：
- **仅在检测到交互式 Turnstile 且 managed 流程卡住时触发**（`_pollCount >= 3` 后才探测，避免误判）；每轮只调用一次（`_turnstileEscalated` 防重入/重复花钱）。
- **需要付费 API Key**：在 设置 → 自动过验证（打码平台） 填入。无 Key 时该路径静默跳过，行为回退到原有 managed / 手动导入。
- **IDN 下的 best-effort**：Turnstile widget 在该域名可能已崩溃（`window.turnstile` 未定义），因此回填采用「隐藏字段赋值 + 提交表单 + 调用 data-callback」多策略，而非依赖 widget 回调。
- **token 与 IP/UA/TLS 指纹绑定**：必须在**同一个**常驻 WebView 会话内回填（正是桥接器在做），否则 Cloudflare 拒绝。

**获取 API Key**：2Captcha（api.2captcha.com）、Anti-Captcha（api.anti-captcha.com）注册后获得 clientKey。

---

## 四、我认为还能解决这个问题的其他思路（备选方案）

| 方案 | 思路 | 优点 | 缺点 / 风险 | 推荐度 |
|------|------|------|------------|--------|
| **A. 当前方案：常驻 WebView 桥接 + 导入旁路** | 所有请求经已验证 WebView 的 `fetch` 取数，共享 TLS 指纹 + cookie | 从根上规避 Dart TLS 指纹差异；导入旁路可 100% 打通 | WebView 手动验证在该 IDN 域名下可能仍过不去（见第五节） | ⭐⭐⭐⭐⭐ 已实现 |
| **B. Dart 客户端直接携带 cf_clearance 重放** | 把 cookie 加进 Dart 请求头直接请求 | 实现最简单，无需 WebView 取数 | Dart BoringSSL 指纹与 WebView 不同，Cloudflare 按请求重放极易再被挑战；该域名 WebView 本身过不去 → 取不到 cookie | ⭐ 不推荐 |
| **C. 自建服务端代理（Node + Playwright/Puppeteer）** | 服务端用真实浏览器过一次 Cloudflare，持有 cookie 并转发数据给 App | App 不再依赖 WebView；cookie 服务端集中管理、可多设备共享；最稳 | 需一台常驻服务器、运维成本；隐私/合规需自担；对个人爬虫偏重 | ⭐⭐⭐⭐ 适"长期稳定"诉求 |
| **D. 换 `flutter_inappwebview`** | 用功能更全的 WebView 包替代 `webview_flutter`，对 cookie/WebRTC 支持更好 | 可能让 Turnstile 在 WebView 内真正通过（缓解 IDN 渲染崩溃） | 包更重；IDN 的 `SecurityError` 未必消失 | ⭐⭐⭐ 可作增强 |
| **E. 对齐 Dart TLS 指纹**（`HttpClient` + 自定义 `SecurityContext` + 对齐 JA3/JA4、header） | 让 Dart 请求"伪装"成浏览器 | 不动 WebView | Cloudflare 不只看 JA3，指纹随版本变；极其脆弱、易失效 | ⭐ 不推荐 |
| **F. 纯 cookie 注入到 Dart 客户端**（方案 B 的变体） | 把用户导入的 `cf_clearance` 直接加进 Dart 请求头 | 最简单，可先快速试 | 若该站做严格按请求 TLS 校验则同 B 失败；否则可能"侥幸"有效 | ⭐⭐ 作快速尝试 |
| **G. App 内嵌 Headless Chromium** | 用真实 Chromium 完成整套验证与取数 | 最稳，能力最全 | 体积大、集成复杂、首次启动慢 | ⭐⭐ 重型兜底 |
| **H. 挑战频率/过期自动轮换** | 检测 403/`cf-mitigated` 自动重新验证或重新导入 cookie，平滑过期 | 体验最好，无需人工干预 | 需处理并发与重试风暴 | ⭐⭐⭐ 建议叠加在当前方案上 |

**我的总体建议**：当前方案（A）已落地且能跑通，是首选。若你后续追求"长期、免手动"的稳定运行，**C（服务端代理）** 是最省心的架构升级；若想让 App 端 WebView **自己**能过验证，可尝试 **D（换 inappwebview）** 作为增强。B/E 因 TLS 指纹本质问题不推荐。

---

## 五、已知限制与风险（务必了解）

1. **IDN 域名下 WebView 手动验证可能永远过不去**：Turnstile 在该域名会因 `SecurityError` 使渲染进程崩溃。这意味着 `CloudflareBridge.solve()` 的"手动验证"路径在此域名**很可能无效**——`fetch(html)` 路径能拿到数据的前提是 `cf_clearance` 已就绪。除原有的**「导入 cf_clearance」旁路**（`injectImport` 直接置 `_ready`，不依赖 Turnstile 成功）外，现已新增**打码平台自动解 Turnstile**（见 3.4）：配置 API Key 后，验证卡在交互式挑战时自动调用平台解出并回填，是目前唯一**全自动**绕过该死结的路径。
   → 对该域名，端到端可用路径优先级：**打码平台自动解（需 Key）> 导入 cookie → 经 WebView 桥接 `fetchHtml` 取数 > 赌 managed 免交互通过**。

2. **`cf_clearance` 会过期**：它与浏览器 UA / IP / TLS 指纹绑定，过期后需重新导入或重走验证。建议叠加方案 H 做自动探测轮换。

3. **TLS 指纹优势**：桥接 `fetch` 在 WebView 进程内执行，共享系统 TLS 指纹，这正是它相对"Dart 重放 cookie"的核心优势。

4. **调试日志未收敛**：大量 `[CF]` `print` 仍保留，建议 release 构建前用 `kDebugMode` 包裹，避免刷日志。

5. **死代码**：`lib/view/cloudflare/cloudflare_mobile_view.dart` 已无外部引用（被桥接器取代），可清理。

---

## 六、如何验证（用户侧操作）

0. **（推荐）自动过验证**：设置 → 自动过验证（打码平台）→ 启用并填入 2Captcha / Anti-Captcha 的 API Key。之后验证卡在交互式挑战时会自动解出，无需任何手动操作。
1. 手机打开 App → 若弹出 Cloudflare 验证页，手动完成人机验证。
2. 验证通过后，屏幕底部出现**绿色状态条**「☁ Cloudflare 已通过 · 数据经桥接 WebView 加载」→ 列表/详情/搜索应正常刷出。
3. 若手动验证在该域名下反复失败（卡住/崩溃）：
   - 桌面浏览器打开站点 → 开发者工具 → Application/Storage → Cookies → 复制 `cf_clearance`（或整段 cookie 头）；
   - App → 设置 → **导入 cf_clearance 绕过验证** → 粘贴 → 导入；
   - 下一请求即经桥接 WebView 取数，无需再手动验证。

---

## 七、关键文件清单

| 文件 | 角色 |
|------|------|
| `lib/utils/cloudflare.dart` | 常量、挑战检测、CookieJar 持久化 |
| `lib/utils/cloudflare_solver.dart` | 并发调度、循环防护、移动端委托桥接 |
| `lib/utils/cloudflare_bridge.dart` | **核心**：常驻 WebView 桥接 + 取数 + 导入旁路 |
| `lib/utils/request.dart` | 请求统一入口、三路径取数、图片 cookie、诊断日志 |
| `lib/main.dart` | 桥接 Overlay（放 builder 内）、状态条、返回键修复 |
| `lib/view/info/setting.dart` | 导入 cf_clearance、清除缓存入口 |
| `lib/view/cloudflare/cloudflare_mobile_view.dart` | 早期方案，现为死代码（可删） |

---

*附：真机调试命令（本环境必须 `--disable-dds`，否则 VM-service 握手失败导致 `flutter run` 退出）*
```bash
flutter run -d 3B6F5RE8GCL2PQS2 --debug --disable-dds
```
