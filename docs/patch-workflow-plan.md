# dev-patch 补丁工作流方案

> 目标仓库:`wtfdelphia/wtf-s-ui`(远程 `down`)
> 制定时间:2026-09-16(决策版)
> 实施状态:**已完成**(2026-09-16,Phase 0-4 全部落地;干净目录端到端冒烟通过,结论见 §7 末尾)
> 前置阅读:[分支与远程仓库关系分析](./branch-analysis.md)
> 配套前端方案:[wtf-s-ui-frontend 补丁工作流方案](./frontend-patch-workflow-plan.md)

## 1. 目标

1. `down` 仓库的 `dev-patch` 分支**永远钉在分叉点 `7cfb1a7`**(v1.4.2 + 1,2026-06-23)。
2. `down` 仓库维护 `patch/` 目录,存放三份补丁:
   - `01-up-main.patch`:`7cfb1a7 → up/main` 的定制全量补丁
   - `02-cloud-main.patch`:`7cfb1a7 → cloud/main` 的官方全量补丁
   - `03-up-on-cloud.patch`:up 定制**重新做在 cloud/main 上**的补丁(最终交付物)
3. `down/main` 随时可快进同步 `cloud/main`。
4. up 出现新定制提交时,能增量更新 `03` 补丁。

## 2. 已确认的决策

| # | 决策 | 说明 |
|---|------|------|
| D1 | 定制叠加成果只以补丁形式交付 | `03` 打在 cloud 最新代码上,加上前端构建步骤,即得最终产品 |
| D2 | 自更新/安装 URL 指向 `wtfdelphia/wtf-s-ui` | 不用 Teminuosi 上游,改写清单见附录 C |
| D3 | 定制前端镜像同样的三线结构 | `wtfdelphia/wtf-s-ui-frontend/main` 对齐官方前端,`dev-custom` 承载 Teminuosi 定制;操作细则见 [前端方案](./frontend-patch-workflow-plan.md) |
| D4 | 集成分支 `dev-custom` 推到 down 公开保存 | 保留合并记忆,供回溯与协作 |

## 3. 整体架构:后端 + 前端两条平行三线

```
后端:
  alireza0/s-ui ──► Teminuosi/s-ui ──► wtfdelphia/wtf-s-ui
  (cloud 官方线)      (up 定制线)          (down 发布线)
前端:
  alireza0/s-ui-frontend ──► Teminuosi/s-ui-frontend ──► wtfdelphia/wtf-s-ui-frontend
  (官方前端)                    (up 定制前端)                 (适配后定制前端,待创建)
```

两条线**同构且同步分叉**:后端与前端都在官方 `v1.4.2` 处分叉。

### 3.1 后端实测数据

| 项目 | 数值 |
|------|------|
| 分叉点 | `7cfb1a7` "simpler chart #1134" |
| 定制线(up/main)独有提交 | 65 个(其中 24 个纯 frontend submodule bump),53 文件 +3103/−488 |
| 官方线(cloud/main)独有提交 | 109 个,181 文件 +17297/−2065 |
| 两侧无重复提交 | `git cherry` 验证通过 |
| 真实合并冲突文件 | **36 个**(实测 `git merge --no-commit`,名单见附录 A) |
| `git apply` 直打 / `git am -3` 重放 | 均失败——补丁不能跨分叉线移植 |
| 两侧 diff 二进制文件 | 无,纯文本补丁可完整表达 |
| 补丁体积 | 01 约 194 KB,02 约 842 KB |
| Go 要求 | 分叉点/定制线 1.26.5;官方线 `go.mod` 已升到 **1.26.7**(本机当前 1.26.5,需升级或依赖 GOTOOLCHAIN) |

### 3.2 前端实测数据(本次审核新增)

| 项目 | 数值 |
|------|------|
| 前端分叉点 | `a4b8816`(v1.4.2),与后端分叉点同版本 |
| 定制前端独有提交 | **39 个**,仅 21 文件 +1915/−51(定制很薄) |
| 官方前端独有提交 | 58 个,163 文件 +25037/−7600(官方走得很远,含 v1.6.3) |
| 真实合并冲突文件 | **10 个**(实测,名单见附录 B) |
| 子模块指针自洽性 | up 指 `31049d1` ✓ 存在于 Teminuosi 仓库;cloud 指 `f859e16` ✓ 存在于官方仓库 |
| 定制前端硬编码上游地址 | 无(自更新特性走后端 `api/updateInfo`,URL 集中在后端);含第三方推广链接(见附录 C) |

