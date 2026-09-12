# niama-skills

Niama 的个人 Skill 源仓库。仓库根目录和每个专项子目录都包含独立的 `SKILL.md`，可由 CC Switch 从同一个 Git 仓库统一识别、安装和更新。

## 目录

- `SKILL.md`：通用工作习惯和总入口
- `niama-web-api-reverse/`：Web API 与前端签名分析
- `niama-api-client/`：HAR 分析与 API 客户端生成
- `niama-js-runtime/`：Node.js 补环境与风控链路复现
- `niama-protocol-reverse/`：协议逆向
- `niama-identity/`：身份相关请求

## 本地配置

将本仓库根目录配置为 Skill 管理器的 Git 源。CC Switch 刷新后应识别根目录及专项子目录中的技能。
具体安装目标由 Skill 管理器负责，不在仓库中硬编码。

## 日常更新

本 Git 工作区是唯一编辑源。不要直接修改 CC Switch 或其他客户端的安装目录；安装目录只是运行副本，具体位置由客户端和当前机器环境决定。

标准流程：

```powershell
cd <你的 niama-skills Git 工作区>

# 修改本仓库后执行
powershell -ExecutionPolicy Bypass -File .\scripts\validate-all.ps1
git add .
git commit -m "update personal skills"
git push
```

然后在 CC Switch 界面点击刷新/更新，最后用新会话验证。`<你的 niama-skills Git 工作区>` 只是示意，不要把它写入 Skill 文件。

远程仓库：

```powershell
git remote -v
```
