# Windows / WSL 環境での開発手順 (Colorlight i9plus-v6.1)

## 前提

- **ボード**: Colorlight i9plus-v6.1 (Xilinx XC7A50T-FGG484, Artix-7)
- **JTAG アダプタ**: CH347 (ボード拡張基板に内蔵, USB VID:PID = `1a86:55dd`)
- **インストール済み**: Vivado / Vitis (Windows)

---

## 全体フロー

```
Vivado (Windows)           WSL2 (Ubuntu)
─────────────────          ──────────────────────────────────────
  Verilog + XDC              openocd (CH347 パッチ適用版)
       ↓                            ↑
  bitstream (.bit)  ───────→  ch347prog-sram / ch347prog-flash
                    (ファイル共有)
```

ビットストリーム生成は Vivado (Windows)、書き込みは WSL の openocd で行うのが最もシンプルです。

---

## Part 1: WSL2 セットアップ

### 1-1. WSL2 + Ubuntu インストール

PowerShell (管理者) で実行:

```powershell
wsl --install
# Ubuntu が既に入っている場合はスキップ
wsl --set-default-version 2
```

その後 Ubuntu を起動して初期ユーザー設定を完了させる。

### 1-2. usbipd-win インストール (CH347 を WSL に転送するため)

PowerShell (管理者):

```powershell
winget install --interactive --exact dorssel.usbipd-win
```

インストール後は **一度再起動** する。

---

## Part 2: WSL 内で openocd (CH347 対応版) をビルド

Ubuntu (WSL) で実行:

```bash
# 依存パッケージ
sudo apt update
sudo apt install -y git make pkg-config autoconf libtool \
    libhidapi-dev libusb-1.0-0-dev libftdi1-dev \
    build-essential

# openocd をクローン (特定コミットを使用)
cd ~
git clone https://github.com/openocd-org/openocd.git
cd openocd
git checkout 3a4f445bd92101d3daee3715178d3fbff3b7b029

# CH347 パッチを適用
cp /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/tools/openocd-patch-for-ch347/ch347.patch .
git apply --reject --whitespace=fix ch347.patch

# ビルド
./bootstrap
./configure --enable-ch347 --disable-werror
make -j$(nproc)

# ※ make install は不要 (パスは直接指定する)
echo "openocd build done: $(pwd)/src/openocd"
```

ビルド完了後、`~/openocd/src/openocd` が実行バイナリになります。

### openocd パスを ch347prog スクリプトに設定

WSL 上で:

```bash
# スクリプトをコピー (WSL ホームに持ってくる)
cp -r /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/tools ~/colorlight-tools
chmod +x ~/colorlight-tools/ch347prog*

# ch347prog の OPENOCD_ROOT を編集
sed -i 's|OPENOCD_ROOT=.*|OPENOCD_ROOT=$HOME/openocd|' ~/colorlight-tools/ch347prog

# PATH に追加 (.bashrc に追記)
echo 'export PATH=$PATH:$HOME/colorlight-tools' >> ~/.bashrc
source ~/.bashrc
```

編集内容を確認:

```bash
head -10 ~/colorlight-tools/ch347prog
# OPENOCD_ROOT=$HOME/openocd  ← この行になっていればOK
```

---

## Part 3: CH347 を WSL に接続 (usbipd)

**CH347 を USB で PC に接続した状態で**、PowerShell (管理者) で実行:

```powershell
# 接続されている USB デバイス一覧を確認
usbipd list
```

出力例:
```
BUSID  VID:PID    DEVICE
2-3    1a86:55dd  USB-Enhanced-SERIAL CH347  ← これが CH347
```

```powershell
# CH347 を WSL に転送 (BUSID は実際の値に変わる)
usbipd bind --busid 2-3
usbipd attach --wsl --busid 2-3
```

WSL 側で確認:

```bash
lsusb | grep 1a86
# Bus 001 Device 003: ID 1a86:55dd QinHeng Electronics ... が表示されればOK

# udev ルールを追加 (sudo なしでアクセスするため)
echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55dd", MODE="0666"' \
    | sudo tee /etc/udev/rules.d/99-ch347.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

---

## Part 4: Flash アンロック (初回のみ必須)

**必ず最初に実行してください。デフォルトで Flash は書き込み禁止になっています。**

```bash
ch347prog-sram /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/tools/unlock_flash_xc7a50t.bit
```

成功すると openocd のログに `flash protect 0 0 50 off` 相当の処理が流れます。

---

## Part 5: Vivado でビットストリームを生成

### 5-1. 新規プロジェクト作成

1. Vivado を起動
2. **Create Project** → **RTL Project**
3. Part 選択: `xc7a50tfgg484-1`
   - Family: **Artix-7**
   - Package: **fgg484**
   - Speed Grade: **-1**

### 5-2. ソースファイルの追加

Verilog ファイルを追加する。blinky の例として [blinky-i9plus.v](blinky-i9plus.v) を参照してください。
(このドキュメントと同じ `docs/` ディレクトリに置いてあります)

### 5-3. XDC 制約ファイルの追加

[blinky-i9plus.xdc](blinky-i9plus.xdc) を Constraints として追加します。

主要な制約 (i9plus-v6.1 の固定ピン):

| 信号         | FPGA ピン | 電圧      |
|-------------|-----------|---------|
| クロック 25MHz | K4        | LVCMOS33 |
| LED D2      | A18       | LVCMOS33 |

### 5-4. 合成 → 実装 → ビットストリーム生成

```
Flow Navigator:
  Run Synthesis    → 完了を待つ
  Run Implementation → 完了を待つ
  Generate Bitstream → 完了を待つ
```

Tcl Console で一括実行する場合:

```tcl
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```

ビットストリームは以下に生成されます:
```
<project_dir>/<project_name>.runs/impl_1/<top_module>.bit
```

---

## Part 6: 書き込み

### SRAM に書き込む (電源 OFF でリセット、テスト用)

```bash
# Windows パスはそのまま /mnt/c/... でアクセス可能
ch347prog-sram /mnt/c/Users/yakun/workspace/vivado_projects/blinky/blinky.runs/impl_1/blink_top.bit
```

### SPI Flash に書き込む (電源 OFF でも保持)

```bash
ch347prog-flash /mnt/c/Users/yakun/workspace/vivado_projects/blinky/blinky.runs/impl_1/blink_top.bit
```

書き込み後、ボードの LED (D2) が点滅すれば成功です。

---

## Part 7: デモビットストリームで動作確認 (ツールなしで即試せる)

ツールチェーンのセットアップが完了していれば、`demo/i9plus/` にある既成 .bit ファイルですぐに試せます:

```bash
# LED 点滅デモ (1000Hz)
ch347prog-sram /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/demo/i9plus/blinky_1000.bit
```

---

## トラブルシューティング

### CH347 が WSL から見えない

```bash
# usbipd attach が必要か確認
# Windows PowerShell (管理者):
usbipd list
usbipd attach --wsl --busid <BUSID>
```

PC を再起動や USB 抜き差しした場合は `attach` をやり直す必要があります。自動化する場合:

```powershell
# Windows の Task Scheduler または startup script に追加
usbipd attach --wsl --busid 2-3
```

### openocd が "Error: libusb_open() failed with LIBUSB_ERROR_ACCESS"

```bash
# udev ルールを確認
cat /etc/udev/rules.d/99-ch347.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
# それでもダメな場合は sudo をつけて ch347prog を実行
sudo ch347prog-sram xxx.bit
```

### openocd が "Error: ch347 driver not compiled in"

CH347 パッチが正しく適用されているか確認:

```bash
~/openocd/src/openocd --version
# "Open On-Chip Debugger" が表示される
# configure時に --enable-ch347 を付けたか確認
grep -r "ch347" ~/openocd/src/jtag/drivers/ | head -5
```

### Vivado: デバイスが見つからない (xc7a50t が選択肢にない)

Vivado のインストール時に **Artix-7** のデバイスサポートが含まれているか確認。
Vivado → Help → Add Design Tools or Devices から追加可能。

---

## 付録: Flash 復元 (工場出荷状態に戻す)

```bash
# 最新の工場 Flash イメージを書き込む
ch347prog-flash /mnt/c/Users/yakun/workspace/i9plus/Colorlight-FPGA-Projects/firmware/flash_image_20220122.bin
```

---

## 参考リンク

- [usbipd-win](https://github.com/dorssel/usbipd-win)
- [WCH CH347 (openocd パッチ元)](https://github.com/WCHSoftGroup/ch347)
- [openXC7 プロジェクト](https://github.com/openXC7/demo-projects)
- [Colorlight i9plus ピン配置](../Colorlight-FPGA-Projects/colorlight_i9plus_v6.1.md)