**核心结论:**

1. 补丁是快照格式,不是生产机制。`03` 必须通过一次真实 rebase(解 36 处
   冲突)生产,之后靠**集成分支**做增量维护;`patch/` 目录是导出物。
2. 前端定制量很小(1915 行 / 21 文件),合并冲突仅 10 处——前端移植的
   主要工作量在**定制功能对 v1.6.3 新 API 的适配**(后端 `api/`+`service/`
   +`sub/` 自分叉点变了 38 文件 +3763 行:login_limit、session 重构、
   maintenance mode、live traffic、TLS spoofing、多用户 Snell 等)。
3. 前端也采用同构补丁机制:前端仓库维护自己的 `main`、`dev-patch`、
   `dev-custom` 与三份 patch;后端 `03` 补丁只记录 `.gitmodules` URL、
   `branch=dev-custom` 与子模块指针。完整流程见
   [前端方案](./frontend-patch-workflow-plan.md)。

## 4. "永远是 7cfb1a7" 的语义定义

分支尖无法既停在 `7cfb1a7` 又携带 `patch/` 目录。本方案采用:

- `dev-patch` 分支 = `7cfb1a7` 之上**恰好一个**"仅添加 `patch/` 与 `docs/` 目录"的提交
  (`docs/` 自 2026-09-16 起随 `dev-patch` 公开保存);
- 每次刷新补丁时 `git commit --amend` + `git push --force-with-lease`;
- 即:除 `patch/` 与 `docs/` 目录外,工作树与 `7cfb1a7` 逐字节一致;分支尖的父提交永远是 `7cfb1a7`。

校验标准:`git diff 7cfb1a7 dev-patch -- . ':!patch' ':!docs'` 输出为空。

审计留痕(可选):`--amend` 会丢弃上一版补丁集。如需保留历史版本,
每次刷新前先打标签:`git tag dev-patch-YYYYMMDD dev-patch`。

## 5. 集成分支(生产引擎)

`dev-custom` 分支(D4:推到 down 公开保存):

```
dev-custom = cloud/main + 全部定制提交(冲突已解,URL 已改写)
```

职责:

1. 记录"定制如何叠到新版官方上"的合并记忆,使下次官方升级只需增量
   rebase,而不是重解 36 处冲突;
2. `03` 补丁的导出源:`git diff cloud/main dev-custom --binary > patch/03-up-on-cloud.patch`;
3. 前端适配工作在独立仓库 `wtfdelphia/wtf-s-ui-frontend` 进行,
   该仓库同样有 `dev-patch` 与 `dev-custom`;适配结果以 `down/dev-custom`
   的已验证子模块指针提交进后端 `dev-custom`。

**提交策略(默认):压扁式移植。** rebase 重放 65 个提交时,24 个纯
submodule bump 会在 gitlink 上几乎逐个冲突。推荐先把定制按功能压成
若干提交(或直接 `git diff` 单提交)叠到 `cloud/main`,子模块只需最终
一个指针提交。完整历史已由 `01` 补丁和 up 仓库保存,`dev-custom`
不必复刻提交粒度。

## 6. 目录结构与元数据

```
patch/
  METADATA.json
  01-up-main.patch
  02-cloud-main.patch
  03-up-on-cloud.patch
  apply.sh        # 端到端应用脚本(见下)
  verify.sh       # 校验脚本
```

`METADATA.json` 字段:

```json
{
  "base": "7cfb1a7...",
  "up_ref": "up/main", "up_sha": "...",
  "cloud_ref": "cloud/main", "cloud_sha": "...",
  "patch3_target": "<cloud_sha,即 03 的应用目标>",
  "frontend_repo": "wtfdelphia/wtf-s-ui-frontend",
  "frontend_branch": "dev-custom",
  "frontend_sha": "...",
  "generated_at": "...",
  "verified": true
}
```

### apply.sh 必须覆盖的端到端流程

`03` 补丁只含后端与子模块配置,**不含可运行的前端产物**
(`web/html` 与 `frontend/dist` 均在 `.gitignore`,不进补丁)。
完整应用流程:

