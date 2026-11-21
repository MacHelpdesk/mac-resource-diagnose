# Changelog

## 0.1.0 — 2026-11-22

第一版。Mac 變慢時量測 CPU、記憶體與登入時會自己啟動的項目，對照知識庫分辨是哪一種狀況。

### Scripts

- `res-diag.sh probe`：核心數、程序數、每核心的 CPU 使用量與負載、最忙的單一程序、同名程序同時在跑的份數、記憶體壓力與可用百分比、swap、登入後會自己啟動的項目數、正在執行的第三方背景服務數。
- `res-diag.sh top`、`groups`：最吃 CPU 或記憶體的程序，以及依 app 加總。
- `res-diag.sh startup`：三個 launchd 目錄裡的項目，會不會自己啟動、現在有沒有在跑。
- `res-diag.sh login-items`：系統設定「登入時打開」的清單。
- `match`、`list`、`show`、`validate`：讀知識庫。
- 全部只讀。

### Knowledge base

七筆：`single-process-busy`、`many-parallel-jobs`、`load-above-cpu`、`memory-pressure`、`heavy-swap`、`many-startup-agents`、`many-background-services`。任何情況都不做的事五項。

### Skill

- `resource-diagnose`：量測 → 對照知識庫 → 向使用者說明 → 依界線處理 → 再量一次並記錄。
- 先問才做的只有三件：讀登入項目（可能跳出權限詢問）、`kill <pid>`、停用使用者層的 launchd 項目。系統層的項目與系統設定裡的登入項目只說明步驟。

### 實測範圍

macOS 27.3，一台 18 核的機器，2026-11-22。

- 已實測：五個量測子命令在真的機器上跑；六筆條目的訊號在那一次實際量到。
- 未驗證：所有解法（`kill`、`launchctl bootout`／`disable` 與復原）都沒有在這個工具裡執行過，也沒有量過做了之後改善多少；門檻只依這一次量測訂的；`login-items` 第一次執行時的權限詢問；其他 macOS 版本與 Intel 的 Mac。
