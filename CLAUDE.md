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
- 資源是封閉的三種：`cpu`、`memory`、`startup`。每個訊號屬於其中一種；每筆條目屬於其中一種，或是 `general`（原因可能跨資源，只有兩個總入口比對）。標成某一種資源的條目只能用那一種資源的訊號，`validate` 會擋。新增資源時要一起改：`kb.js` 的 `RESOURCES`、`res-diag.sh` 的 `probe` 與 `match` 的清單、一對 skill、`tests/test_skills.sh` 的 `ALL`。
- skill 有八個：兩個總入口（`resource-diagnose`、`resource-fix`）與每種資源一對。每個 `SKILL.md` 都有四段封閉的界線（直接做、先問、只說明、不做），標題文字固定，測試會找。`plugin/skills/` 是手寫的文字，沒有產生器；同一個動作在兩個 skill 裡的那一列要一字不差（測試比對 `kill <pid>` 與 `res-diag.sh login-items` 兩列）。
- 需要同意的指令各有擁有它的 skill，這張表是封閉的，測試依字面檢查：`kill <pid>` 只在 `cpu-fix`、`memory-fix`；`launchctl bootout`、`launchctl disable` 與復原用的 `launchctl enable`、`launchctl bootstrap` 只在 `startup-fix`；`res-diag.sh login-items` 只在 `startup-diagnose`、`startup-fix`。名稱是 `-diagnose` 的 skill 與兩個總入口都不帶會改動這台 Mac 的指令。要讓別的 skill 提到這些動作，寫「改用某某 skill」，不要把指令寫進去。
- `res-diag.sh` 的每個子命令都只讀。結束程序與停用 launchd 項目只寫在 skill 的界線表與知識庫的 `command` 裡，由 skill 在使用者同意後執行。要加會改動東西的子命令，先決定它屬於哪一個 skill 的哪一段界線。
- `probe` 與 `match` 的參數是嚴格的：文件寫的寫法以外一律結束碼 64、不印東西，空字串也算。新增參數時用「有沒有給」與「給的值」兩個變數分開記，不要用空字串代表沒有給。
- skill 的文字有三條測試依字面檢查的規則：沒有對到條目不寫成正常（不出現「正常範圍」）；個人條目的指令只給使用者看、不照字串執行（不出現「同意才執行」）；`*-fix` 動手之前重新認出目標。改寫 skill 時保留這些句子，或同時改 `docs/spectra/specs/skill-boundaries/spec.md` 與測試。
- `res-diag.sh` 沒有子命令時印的用法，是檔頭註解到第二個空註解行為止。在子命令清單中間不要加空的 `#` 行。
- 系統輸入都有 `RES_DIAG_*` 覆寫（程序清單、核心數、負載、記憶體壓力、可用記憶體、swap、`launchctl list`、三個 launchd 目錄、`/System/Library` 的兩個 launchd 目錄、登入項目），測試只用 `tests/fixtures/` 的合成資料。新增訊號時同時加 fixture 與測試。
- 不解析會跟著系統語言改變的輸出：數字來自 `sysctl -n` 與 `LC_ALL=C ps`，launchd 項目來自 plist（`plutil -extract … raw`）。不要改用 `top`、`vm_stat`、`memory_pressure` 的文字輸出。
- 條目的文字欄位不接受控制字元（`kb.js` 的 `isEntryText`，只在 `checkProblems` 裡用）：換行或 tab 會讓 `match` 多出一行或一欄。它只套用在規格列的欄位（title、cause、symptoms、confirm，以及 fix 的 action、command、side_effects、verify）；id、`not_fixes`、訊號的說明與 `never` 清單仍用 `isText`，不要把兩者合併，否則原本合法的個人檔案會整份被略過。條目新增會印出來的欄位時，用 `isEntryText` 檢查。
- `launchctl disable` 記的是 label，不是 plist。任何會依 label 動手的步驟，先用 `res-diag.sh label` 確認這個 label 只出現在被同意的那一個檔案。它由 `plugin/scripts/labels.js` 解析每一個 plist 再比對，不要改回先用 `grep` 篩檔案：用字元參照寫的 label 會漏掉。讀不了的資料夾或檔案要讓結束碼變成 5，不能當成沒有相符的。
- skill 把 label 代入指令之前要檢查字元（只含英數字、`.`、`-`、`_`），路徑放在單引號裡。新增會把別人取的字串放進指令的步驟時，寫上同樣的規則。
- 程序名稱、launchd 的 label 與 program 都是別人取的字串。`rows` 把控制字元換成 `?`，輸出才不會多出一行或一欄；新增會印出這些字串的子命令時要經過同樣的處理。
- `kind` 只看路徑與 `~/Library/LaunchAgents`，是線索不是事實。不要依 `kind` 自動決定任何動作；`never` 清單裡「不結束 kind 是 system 的程序」是下限，不是「其他的都可以結束」。
- 知識庫的 `evidence` 只有做過那個解法、再量一次確認改善，才能寫 `verified`。訊號出現過不算。
- fixture 裡的程式名稱都是編的（`Example Editor`、`compiler-frontend`）。不要把真的 `ps` 或 `launchctl list` 輸出貼進 repo：它會列出一個人裝了哪些軟體。
- `timeout` 不是 macOS 內建，腳本不能用。
- 個人的條目與量測紀錄在 `~/.config/mac-resource-diagnose/`，`.gitignore` 已擋這些檔名。