1. 检出 `patch3_target` 对应的 cloud 代码;
2. `git apply --index 03-up-on-cloud.patch`;
3. `git submodule sync --recursive && git submodule update --init --recursive frontend`(拉取 `wtfdelphia/wtf-s-ui-frontend`);
4. 构建前端:`cd frontend && npm ci && npm run build`;
5. `mkdir -p web/html && rm -fr web/html/* && cp -R frontend/dist/* web/html/`(与 `build.sh` 一致);
6. 运行发布等价构建:`./build.sh` 或使用相同 build tags 执行 `go build -o sui main.go`。

### verify.sh 必须包含(缺一不算合格)

1. `git apply --check` 三份补丁各自的目标基底;
2. 实际复现树时统一使用 `git apply --index`,避免新增文件停留在 untracked 状态导致比对误判;
3. 打完 01 后树与 `up/main` 一致;打完 03 后树与 `dev-custom` 一致;
4. 走完 apply.sh 全流程,发布等价构建通过(`./build.sh` 或同 build tags 的 `go build -o sui main.go`);
5. `git submodule status` 指向 METADATA 记录的 frontend SHA;
6. `web/html` 非空(embed 空目录也能编译过,构建通过不代表面板可用)。

## 7. 分步实施计划

### Phase 0 — 环境准备
- [x] Go ≥ 1.26.7(官方线 `go.mod` 要求;本机当前 1.26.5,需升级或确认
      `GOTOOLCHAIN=auto` 可自动拉取);Node 工具链按前端 `package.json` 要求
- [x] 在 GitHub 创建 `wtfdelphia/wtf-s-ui-frontend`,推荐 fork/import 自官方
      `alireza0/s-ui-frontend`;若已 fork 自 `Teminuosi/s-ui-frontend`,首次必须
      强制对齐 `main` 到官方前端;然后按 [前端方案](./frontend-patch-workflow-plan.md)
      建立 `main`、`dev-patch`、`dev-custom`
- [x] 在 down 上创建 `dev-patch` 与 `dev-custom` 分支
- [x] 确认 `wtfdelphia/wtf-s-ui` 为公开仓库且开启 Releases(D2 的自更新
      依赖 `api.github.com/repos/wtfdelphia/wtf-s-ui/releases`)

### Phase 1 — 生成并校验 01、02 补丁
- [x] `git diff 7cfb1a7 up/main --binary > patch/01-up-main.patch`
- [x] `git diff 7cfb1a7 cloud/main --binary > patch/02-cloud-main.patch`
- [x] 临时 worktree 中打回 `7cfb1a7`,校验树与 `up/main`、`cloud/main` 完全一致
- [x] 写入 METADATA(除 03 相关字段)

### Phase 2 — 后端定制移植(生产 03 的主体)
- [x] 首次执行:`git checkout -b dev-custom cloud/main`;后续维护禁止
      `checkout -B` 或重置已有 `dev-custom`,只能 rebase/merge/cherry-pick 增量
- [x] 压扁式移植:将定制(65 提交,去掉 24 个纯 submodule bump)叠到
      `cloud/main`,解 36 处冲突(名单见附录 A)
- [x] `.gitmodules`:URL 改为 `wtfdelphia/wtf-s-ui-frontend`,branch 改为
      `dev-custom`,gitlink 指向前端 `down/dev-custom` 的已验证提交(D3)
- [x] **URL 改写(D2)**:按附录 C 清单把 `install.sh`、`s-ui.sh`、
      `service/panel.go`、CI workflows 中的 Teminuosi 地址改为
      `wtfdelphia/wtf-s-ui`;release CI 调整为向 `wtfdelphia/wtf-s-ui`
      发布产物(否则面板自更新无包可下)
- [x] `go test ./...` + 发布等价构建通过(`./build.sh` 或同 build tags 的 `go build -o sui main.go`)

### Phase 3 — 前端仓库同构移植
前端不再作为后端文档里的一个临时步骤处理,而是按
[前端方案](./frontend-patch-workflow-plan.md) 独立完成:

- [x] `wtfdelphia/wtf-s-ui-frontend/main` 快进到官方前端 `cloud/main`
- [x] 前端 `dev-patch` 钉在 `a4b8816` 并维护自己的三份 patch
- [x] 前端 `dev-custom` = 官方最新前端 + Teminuosi 定制,解 10 处冲突
- [x] 前端 `dev-custom` 已推到 down,且 `npm ci && npm run build` 通过
- [x] 后端子模块指针锁定到前端 `down/dev-custom` 的已验证 SHA
- [x] 端到端:安装脚本 → 起服务 → 面板全流程(含自更新检查)验证

