# mac-resource-diagnose

Mac 變慢、風扇一直轉、一登入就很卡時，量測 CPU 負載、記憶體壓力與 swap、最吃資源的程序，以及登入時會自己啟動的背景項目，對照一份已知狀況的知識庫分辨是哪一種。

與 [`mac-printer-setup`](https://github.com/MacHelpdesk/mac-printer-setup)、[`mac-dropbox-fix`](https://github.com/MacHelpdesk/mac-dropbox-fix)、[`mac-timemachine-fix`](https://github.com/MacHelpdesk/mac-timemachine-fix) 同一個系列：先量測，再判讀，最後才動手。

> **狀態：v0.1.0。** 量測的子命令在 macOS 27.3 上實跑過一次。知識庫每一筆都是 `unverified`：訊號在那一次實際量到，但沒有任何一個解法在這個工具裡執行過，也沒有量過做了之後改善多少。

## 它分辨什麼

「電腦很慢」有幾種原因，處理方式完全不同：

| 你遇到的 | 量到的 | 知識庫條目 |
|---|---|---|
| 只開幾個程式，風扇卻一直轉 | 一個程序長時間用滿一個以上的核心 | `single-process-busy` |
| 編譯、測試或好幾個自動化工作同時跑的時候整台變慢 | 很多同名的程序同時在跑，負載超過核心數 | `many-parallel-jobs` |
| 操作有延遲，但 CPU 沒有用滿 | 負載是核心數的好幾倍，CPU 使用量卻不高 | `load-above-cpu` |
| 切換程式或分頁時停頓 | 系統回報記憶體壓力不是正常 | `memory-pressure` |
| 開很久的 app 切回來要等一下 | swap 用了好幾 GB | `heavy-swap` |
| 登入之後要等一陣子才順，選單列很多圖示 | 很多項目設定成登入後自己啟動 | `many-startup-agents` |
| 什麼都沒開，背景仍有幾十個第三方程序 | 正在執行的第三方背景服務很多 | `many-background-services` |

吃 CPU 不一定是問題：編譯、轉檔、建立索引本來就會用滿。這個工具量出「是誰、是哪一種」，哪些是你要它跑的由你判斷。

範圍是封閉的：CPU、記憶體、登入時會自己啟動的項目。磁碟剩餘空間（[`mac-disk-space`](https://github.com/MacHelpdesk/mac-disk-space)）、網路（[`mac-network-test`](https://github.com/MacHelpdesk/mac-network-test)）、電池、GPU、溫度都不處理。磁碟讀寫還量不到，`load-above-cpu` 的原因因此只能說到「在等某樣東西」。

## 三個部分

| 部分 | 位置 | 做什麼 |
|---|---|---|
| skill | `/mac-resource-diagnose:resource-diagnose` | 量測 → 對照知識庫 → 向你說明 → 依界線處理 → 再量一次並記錄 |
| 知識庫 | `plugin/data/problems.json` | 每筆狀況的症狀、訊號、原因、可以做的事、驗證到哪裡，以及任何情況都不做的事 |
| 腳本 | `plugin/scripts/res-diag.sh` | `probe`、`match`、`list`、`show`、`validate`、`top`、`groups`、`startup`、`login-items`，全部只讀 |

## 安裝

```
/plugin marketplace add MacHelpdesk/mac-helpdesk
/plugin install mac-resource-diagnose@mac-helpdesk
```

然後對 Claude 說：

```
我的 Mac 好慢，幫我看是什麼在吃資源
```

## 直接用腳本

不透過 Claude 也可以跑，全部只讀：

```bash
bash plugin/scripts/res-diag.sh probe          # 訊號，一行一個
bash plugin/scripts/res-diag.sh match          # 對到知識庫的哪幾筆
bash plugin/scripts/res-diag.sh groups 10      # 依 app 加總，最吃 CPU 的十個
bash plugin/scripts/res-diag.sh top 10 mem     # 最佔記憶體的十個程序
bash plugin/scripts/res-diag.sh startup        # 會自己啟動的 launchd 項目
bash plugin/scripts/res-diag.sh show heavy-swap
```

`probe` 的輸出像這樣（數字是舉例）：

```
cpu_count=8
process_count=640
cpu_used_pct_per_core=35
top_process_cpu_pct=98
busy_processes=1
busy_group_size=1
load_per_core_pct=120
load5_per_core_pct=90
memory_pressure=normal
memory_free_pct=41
swap_used_mb=512
startup_user_agents=6
startup_system_items=14
running_third_party_services=9
```

`login-items` 會向 System Events 詢問「登入時打開」的清單，第一次執行時 macOS 可能跳出權限詢問。

## 登入時啟動的東西在哪裡

系統設定的畫面看不到全部。它們分散在三個地方：

| 地方 | 怎麼看 | 怎麼關 |
|---|---|---|
| 系統設定 > 一般 > 登入項目與延伸功能 的「登入時打開」與「允許在背景執行」 | `res-diag.sh login-items`（只有「登入時打開」） | 在系統設定裡關 |
| `~/Library/LaunchAgents`（使用者層） | `res-diag.sh startup` 的 `user-agent` | skill 逐項問過你之後用 `launchctl` 停用，可以復原 |
| `/Library/LaunchAgents`、`/Library/LaunchDaemons`（系統層） | `res-diag.sh startup` 的 `system-agent`、`system-daemon` | 需要管理者權限。skill 只告訴你它是哪個軟體的，由你從該軟體的設定或解除安裝程式處理 |

## 會動到東西的只有這三件，都先問

| 動作 | 問的時候會告訴你 |
|---|---|
| 讀「登入時打開」的清單 | 可能跳出權限詢問 |
| `kill <pid>`，對象是你自己的、不屬於系統的程序 | 是哪個程式、用了多少、沒存檔的內容可能遺失 |
| 停用一個使用者層的 launchd 項目 | 是哪個軟體的、什麼功能會停、怎麼復原 |

任何情況都不做的事（寫在知識庫的 `never`）：不結束系統的程序、不用 `kill -9` 或 `killall`、不刪除或修改任何 plist 與 app、不執行 `sudo` 也不停用系統層的項目、不執行 `purge` 也不安裝清理軟體。

## 個人的條目與紀錄

這個 repo 只放方法與工具。你的程序清單、裝了哪些軟體、量測紀錄都不在這裡。

- 自己遇過的狀況：`~/.config/mac-resource-diagnose/problems.local.json`，格式見 skill 的〈新增條目〉。個人條目沒有經過審查，skill 執行裡面的任何指令之前都會先問。
- 量測紀錄：`~/.config/mac-resource-diagnose/records/`。

## 驗證到哪裡

| 項目 | 狀態 |
|---|---|
| `probe`、`top`、`groups`、`startup` 在真的機器上跑 | 已實測（macOS 27.3，2026-11-22）：一台 18 核、近三千個程序的機器，`probe` 約 4 秒 |
| `login-items` | 已實測一次：在已經給過權限的機器上讀到清單。第一次執行時的權限詢問、按了不允許之後的行為都沒有看過 |
| 訊號的判讀與門檻 | 只依一台機器的一次量測訂的，沒有和其他機器比較過 |
| 知識庫七筆的訊號 | 六筆在那一次實際量到；`memory-pressure` 只短暫出現過一次、沒有留下當時的值 |
| 知識庫的解法：`kill`、`launchctl bootout`／`disable` 與復原 | 未驗證。沒有在這個工具裡執行過，也沒有量過做了之後改善多少 |
| 腳本對合成輸入的行為 | 只在測試裡驗過（`tests/test_probe.sh` 55 項、`tests/test_kb.sh` 24 項） |
| 其他 macOS 版本、Intel 的 Mac | 未驗證 |

## 需求

- macOS（實測 27.3）。只用系統內建的 `/bin/bash`、`ps`、`sysctl`、`launchctl`、`plutil`、`osascript`，不需要安裝任何東西。

## 開發

```bash
bash tests/test_probe.sh
bash tests/test_kb.sh
bash scripts/check-privacy.sh
```

測試只讀 `tests/fixtures/` 的合成資料，不看這台機器在跑什麼。

## 授權

MIT
