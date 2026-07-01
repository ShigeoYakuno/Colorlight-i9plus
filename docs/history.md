# 環境構築履歴 - Colorlight i9plus-v6.1

## 完了状況

| ステップ | 内容 | 状態 |
|---------|------|------|
| Part 1 | WSL2 セットアップ | ✅ 完了 |
| Part 2 | openocd (CH347対応) ビルド | ✅ 完了 |
| Part 3 | usbipd-win インストール / CH347 を WSL に接続 | ✅ 完了 |
| Part 4 | Flash アンロック | ✅ 完了 |
| Part 5 | Vivado でビットストリーム生成 | ✅ 完了 |
| Part 6 | ボードへの書き込み・LED 点滅確認 | ✅ 完了 |

---

## 環境

- **OS**: Windows 11 + WSL2 (Ubuntu 22.04)
- **FPGA ボード**: Colorlight i9plus-v6.1
- **FPGA**: Xilinx XC7A50T-FGG484 (Artix-7)
- **JTAG アダプタ**: CH347 (ボード内蔵, USB VID:PID = `1a86:55dd`, COM6 として認識)
- **Vivado**: インストール済み (Windows)
- **PetaLinux 2023.2**: WSL 内にインストール済み (`.bashrc` から自動ロード)

---

## Part 1: WSL2 セットアップ

WSL2 + Ubuntu 22.04 はインストール済みのため作業なし。

---

## Part 2: openocd (CH347 パッチ適用版) のビルド

すべて **WSL (Ubuntu)** のターミナルで実行。

### 2-1. 依存パッケージのインストール

```bash
sudo apt update && sudo apt install -y \
    git make pkg-config autoconf libtool \
    libhidapi-dev libusb-1.0-0-dev \
    libftdi1-dev build-essential
```

### 2-2. openocd ソースの取得

```bash
cd ~
git clone https://github.com/openocd-org/openocd.git
cd openocd
git checkout 3a4f445bd92101d3daee3715178d3fbff3b7b029
```

特定コミットに固定する理由: CH347 パッチがこのコミットに対して作られているため。  
`detached HEAD` の警告は正常。

### 2-3. CH347 パッチの適用

パッチファイルは Windows 側の以下にある:
```
C:\Users\yakun\workspace\i9plus\Colorlight-FPGA-Projects\tools\openocd-patch-for-ch347\ch347.patch
```

WSL からは `/mnt/c/...` でアクセスできる。

```bash
# パッチをコピー
cp /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/tools/openocd-patch-for-ch347/ch347.patch .

# パッチファイルが Windows 改行 (CRLF) だったため LF に変換 (これをしないと失敗する)
sed -i 's/\r$//' ch347.patch

# パッチ適用
git apply --reject --whitespace=fix ch347.patch
```

**結果**: 以下が正常に適用された:
- `configure.ac` ✅
- `src/jtag/drivers/Makefile.am` ✅
- `src/jtag/drivers/ch347_jtag.c` ✅
- `src/jtag/interfaces.c` ✅
- `tcl/interface/ch347.cfg` ✅

### 2-4. ビルド

```bash
./bootstrap
./configure --enable-ch347 --disable-werror
make -j$(nproc)
```

`configure` 完了時のサマリーで以下が確認できれば成功:
```
Mode 3 of the CH347 devices             yes
```

`make` は約30秒で完了。

### 2-5. 動作確認

```bash
./src/openocd --version
# Open On-Chip Debugger 0.12.0+dev-01192-g3a4f445bd-dirty (2026-06-30-23:55)
```

---

## Part 3: ch347prog スクリプトのセットアップ

### 3-1. スクリプトをホームにコピー

```bash
cp -r /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/tools ~/colorlight-tools
chmod +x ~/colorlight-tools/ch347prog ~/colorlight-tools/ch347prog-sram \
         ~/colorlight-tools/ch347prog-flash ~/colorlight-tools/ch347prog-probe
```

### 3-2. スクリプトの CRLF 変換

Windows からコピーしたスクリプトが CRLF のため変換が必要:

```bash
sed -i 's/\r$//' ~/colorlight-tools/ch347prog \
                  ~/colorlight-tools/ch347prog-sram \
                  ~/colorlight-tools/ch347prog-flash \
                  ~/colorlight-tools/ch347prog-probe
```

### 3-3. openocd パスの設定

`ch347prog` 内の `OPENOCD_ROOT` を実際のパスに書き換える:

```bash
sed -i 's|OPENOCD_ROOT=.*|OPENOCD_ROOT=$HOME/openocd|' ~/colorlight-tools/ch347prog
```

確認:
```bash
head -6 ~/colorlight-tools/ch347prog
# OPENOCD_ROOT=$HOME/openocd  ← この行になっていればOK
```

### 3-4. ch347prog-sram / flash / probe をシンボリックリンクに変更

元のファイルは中身が `ch347prog` と書いてあるだけで引数を渡さない設計だった。  
`ch347prog` スクリプトは `$0` (呼ばれたコマンド名) を見て動作モードを切り替えるため、シンボリックリンクにする必要がある:

```bash
cd ~/colorlight-tools
rm ch347prog-sram ch347prog-flash ch347prog-probe
ln -s ch347prog ch347prog-sram
ln -s ch347prog ch347prog-flash
ln -s ch347prog ch347prog-probe
```

