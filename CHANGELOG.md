# Changelog

## 0.2.0 — 2026-11-22

一個 skill 拆成八個：每一種資源一對 diagnose 與 fix，加上兩個總入口。量測的內容沒有增加。

### 升級時要知道的

- **`resource-diagnose` 不再結束程序或停用項目。** 它只量測與判讀。要動手改用 `resource-fix`（不知道是哪一種資源時），或直接用 `cpu-fix`、`memory-fix`、`startup-fix`。
- 不帶參數的 `res-diag.sh probe` 與 `res-diag.sh match [FILE]` 輸出不變。
- `~/.config/mac-resource-diagnose/problems.local.json` 不必改：沒有 `resource` 欄位的條目算 `general`。

### Skills

- `resource-diagnose`、`resource-fix`：量測全部、判斷是哪一種資源。`resource-fix` 自己不動手，判斷之後交給對應的 fix。
- `cpu-diagnose`、`cpu-fix`、`memory-diagnose`、`memory-fix`、`startup-diagnose`、`startup-fix`：只量測與比對自己的資源。
- 名稱是 `-diagnose` 的 skill 不帶任何會改動這台 Mac 的指令。`kill <pid>` 只在 `cpu-fix` 與 `memory-fix`，停用 launchd 項目只在 `startup-fix`，讀「登入時打開」的清單只在 `startup-diagnose` 與 `startup-fix`。先問才做的動作與 0.1.0 相同，沒有新增。

### Scripts

- `res-diag.sh probe cpu|memory|startup`：只量一種資源。
- `res-diag.sh match --resource cpu|memory|startup|general [FILE]`：只比對一種資源的條目；沒有給檔案時只量那一種資源。
- `res-diag.sh show ID` 多印一行 `resource:`。
- `validate` 多三項檢查：每個訊號要有 `resource`；條目的 `resource` 只能是四種之一；標成某一種資源的條目只能用那一種資源的訊號。

### Knowledge base

- 14 個訊號與 7 筆條目都標了 `resource`。`load-above-cpu` 是 `general`：它的原因可能在磁碟或記憶體，只有兩個總入口會比對它。

### 實測範圍

macOS 27.3，2026-11-22。

- 已實測：`probe` 的三種資源、`match --resource` 的四種值、`show` 的 resource 行，在真的機器上各跑一次。
- 未驗證：八個 skill 只用測試檢查過文字（`tests/test_skills.sh`），沒有用真的對話確認 Claude 會選到對的 skill、會照界線做；`resource-fix` 交給對應 skill 的那一步也沒有跑過。所有解法仍然沒有在這個工具裡執行過。

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
