# mac-resource-diagnose

Mac 變慢、風扇一直轉、一登入就很卡時，量測 CPU 負載、記憶體壓力與 swap、最吃資源的程序，以及登入時會自己啟動的背景項目，對照一份已知狀況的知識庫分辨是哪一種。

與 [`mac-printer-setup`](https://github.com/MacHelpdesk/mac-printer-setup)、[`mac-dropbox-fix`](https://github.com/MacHelpdesk/mac-dropbox-fix)、[`mac-timemachine-fix`](https://github.com/MacHelpdesk/mac-timemachine-fix) 同一個系列：先量測，再判讀，最後才動手。

> **狀態：v0.2.0。** 量測的子命令在 macOS 27.3 上實跑過。知識庫每一筆都是 `unverified`：訊號實際量到過，但沒有任何一個解法在這個工具裡執行過，也沒有量過做了之後改善多少。八個 skill 的界線只用測試檢查過文字，沒有用真的對話跑過。

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
| skill | `plugin/skills/`，八個 | 見下一節 |
| 知識庫 | `plugin/data/problems.json` | 每筆狀況屬於哪一種資源、症狀、訊號、原因、可以做的事、驗證到哪裡，以及任何情況都不做的事 |
| 腳本 | `plugin/scripts/res-diag.sh` | `probe`、`match`、`list`、`show`、`validate`、`top`、`groups`、`startup`、`label`、`login-items`，全部只讀 |

## 八個 skill

每一種資源一對：`diagnose` 只量測與判讀，不結束程序、不停用項目、不改設定，會寫的只有 `~/.config/mac-resource-diagnose/` 裡這次的紀錄與你自己的條目（腳本執行中用的暫存檔不算，結束時就刪掉）；`fix` 自己先量一次，再逐項問要不要動手。不知道是哪一種資源時用總入口。

| 你想做的 | 只想知道原因 | 要動手處理 |
|---|---|---|
| 還不知道是什麼造成的 | `resource-diagnose` | `resource-fix` |
| CPU | `cpu-diagnose` | `cpu-fix` |
| 記憶體 | `memory-diagnose` | `memory-fix` |
| 登入時啟動的項目 | `startup-diagnose` | `startup-fix` |

`resource-fix` 自己不動手，會寫的也只有同一個資料夾：它量測全部、判斷是哪一種資源，再交給那一種的 fix。知識庫的 `load-above-cpu` 原因可能跨資源，只有兩個總入口會比對它。

從 0.1.0 升級：`resource-diagnose` 不再結束程序或停用項目，那些動作移到 `cpu-fix`、`memory-fix`、`startup-fix`。

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
bash plugin/scripts/res-diag.sh probe memory   # 只量一種資源：cpu、memory 或 startup
bash plugin/scripts/res-diag.sh match          # 對到知識庫的哪幾筆
bash plugin/scripts/res-diag.sh match --resource cpu   # 只比對一種資源的條目（另有 general）
bash plugin/scripts/res-diag.sh groups 10      # 依 app 加總，最吃 CPU 的十個
bash plugin/scripts/res-diag.sh top 10 mem     # 最佔記憶體的十個程序
bash plugin/scripts/res-diag.sh startup        # 會自己啟動的 launchd 項目
bash plugin/scripts/res-diag.sh label com.example.sync   # 這個 label 出現在哪些 plist，含 /System/Library；結束碼 5 表示有檔案讀不了
bash plugin/scripts/res-diag.sh show heavy-swap
```

`match` 的 `--resource` 可以寫在檔案前面或後面；`--resource general` 沒有給檔案時會量全部三種資源，因為跨資源的條目可以用任何訊號。除了這些寫法，`probe` 與 `match` 不接受別的：空的資源、多出來的參數、第二個檔案、不認得的選項，結束碼都是 64，stdout 不印任何東西（原因印在 stderr）。打錯的參數不會變成「量全部」。沒有對到任何條目時 `match` 的結束碼是 3，這只表示沒有對到已知的狀況，不表示數字正常。

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

## 要先問的只有這三件

| 動作 | 寫在哪些 skill | 問的時候會告訴你 |
|---|---|---|
| 讀「登入時打開」的清單（只讀，但可能跳出權限詢問） | `startup-diagnose`、`startup-fix` | 可能跳出權限詢問 |
| `kill <pid>`，對象是你自己的、不屬於系統的程序 | `cpu-fix`、`memory-fix` | 是哪個程式、用了多少、沒存檔的內容可能遺失 |
| 停用一個使用者層的 launchd 項目 | `startup-fix` | 是哪個軟體的、什麼功能會停、怎麼復原（先 `launchctl enable` 再重新載入；只登出再登入不會解除停用） |

會改動這台 Mac 的只有後兩件，都只在名稱是 `-fix` 的 skill 裡。`tests/test_skills.sh` 檢查這些指令與復原用的指令沒有出現在別的 skill。

同意的是列出來的那幾個目標。動手之前 skill 會重新認出目標，認不出來就不做：

- 結束程序：只列出屬於你這個使用者的程序。問你的程式、啟動時間、CPU 與記憶體取自同一次讀取（前後各讀一次身分，相同才採用），不拿先前量測的數字來配。送出時用同一道指令比對使用者編號、啟動時間與程式，和問的時候不一樣就不送出。這是盡力核對，不是保證：啟動時間只到秒，比對與送出之間仍有極短的空檔。所以 skill 會先請你在 app 裡正常結束。
- 停用項目：先查這個 label 出現在哪些 plist（`res-diag.sh label`，解析使用者層、`/Library` 與 `/System/Library` 的每一個 plist）。有檔案讀不了時不知道有沒有同名的項目，就不做。只有恰好一個、而且就是你同意的那個使用者層 plist 才繼續，並記下那個檔案的檢查碼；別的地方也有同名的項目時不代為停用，因為停用記的是名稱，另一個也會跟著不啟動。其餘分三種：載入的是你同意的那一個 plist，先卸載、成功才停用；沒有載入，只停用；載入的是別的位置，不做。
- 這些檢查在問你的時候做一次，動手之前再做一次；結果不同（包含檔案的檢查碼變了）、或要跑的指令和問的時候說的不一樣，就重新問。
- 停用之後分開確認「已經卸載」與「已經停用」，查不到的說無法確認。

## 個人的條目與紀錄

這個 repo 只放方法與工具。你的程序清單、裝了哪些軟體、量測紀錄都不在這裡。

- 自己遇過的狀況：`~/.config/mac-resource-diagnose/problems.local.json`，格式見 `resource-diagnose` 的〈新增條目〉。個人條目沒有經過審查，也不會讓 skill 能做的事變多：裡面的指令只給你看，skill 不照那些字串執行，只執行它自己寫明的指令。文字欄位含有換行、tab 這類控制字元的個人條目不會通過 `validate`，整份個人檔案會被略過並說明原因。
- 量測紀錄：`~/.config/mac-resource-diagnose/records/`。

## 驗證到哪裡

| 項目 | 狀態 |
|---|---|
| `probe`、`top`、`groups`、`startup` 在真的機器上跑 | 已實測（macOS 27.3，2026-11-22）：一台 18 核、近三千個程序的機器，`probe` 約 4 秒 |
| `probe cpu`、`probe memory`、`probe startup`、`match --resource` 的四種值、`show` 的 resource 行 | 已實測（macOS 27.3，2026-11-22）：各自只印出該資源的訊號或條目 |
| `login-items` | 已實測一次：在已經給過權限的機器上讀到清單。第一次執行時的權限詢問、按了不允許之後的行為都沒有看過 |
| 訊號的判讀與門檻 | 只依一台機器的一次量測訂的，沒有和其他機器比較過 |
| 知識庫七筆的訊號 | 七筆都實際量到過：六筆在 0.1.0 的那一次，`memory-pressure` 在 2026-11-22 的另一次量測（當時是 warn） |
| `res-diag.sh label` | 已實測（macOS 27.3，2026-11-22）：解析五個資料夾約九百個 plist，一秒內回來；那台機器上有一個 label 同時出現在使用者層與 `/Library`，查得出兩列；一個指向已不存在檔案的捷徑被略過。讀不了的 plist 與用字元參照寫的 label 只在測試裡驗過 |
| 動手前後認出目標用的唯讀指令：`ps -o uid=,lstart=,comm= -p`、`launchctl print`、`launchctl print-disabled` | 指令本身已實測（macOS 27.3，2026-11-22），包含 `launchctl print` 對不存在的服務回報 `Could not find service`。pid 被重複使用、同意之後檔案被換掉、沒有載入的項目只停用、停用之後的輸出，這幾種情形都沒有實際遇過 |
| 知識庫的解法：`kill`、`launchctl bootout`／`disable` 與復原 | 未驗證。沒有在這個工具裡執行過，也沒有量過做了之後改善多少 |
| 腳本對合成輸入的行為 | 只在測試裡驗過（`tests/test_probe.sh` 111 項、`tests/test_kb.sh` 92 項） |
| 八個 skill 的界線 | 只檢查過文字（`tests/test_skills.sh` 245 項）。Claude 讀了之後是否照做、是否選到對的那一個 skill，沒有用真的對話跑過 |
| 其他 macOS 版本、Intel 的 Mac | 未驗證 |

## 需求

- macOS（實測 27.3）。只用系統內建的 `/bin/bash`、`ps`、`sysctl`、`launchctl`、`plutil`、`cksum`、`osascript`，不需要安裝任何東西。

## 開發

```bash
bash tests/test_probe.sh
bash tests/test_kb.sh
bash tests/test_skills.sh
bash scripts/check-privacy.sh
```

測試只讀 `tests/fixtures/` 的合成資料，不看這台機器在跑什麼。

## 授權

MIT
