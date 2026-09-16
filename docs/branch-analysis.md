# 分支与远程仓库关系分析

> 分析对象:`wtf-s-ui` 后端仓库 + `wtf-s-ui-frontend` 前端仓库
> 生成时间:2026-09-16(实施完成后刷新版)

## 一、远程仓库一览(后端 `wtf-s-ui`)

| 远程名 | 仓库地址 | 角色 |
|--------|----------|------|
| `up` | `git@github.com:Teminuosi/s-ui.git` | 定制化上游(定制线来源,qs 系列) |
| `cloud` | `git@github.com:alireza0/s-ui.git` | 原始上游项目(官方主线) |
| `down` | `git@github.com:wtfdelphia/wtf-s-ui.git` | 本仓库下游(定制成果发布目标) |

前端仓库 `wtf-s-ui-frontend` 同样配置 `cloud`/`up`/`down` 三远程
(分别指向 `alireza0/s-ui-frontend`、`Teminuosi/s-ui-frontend`、
`wtfdelphia/wtf-s-ui-frontend`),结构与后端完全同构。

## 二、分支关系图(当前状态)

```
后端:
 7cfb1a7 "simpler chart #1134"            ← 分叉点 (v1.4.2 + 1, 2026-06-23)
   │
   ├─ 官方线 +109 ──► 13abbdc v1.6.3 ──────────────► cloud/main = down/main
   │                                              │
   │                                              └─ dev-custom = v1.6.3 + wtfdelphia 定制
   │                                                  (28003cf..a30efa9,已推 down)
   │
   ├─ 定制线 +65 ──► 8704dd2 v1.4.2-qs44 ─────────► up/main = 本地 main
   │
   └─ dev-patch = 7cfb1a7 + patch/ 目录 ──────────► 已推 down (2661af3)

前端:
 a4b8816 v1.4.2                             ← 分叉点 (2026-05-19,与后端同版本)
   │
   ├─ 官方线 +58 ──► f859e16 v1.6.3 ──────────────► cloud/main = down/main
   │                                              │
   │                                              └─ dev-custom = v1.6.3 + 定制
   │                                                  (f5c003f,已推 down)
   │
   └─ 定制线 +39 ──► 31049d1 ────────────────────► up/main

子模块锁定: 后端 dev-custom 的 frontend gitlink = f5c003f (前端 dev-custom)
```

## 三、分支指向明细(实测,2026-09-16)

| 引用 | 提交 | 说明 |
|------|------|------|
| 后端 `main`(本地) | `8704dd2` | = `up/main`(定制线最新,标签 `v1.4.2-qs44`) |
| 后端 `dev-patch` | `2661af3` | 父提交 = `7cfb1a7`,仅多出 `patch/` 目录 |
| 后端 `dev-custom` | `a30efa9` | = `cloud/main` + 定制移植(3 个压扁提交) |
| `cloud/main` / `down/main` | `13abbdc` | 官方 v1.6.3,两者一致 |
| 前端 `down/main` | `f859e16` | = 官方前端 v1.6.3 镜像 |
| 前端 `dev-patch` | `a4b8816` | 钉在前端分叉点(补丁目录待补充) |
| 前端 `dev-custom` | `f5c003f` | = 官方前端 + 定制移植(合并提交) |

## 四、三条产品线的定位

| 线 | 内容 | 用途 |
|----|------|------|
| `main`(down) | 纯官方镜像,快进同步 `cloud/main` | 官方代码存档、diff 基底 |
| `dev-custom`(down) | 官方最新 + 全部定制(冲突已解、URL 已改写) | **实际产品分支**;补丁导出源 |
| `dev-patch`(down) | `7cfb1a7` + `patch/` 目录 | 补丁分发/存档,不参与开发 |

## 五、补丁管道(已建成并通过校验)

`dev-patch:patch/` 目录内容:

| 文件 | 内容 | 校验结果 |
|------|------|----------|
| `01-up-main.patch` | `7cfb1a7 → up/main`(194 KB) | ✓ 打回基底复现 up 树 |
| `02-cloud-main.patch` | `7cfb1a7 → cloud/main`(842 KB) | ✓ 打回基底复现 cloud 树 |
| `03-up-on-cloud.patch` | `cloud/main → dev-custom`(101 KB) | ✓ 打在 cloud 上复现 dev-custom 树 |
| `METADATA.json` | 全部 SHA 固定(含前端子模块指针) | ✓ 与树一致 |
| `apply.sh` | 端到端应用脚本(打补丁→拉子模块→构建前端→构建后端) | — |
| `verify.sh` | 7 项自动校验 | ✓ ALL CHECKS PASSED |

## 六、与分叉点相比的工作量

| 方向 | 提交数 | 改动规模(自分叉点) |
|------|--------|----------------------|
| 后端定制线独有 | 65(含 24 个纯子模块 bump) | 53 文件,+3103 / −488 |
| 后端官方线独有 | 109 | 181 文件,+17297 / −2065 |
| 前端定制线独有 | 39 | 21 文件,+1915 / −51 |
| 前端官方线独有 | 58 | 163 文件,+25037 / −7600 |

移植时两侧共同修改的文件(冲突区)已全部解决:后端 36 处、前端 10 处。

## 七、复核命令

```bash
# 各分支两两差异(左/右独有提交数)
git rev-list --left-right --count main...cloud/main   # 65  109

# 分叉点
git merge-base main cloud/main                        # 7cfb1a7

# dev-patch 语义校验:除 patch/ 外与 7cfb1a7 无差异
git diff 7cfb1a7 dev-patch -- . ':!patch'             # 期望无输出

# 补丁全集校验(在仓库根目录)
bash patch/verify.sh                                  # 期望 ALL CHECKS PASSED

# 定制线当前落后官方线的量
git fetch cloud && git log --oneline cloud/main ^dev-custom | wc -l
```

## 八、维护要点

1. `cloud` 升级:`down/main` 快进 → `dev-custom` rebase/合并解增量冲突 →
   重新导出 02/03 → 跑 `verify.sh` → amend `dev-patch` 并强推。
2. `up` 出新提交:只移植增量到 `dev-custom`(勿整份重放 01)→ 同上刷新。
3. 两者同时更新:先 rebase 到新 cloud,再叠 up 增量。
4. 前端先行:前端 `dev-custom` 完成并推送后,再更新后端子模块指针。
