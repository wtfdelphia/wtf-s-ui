# wtf-s-ui-frontend 补丁工作流方案

> 目标仓库:`wtfdelphia/wtf-s-ui-frontend`
> 制定时间:2026-09-16
> 实施状态:**已完成**(2026-09-16,Phase 0-4 全部落地,分支与 `patch/` 已推 down;verify.sh 全过)
> 配套后端方案:[dev-patch 补丁工作流方案](./patch-workflow-plan.md)

## 1. 目标

1. `wtfdelphia/wtf-s-ui-frontend` 与后端仓库保持同构分支语义:
   `main`、`dev-patch`、`dev-custom` 三分支职责一致。
2. `main` 永远可快进同步官方前端 `alireza0/s-ui-frontend/main`。
3. `dev-patch` 永远钉在前端分叉点 `a4b8816`(官方 `v1.4.2`),只额外携带
   `patch/` 目录。
4. `patch/` 目录存放三份前端补丁:
   - `01-up-main.patch`:`a4b8816 -> up/main` 的 Teminuosi 前端定制全量补丁
   - `02-cloud-main.patch`:`a4b8816 -> cloud/main` 的官方前端演进全量补丁
   - `03-up-on-cloud.patch`:Teminuosi 前端定制重新做在官方最新前端上的补丁
5. `dev-custom` 公开推送到 `down`,作为后端子模块实际引用的前端成品分支。

## 2. 远程与分支命名

建议在本地前端仓库使用与后端完全一致的远程命名:

| 名称 | 仓库 | 角色 |
|------|------|------|
| `cloud` | `git@github.com:alireza0/s-ui-frontend.git` | 官方前端主线 |
| `up` | `git@github.com:Teminuosi/s-ui-frontend.git` | Teminuosi 定制前端 |
| `down` | `git@github.com:wtfdelphia/wtf-s-ui-frontend.git` | wtfdelphia 前端发布仓库 |

分支职责:

| 分支 | 基底/内容 | 是否公开推到 down | 说明 |
|------|-----------|-------------------|------|
| `main` | `cloud/main` | 是 | 纯官方镜像,不放定制 |
| `dev-patch` | `a4b8816` + `patch/` 一个提交 | 是 | 前端补丁仓库,语义与后端一致 |
| `dev-custom` | `cloud/main` + 已适配定制 | 是 | 后端子模块引用的最终前端 |

## 3. 已验证的事实

| 项目 | 数值 |
|------|------|
| 前端分叉点 | `a4b8816`(官方 `v1.4.2`,2026-05-19) |
| Teminuosi 前端最新指针 | `31049d1` `feat: 设置页加上「检查更新 / 一键更新」` |
| 官方前端最新指针 | `f859e16` `v1.6.3` |
| 定制前端独有提交 | 39 个,21 文件 +1915/-51 |
| 官方前端独有提交 | 58 个,163 文件 +25037/-7600 |
| 真实合并冲突文件 | 10 个,名单见附录 A |
| diff 二进制文件 | 无,纯文本补丁可完整表达 |
| 补丁体积 | 01 约 93 KB,02 约 1.39 MB |
| Teminuosi 硬编码地址 | 未发现;自更新 UI 走后端 `api/updateInfo` / `api/updatePanel` |

结论:前端同样适合采用 `dev-patch` + `dev-custom` + 三份补丁的结构。
前端冲突数量少于后端,但官方前端从 `v1.4.2` 到 `v1.6.3` 演进很大,
真正工作量在定制功能与新版 API/路由/状态结构的适配。

## 4. `dev-patch` 语义定义

前端 `dev-patch` 与后端保持完全一致的语义:

- 分支尖 = `a4b8816` 之上恰好一个"仅添加 `patch/` 目录"的提交;
- 每次刷新补丁时使用 `git commit --amend` + `git push --force-with-lease`;
- 除 `patch/` 外,工作树必须与 `a4b8816` 逐字节一致。

校验标准:

```bash
git diff a4b8816 dev-patch -- . ':!patch'
```

期望无输出。需要审计留痕时,刷新前先打标签:

```bash
git tag frontend-dev-patch-YYYYMMDD dev-patch
```

## 5. `dev-custom` 语义定义

前端 `dev-custom` 是生产引擎:

```text
dev-custom = cloud/main + Teminuosi 前端定制(已适配官方最新代码)
```

职责:

1. 保存定制移植到官方新版前端后的合并记忆;
2. 作为 `03-up-on-cloud.patch` 的导出源;
3. 作为后端仓库 `frontend` 子模块引用的公开分支。