### Phase 4 — 导出 03 补丁并入库
- [x] `git diff cloud/main dev-custom --binary > patch/03-up-on-cloud.patch`
- [x] 新 worktree 打在 `cloud/main` 上 apply 03,校验树与 `dev-custom` 一致
- [x] 补全 METADATA(`patch3_target` = 当前 `cloud_sha`)并跑 `verify.sh`
- [x] 将 `patch/` 提交到 `dev-patch`(首个或 `--amend`),
      `git push --force-with-lease down dev-patch`
- [x] `git push down dev-custom`(D4)

### Phase 5 — 日常维护协议

**cloud 发新版时:**
1. `git fetch cloud` → `down/main` 快进
2. `dev-custom` rebase 到新 `cloud/main`,解增量冲突
3. 官方前端同步升级时,前端仓库同步移植
4. 先完成前端 `dev-custom` 并推送,再更新后端子模块指针
5. 重新导出 02、03,刷新 METADATA,跑 verify,amend `dev-patch`

**up 出新定制提交时:**
1. `git fetch up` → 找出 `dev-custom` 尚未包含的定制提交
2. 只 cherry-pick/移植增量(切勿整份重放 01)
3. 前端增量同理,按前端方案移植到 `wtfdelphia/wtf-s-ui-frontend/dev-custom`
4. 先推送前端 `dev-custom`,再更新后端子模块指针
5. 重新导出 01、03,刷新 METADATA,跑 verify,amend `dev-patch`

**cloud 与 up 同时更新时**:先 rebase 到新 cloud,再叠 up 增量。

### 实施结论(2026-09-16)

- 后端:`dev-custom`(7cff297,cloud v1.6.3 + 定制,36 处冲突已解)、`dev-patch`(
  7cfb1a7 + `patch/` 全套 + `docs/`)均已推送到 down;verify.sh 7 项全过。
- 前端:`dev-custom`(edeac95)、`dev-patch`(49bac2a)均已推送到 down,
  前端 verify.sh 全过;后端 `.gitmodules` 锁定前端 `dev-custom` @ edeac95。
- 同日复核修订:删除前端 `Drawer.vue`/`Login.vue` 的上游推广链接及对应语言包键;
  后端 `README.md`/`CONTRIBUTING.md` 去除 Teminuosi 残留与推广块;
  03 补丁与 METADATA 已随之重导,两侧补丁复现校验全过。
- 端到端冒烟:干净目录跑 `patch/apply.sh` 全流程成功
  (clone → checkout cloud 13abbdc → apply 03 → 子模块 dev-custom → 前端构建 → 后端构建)。
  `build.sh` dev profile 因本地无 musl/cronet 工具链按预期回退到 test profile;
  产出的 `sui` 启动后 2 秒内面板就绪(`/app/` 200),定制前端资源(如
  `quickTemplate` locale 键)确认被嵌入,自更新/安装 URL 均指向 `wtfdelphia/wtf-s-ui`。

## 8. 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| 前端适配工作量超预期 | 阻塞交付 | 前端有独立 `dev-custom` 和补丁方案;必要时可先锁官方前端 SHA,定制前端第二批补 |
| 后端子模块指向未推送前端提交 | 用户 apply 后拉不到前端 | 先推前端 `dev-custom`,再更新后端 gitlink;verify 检查 `frontend_sha` |
| 36 处后端冲突解错 | 回归 | verify.sh 树级比对兜底;`dev-custom` 公开保存可回溯 |
| 自更新链路断(未发 release / 仓库私有) | 面板升级失败 | Phase 0 检查项前置;发布流程写入维护协议 |
| 03 与 METADATA 记录的 cloud SHA 失配 | 应用失败 | verify 强制校验;cloud 一升级必须全量刷新 |
| up 定制与官方新特性语义冲突(如安装脚本) | 功能损坏 | 按文件做人工审查清单;CI 跑构建与测试 |
| `dev-patch` 被误当开发分支 | 语义破坏 | 分支保护:仅允许 force-with-lease 的 amend 提交 |
| Go 工具链版本不够 | 编译失败 | Phase 0 明确 ≥1.26.7 或依赖 GOTOOLCHAIN |
| 维护时误用 `checkout -B dev-custom` | 丢失合并记忆 | `-B`/重置只允许首次建分支;后续必须 rebase/merge/cherry-pick |