### 3-5. PATH に追加

```bash
echo 'export PATH=$PATH:$HOME/colorlight-tools' >> ~/.bashrc
source ~/.bashrc
```

※ `source ~/.bashrc` 実行時に PetaLinux の警告が出るが無視してよい。

確認:
```bash
which ch347prog-sram
# /home/yakun/colorlight-tools/ch347prog-sram
```

---

## Part 4: usbipd-win のインストールと CH347 の WSL 接続

### 4-1. usbipd-win インストール (Windows PowerShell 管理者)

```powershell
winget install --interactive --exact dorssel.usbipd-win
```

インストール後 PowerShell を再起動。

### 4-2. CH347 を WSL に接続

ボードを USB 接続した状態で PowerShell (管理者) で実行:

```powershell
usbipd list
# 5-4    1a86:55dd  USB-HiSpeed-SERIAL-A CH347 (COM6), USB To UART+JTAG   Not shared

usbipd bind --busid 5-4
usbipd attach --wsl --busid 5-4
```

※ `5-4` は環境により異なる。`1a86:55dd` の行の BUSID を使う。  
※ PC 再起動・USB 抜き差し後は `usbipd attach --wsl --busid 5-4` を再実行する必要がある。

### 4-3. WSL 側での確認

```bash
lsusb | grep 1a86
# Bus 001 Device 002: ID 1a86:55dd QinHeng Electronics USB To UART+JTAG
```

### 4-4. udev ルールの追加 (sudo なしでアクセスするため)

```bash
echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55dd", MODE="0666"' \
    | sudo tee /etc/udev/rules.d/99-ch347.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

---

## Part 5: Flash アンロック (初回のみ)

**デフォルトで Flash は書き込み禁止になっている。初回必須。**

```bash
ch347prog-sram /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/tools/unlock_flash_xc7a50t.bit
```

成功時の出力:
```
sram
Open On-Chip Debugger 0.12.0+dev-01192-g3a4f445bd-dirty ...
Info : JTAG tap: xc7.tap tap/device found: 0x0362c093 (mfg: 0x049 (Xilinx), ...)
loaded file .../unlock_flash_xc7a50t.bit to pld device 0 in 4s 777308us
Info : Close the CH347.
```

`0x0362c093` は XC7A50T の JTAG IDCODE。正常認識。

---

## Part 6: ビットストリームの書き込み

### SRAM への書き込み (電源 OFF でリセット)

```bash
ch347prog-sram /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/demo/i9plus/blinky_1000.bit
```

**結果**: ボードの LED (D2, FPGA ピン A18) が点滅 → 動作確認完了 ✅

### SPI Flash への書き込み (電源 OFF でも保持)

```bash
ch347prog-flash /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/demo/i9plus/blinky_1000.bit
```

**実行時の挙動と注意点**:
- セクターごとに `Info : sector XX took NNN ms` と表示されながら進む
- sector 33 付近で数分間メッセージが止まるが、**フリーズではない**
- Flash 書き込み完了後の JTAG 再起動ステップ (`irscan`) に時間がかかっている
- 最終的に `Info : Close the CH347.` が出れば書き込み完了

実際の出力例:
```
Info : sector 32 took 198 ms
Info : sector 33 took 259 ms
irscan [tap_name instruction]* ['-endstate' state_name]

Info : Close the CH347.
```

**電源投入後の起動について**:
- 電源 OFF → ON 後、すぐには動作しない
- Artix-7 が Flash からビットストリームを読み込む時間（数秒）がかかる
- しばらく待つと LED が点滅し始める → Flash 自動起動確認 ✅
- モードピンの設定は不要（デフォルトで Flash 起動）

---

## Vivado でのビットストリーム生成

- **Part**: `xc7a50tfgg484-1` (Artix-7, 50T, FGG484, Speed -1)
- **XDC 制約ファイル**: `docs/blinky-i9plus.xdc` 参照
- **Verilog サンプル**: `docs/blinky-i9plus.v` 参照

生成された `.bit` ファイルは `<project>.runs/impl_1/<top>.bit` にある。

---

## 毎回起動時に必要な操作

PC 再起動後・USB 抜き差し後は以下を **Windows PowerShell (管理者)** で実行:

```powershell
usbipd attach --wsl --busid 5-4
```

これだけで WSL から CH347 が使えるようになる。

---

## ファイル構成まとめ

```
~/openocd/                    ← CH347 パッチ適用済み openocd (ソース + バイナリ)
  src/openocd                 ← 実行バイナリ

~/colorlight-tools/           ← 書き込みスクリプト群
  ch347prog                   ← メインスクリプト (OPENOCD_ROOT=$HOME/openocd に設定済み)
  ch347prog-sram              ← シンボリックリンク → ch347prog
  ch347prog-flash             ← シンボリックリンク → ch347prog
  ch347prog-probe             ← シンボリックリンク → ch347prog
  ch347.cfg                   ← openocd 用 CH347 設定 (VID:PID = 1a86:55dd)
  bscan_spi_xc7a50t.bit       ← Flash アクセス用ビットストリーム (Flash 書き込み時に使用)
  unlock_flash_xc7a50t.bit    ← Flash アンロック用

/etc/udev/rules.d/
  99-ch347.rules               ← CH347 を sudo なしで使うための udev ルール
```