默认采用**压扁式移植**:不逐个重放 39 个定制提交,而是把定制按功能合并成
少量提交叠到 `cloud/main`。原始提交历史由 `up` 仓库和 `01-up-main.patch`
保存,`dev-custom` 优先保证后续维护简单。

## 6. 目录结构与元数据

前端仓库同样维护 `patch/` 目录:

```text
patch/
  METADATA.json
  01-up-main.patch
  02-cloud-main.patch
  03-up-on-cloud.patch
  apply.sh
  verify.sh
```

`METADATA.json` 字段建议:

```json
{
  "repo_kind": "frontend",
  "base": "a4b88165023003acd8f25c90d4cb395b7f996b50",
  "up_ref": "up/main",
  "up_sha": "31049d1...",
  "cloud_ref": "cloud/main",
  "cloud_sha": "f859e16...",
  "patch3_target": "<cloud_sha,即 03 的应用目标>",
  "dev_custom_sha": "...",
  "consumed_by_backend_submodule": true,
  "generated_at": "...",
  "verified": true
}
```

### apply.sh 必须覆盖的流程

1. 检出 `patch3_target` 对应的官方前端代码;
2. `git apply --index patch/03-up-on-cloud.patch`;
3. `npm ci`;
4. `npm run build`;
5. 输出 `dist/` 供后端 `build.sh` 拷入 `web/html/`。

### verify.sh 必须包含

1. `git apply --check` 三份补丁各自的目标基底;
2. 实际复现树时统一使用 `git apply --index`,避免新增文件停留在 untracked 状态导致比对误判;
3. 打完 `01` 后树与 `up/main` 一致;
4. 打完 `03` 后树与 `dev-custom` 一致;
5. `npm ci && npm run build` 通过;
6. `dist/` 非空;
7. 关键页面路由可构建:登录、设置、入站、Relay、Servers、导出中心。

## 7. 分步实施计划

### Phase 0 - 环境准备

- [x] 创建 `wtfdelphia/wtf-s-ui-frontend` 仓库。推荐 fork/import 自
      `alireza0/s-ui-frontend`,再添加 `up` 远程指向 Teminuosi;如果 GitHub
      上已经 fork 自 `Teminuosi/s-ui-frontend`,首次必须将 `down/main`
      强制对齐到 `cloud/main`,否则不能保持纯官方镜像
- [x] 配置三远程:`cloud`、`up`、`down`
- [x] `down/main` 对齐到 `cloud/main`,保持纯官方镜像;首次从 Teminuosi fork
      改镜像时允许 force-push,后续只允许快进同步官方
- [x] 首次创建 `dev-patch`(基于 `a4b8816`)与 `dev-custom`(基于 `cloud/main`)
- [x] 确认 Node/npm 版本满足 `package.json` 与 lockfile 要求

### Phase 1 - 生成并校验 01、02 补丁

- [x] `git diff a4b8816 up/main --binary > patch/01-up-main.patch`
- [x] `git diff a4b8816 cloud/main --binary > patch/02-cloud-main.patch`
- [x] 临时 worktree 打回 `a4b8816`,分别校验树与 `up/main`、`cloud/main` 一致
- [x] 写入 METADATA(除 `03` 与 `dev_custom_sha`)

### Phase 2 - 前端定制移植(生产 03)

- [x] 首次执行:`git checkout -b dev-custom cloud/main`;后续维护禁止
      `checkout -B` 重置已有 `dev-custom`,只能 rebase/merge/cherry-pick 增量
- [x] 压扁式移植 Teminuosi 定制到官方最新前端
- [x] 解决 10 个冲突文件(见附录 A)
- [x] 适配 v1.6.3 API/状态/路由:登录、设置、自更新、入站、Relay、Servers、导出中心
- [x] 决策第三方入口:3yuedaohang、YouTube、VPS 推荐链接**全部删除**(2026-09-16 复核时定案,含语言包键)
- [x] `npm ci && npm run build` 通过

### Phase 3 - 导出 03 并推送分支

- [x] `git diff cloud/main dev-custom --binary > patch/03-up-on-cloud.patch`
- [x] 新 worktree 打在 `cloud/main` 上 apply 03,校验树与 `dev-custom` 一致
- [x] 补全 METADATA 并跑 `verify.sh`
- [x] 将 `patch/` 提交到 `dev-patch`(首个或 `--amend`)
- [x] `git push --force-with-lease down dev-patch`
- [x] `git push down dev-custom`

### Phase 4 - 后端子模块对齐

在后端 `wtfdelphia/wtf-s-ui/dev-custom` 中执行:

