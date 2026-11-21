<!-- SPECTRA:START v1.3.0 -->

# Spectra Instructions

This project uses Spectra for Spec-Driven Development(SDD). Specs live in `docs/spectra/specs/`, change proposals in `docs/spectra/changes/`.

## Skills

Each `/spectra-*` skill carries its own trigger description; these are the groups:

- Shape and plan → `/spectra-discuss`, `/spectra-propose`
- Continue tasks for an identified change → `/spectra-apply`
- Update requirements or plans for an identified change → `/spectra-ingest`
- Quality gate → `/spectra-verify`, `/spectra-review`, `/spectra-analyze`, `/spectra-audit`, `/spectra-drift`, `/spectra-debug`
- Finish → `/spectra-archive`, `/spectra-commit`

Explicit skill invocation takes precedence. Apply existing authorization within its unchanged scope.

## Workflow

discuss? → propose → apply ⇄ ingest → verify / review → archive

- `discuss` is optional — skip if requirements are clear
- Requirements change mid-work? Plan mode → `ingest` → resume `apply`

## Parked Changes

Changes can be parked（暫存）— temporarily moved out of `docs/spectra/changes/`. Parked changes won't appear in `spectra list` but can be found with `spectra list --parked`. To restore: `spectra unpark <name>`. The `/spectra-apply` and `/spectra-ingest` skills disclose parking and restore when the named operation is already explicitly requested; respect a known refusal, otherwise ask for missing authorization.

<!-- SPECTRA:END -->

# CLAUDE.md

MacHelpdesk 系列的資源診斷工具。整個系列共用的規則（公開 repo 不寫任何人的環境、只寫實測過的行為、會改設定的動作寫明界線、`/bin/bash` 3.2 相容、Git 流程）在 umbrella repo `MacHelpdesk/mac-helpdesk` 的 CLAUDE.md，這裡不重抄。

## 這個工具特有的

- 範圍是封閉的：CPU、記憶體、登入時會自己啟動的項目。磁碟空間（`mac-disk-space`）、網路（`mac-network-test`）、電池、GPU、溫度都不涵蓋。磁碟讀寫排在之後的版本，要先實測哪些量測不需要管理者權限。
- `res-diag.sh` 的每個子命令都只讀。結束程序與停用 launchd 項目只寫在 skill 的界線表與知識庫的 `command` 裡，由 skill 在使用者同意後執行。要加會改動東西的子命令，先在 SKILL.md 的四張界線表裡決定它屬於哪一類。
- 系統輸入都有 `RES_DIAG_*` 覆寫（程序清單、核心數、負載、記憶體壓力、可用記憶體、swap、`launchctl list`、三個 launchd 目錄、登入項目），測試只用 `tests/fixtures/` 的合成資料。新增訊號時同時加 fixture 與測試。
- 不解析會跟著系統語言改變的輸出：數字來自 `sysctl -n` 與 `LC_ALL=C ps`，launchd 項目來自 plist（`plutil -extract … raw`）。不要改用 `top`、`vm_stat`、`memory_pressure` 的文字輸出。
- 程序名稱、launchd 的 label 與 program 都是別人取的字串。`rows` 把控制字元換成 `?`，輸出才不會多出一行或一欄；新增會印出這些字串的子命令時要經過同樣的處理。
- `kind` 只看路徑與 `~/Library/LaunchAgents`，是線索不是事實。不要依 `kind` 自動決定任何動作；`never` 清單裡「不結束 kind 是 system 的程序」是下限，不是「其他的都可以結束」。
- 知識庫的 `evidence` 只有做過那個解法、再量一次確認改善，才能寫 `verified`。訊號出現過不算。
- fixture 裡的程式名稱都是編的（`Example Editor`、`compiler-frontend`）。不要把真的 `ps` 或 `launchctl list` 輸出貼進 repo：它會列出一個人裝了哪些軟體。
- `timeout` 不是 macOS 內建，腳本不能用。
- 個人的條目與量測紀錄在 `~/.config/mac-resource-diagnose/`，`.gitignore` 已擋這些檔名。
