# ビットストリーム書き込み手順

## 毎回必要な手順

### Step 1: CH347 を WSL に接続 (Windows PowerShell 管理者)

```powershell
usbipd attach --wsl --busid 5-4
```

### Step 2: 書き込み (WSL Ubuntu)

**SRAM に書き込む場合** (電源 OFF でリセット、動作確認用)

```bash
ch347prog-sram /mnt/c/path/to/your.bit
```

**SPI Flash に書き込む場合** (電源 OFF でも保持、恒久書き込み)

```bash
ch347prog-flash /mnt/c/path/to/your.bit
```

> **注意**: sector 33 付近で数分間メッセージが止まるが **フリーズではない**。
> `Info : Close the CH347.` が出るまで待つこと。
> 電源投入後は数秒のロード時間があってから LED が動き始める。

---

## デモビットストリーム

```bash
# LED 点滅 (1000Hz)
ch347prog-sram /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/demo/i9plus/blinky_1000.bit

# LED 点滅 (10Hz)
ch347prog-sram /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/demo/i9plus/blinky_10.bit
```

## Vivado で生成したビットストリーム

```bash
ch347prog-sram /mnt/c/Users/yakun/workspace/vivado_projects/<プロジェクト名>/runs/impl_1/<top>.bit
```

---

## 注意事項

- PC 再起動・USB 抜き差し後は毎回 Step 1 の `usbipd attach` が必要
- Flash アンロックは初回のみ実施済み。再実行不要
- `usbipd list` で BUSID `5-4` が変わっていないか確認すること