- [x] `.gitmodules` URL 改为 `https://github.com/wtfdelphia/wtf-s-ui-frontend`
- [x] `.gitmodules` 的 `branch` 改为 `dev-custom`
- [x] `frontend` 子模块指针锁定到前端 `down/dev-custom` 的已验证提交
- [x] 后端 `patch/METADATA.json` 记录同一个 `frontend_sha`
- [x] 后端 apply/verify 流程能拉取该子模块并构建 `web/html`

### Phase 5 - 日常维护协议

**官方前端更新时:**

1. `git fetch cloud`
2. `down/main` 快进同步 `cloud/main`
3. `dev-custom` rebase 到新 `cloud/main`,解增量冲突
4. 重新导出 `02`、`03`,刷新 METADATA,跑 verify,amend `dev-patch`
5. 更新后端子模块指针,刷新后端 `03` 补丁

**Teminuosi 前端更新时:**

1. `git fetch up`
2. 找出 `dev-custom` 尚未包含的定制增量
3. 只移植增量,不要整份重放 `01`
4. 重新导出 `01`、`03`,刷新 METADATA,跑 verify,amend `dev-patch`
5. 更新后端子模块指针,刷新后端 `03` 补丁

**后端与前端同时更新时:**先处理前端 `dev-custom`,得到可构建 SHA;
再处理后端 `dev-custom` 并锁定该 SHA。这样后端 `03` 永远引用一个真实存在、
已验证的前端提交。

## 8. 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| 前端 `main` 混入定制 | 失去官方镜像能力 | `main` 只允许快进官方;定制只进 `dev-custom` |
| 后端子模块指向未推送提交 | 用户 apply 后拉不到前端 | 先推前端 `dev-custom`,再更新后端子模块 |
| `dev-patch` 被当开发分支 | 分支语义破坏 | 只允许 amend `patch/` 提交,用校验命令兜底 |
| 维护时误用 `checkout -B dev-custom` | 丢失合并记忆 | `-B` 只允许首次建分支;后续必须 rebase/merge/cherry-pick |
| 官方前端 API/状态结构变化 | 定制 UI 可编译但不可用 | Phase 2 做页面级回归,后端联调后再导出 03 |
| 第三方推广链接未决 | 品牌归属不清 | Phase 2 明确保留/替换策略 |
| npm/lockfile 变化 | 构建失败 | verify 固化 `npm ci && npm run build` |

## 9. 工作量预估

| 阶段 | 预估 | 说明 |
|------|------|------|
| Phase 0-1 | 0.5 天 | 仓库/分支/补丁机械操作 |
| Phase 2 | 1-3 天 | 10 个冲突 + 定制功能适配新版前端 |
| Phase 3 | 0.5 天 | 导出、校验、推送 |
| Phase 4 | 0.5 天 | 后端子模块对齐与端到端验证 |
| Phase 5 | 每轮 0.5-1 天 | 取决于官方/Teminuosi 增量大小 |

---

## 附录 A:前端实测冲突文件清单(10 个)

```text
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

## 附录 B:复核命令

```bash
FRONTEND_REPO=/path/to/wtf-s-ui-frontend

# 生成三份补丁
git diff a4b8816 up/main       --binary > patch/01-up-main.patch
git diff a4b8816 cloud/main    --binary > patch/02-cloud-main.patch
git diff cloud/main dev-custom --binary > patch/03-up-on-cloud.patch

# 校验 01 打回基底能复现 up/main
git worktree add -f /tmp/fe-v1 a4b8816
(cd /tmp/fe-v1 && git apply --index "$FRONTEND_REPO/patch/01-up-main.patch" && git diff up/main --exit-code)
git worktree remove -f /tmp/fe-v1

# dev-patch 语义校验:除 patch/ 外与 a4b8816 无差异
git diff a4b8816 dev-patch -- . ':!patch'

# 预演前端合并冲突
git checkout -B merge-test cloud/main
git merge --no-commit --no-ff up/main
```

## 附录 C:与后端保持一致的校验清单

- [ ] 前端 `down/main` = `cloud/main`
- [ ] 前端 `dev-patch` 父提交 = `a4b8816`
- [ ] 前端 `dev-custom` 已推到 down
- [ ] 后端 `.gitmodules` URL = `wtfdelphia/wtf-s-ui-frontend`
- [ ] 后端 `.gitmodules` branch = `dev-custom`
- [ ] 后端 gitlink SHA = 前端 `down/dev-custom` 的已验证提交
- [ ] 后端 `patch/METADATA.json.frontend_sha` = 上一项 SHA
- [ ] 后端 `apply.sh` 能从 down 拉取该前端提交并完成构建