## 9. 工作量预估

| 阶段 | 预估 | 说明 |
|------|------|------|
| Phase 1 | 0.5h | 机械操作 |
| Phase 2 | 1–2 天 | 36 处冲突 + URL 改写 |
| Phase 3 | 2–5 天 | 关键路径;冲突仅 10 处,主要开销在定制功能适配新 API |
| Phase 4 | 0.5h | 导出与校验 |
| Phase 5 | 每轮 1–2h | 按协议滚动 |

---

## 附录 A:后端实测冲突文件清单(36 个)

```
.github/workflows/docker.yml
.github/workflows/release.yml
.github/workflows/windows.yml
README.md
cmd/cmd.go
core/inbound_users.go
core/protocol/anytls/inbound.go
core/protocol/anytls/users.go
core/protocol/hysteria/inbound.go
core/protocol/hysteria/users.go
core/protocol/hysteria2/inbound.go
core/protocol/hysteria2/users.go
core/protocol/trojan/inbound.go
core/protocol/trojan/users.go
core/protocol/tuic/inbound.go
core/protocol/tuic/users.go
core/protocol/vless/inbound.go
core/protocol/vless/users.go
core/protocol/vmess/inbound.go
core/protocol/vmess/users.go
core/register.go
core/tracker_conn.go
database/db.go
frontend (submodule)
go.mod
go.sum
install.sh
network/tls.go
s-ui.sh
service/inbounds.go
service/user.go
sub/jsonService.go
sub/sub.go
util/password.go
util/shadowsocks.go
web/web.go
```

## 附录 B:前端实测冲突文件清单(10 个)

```
src/layouts/default/AppBar.vue
src/layouts/default/Drawer.vue
src/layouts/modals/QrCode.vue
src/locales/en.ts
src/locales/zhcn.ts
src/plugins/httputil.ts
src/store/modules/data.ts
src/views/Inbounds.vue
src/views/Login.vue
src/views/Settings.vue
```

## 附录 C:URL 改写清单

| 位置 | 现状(实测) | 改写为 |
|------|--------------|--------|
| `service/panel.go` | `panelUpdaterURL`/`panelReleaseAPI` 指向 `Teminuosi/s-ui` | `wtfdelphia/wtf-s-ui` |
| `install.sh` | 9+ 处 raw/releases 地址指向 `Teminuosi/s-ui` | `wtfdelphia/wtf-s-ui` |
| `s-ui.sh` | 4 处(菜单更新、下载链接、自更新) | `wtfdelphia/wtf-s-ui` |
| `.github/workflows/release.yml` | CI 发布权限与目标 | 向 `wtfdelphia/wtf-s-ui` 发布 release(自更新的包来源) |
| `.gitmodules` | `Teminuosi/s-ui-frontend` | `wtfdelphia/wtf-s-ui-frontend` |
| 前端 `Drawer.vue` | 3yuedaohang 博客 / YouTube / VPS 推广链接 | 待定:保留或换成自己的入口 |

前端自更新特性本身不含硬编码 URL(走后端 `api/updateInfo`),
无需改写,但依赖后端 `service/panel.go` 的改写完成。

## 附录 D:复核命令

```bash
REPO=/home/openclaw/wtf_workspace/local/wtf-s-ui

# 生成三份补丁
git diff 7cfb1a7 up/main       --binary > patch/01-up-main.patch
git diff 7cfb1a7 cloud/main    --binary > patch/02-cloud-main.patch
git diff cloud/main dev-custom --binary > patch/03-up-on-cloud.patch

# 校验 01 打回基底能复现 up/main
git worktree add -f /tmp/v1 7cfb1a7
(cd /tmp/v1 && git apply --index "$REPO/patch/01-up-main.patch" && git diff up/main --exit-code)
git worktree remove -f /tmp/v1

# dev-patch 语义校验:除 patch/ 与 docs/ 外与 7cfb1a7 无差异
git diff 7cfb1a7 dev-patch -- . ':!patch' ':!docs'   # 期望无输出

# 前端合并冲突预演(在 frontend 仓库内)
git merge --no-commit --no-ff <up-frontend-main>
```
