# Colorlight i9plus-v6.1 スタートガイド

> **Windows / WSL 環境での詳細手順**: [windows-guide.md](windows-guide.md) を参照してください。
> Vivado がある場合はそちらが最も確実です。

## ボード概要

**Colorlight i9plus-v6.1** は、Xilinx Artix-7 シリーズの FPGA を搭載した小型モジュールです。
オープンソースツールチェーン (openXC7) でビットストリームをコンパイルでき、LED や Ethernet など豊富な機能を持ちます。

### 主要コンポーネント

| コンポーネント | 型番 / 仕様 |
|---------------|-------------|
| **FPGA**       | Xilinx XC7A50T-FGG484 (Artix-7 50T) |
| **SDRAM**      | M12L64322A 8MB (512K x 32bit x 4 Banks) |
| **SPI Flash**  | MX25L128 16MB |
| **Ethernet PHY** | Broadcom B50612D x 2 (1Gbps) |
| **クロック**   | 25MHz (FPGA ピン K4 に接続) |
| **LED**        | D2 (FPGA ピン A18) |

---

## 接続インタフェース

### JTAG ピン配置

| FPGA ピン | JTAG 信号 |
|-----------|-----------|
| J5        | TCK       |
| J4        | TMS       |
| J3        | TDI       |
| J2        | TDO       |

### SPI Flash (U12)

| 信号 | FPGA ピン |
|------|-----------|
| CS   | T19       |
| MISO | R22       |
| MOSI | P22       |
| SCK  | L12       |

### Ethernet PHY0 (U5)

| 信号     | FPGA ピン |
|---------|-----------|
| MDC     | G1        |
| MDIO    | G2        |
| RESET   | H2        |
| GTXCLK  | A1        |
| TXD[0]  | B2        |
| TXD[1]  | B1        |
| TXD[2]  | C2        |
| TXD[3]  | D2        |
| TX_EN   | D1        |
| RXC     | H2/H4     |
| RXD[0]  | E3        |
| RXD[1]  | E2        |
| RXD[2]  | E1        |
| RXD[3]  | F3        |
| RX_DV   | F1        |

### Ethernet PHY1 (U9)

| 信号     | FPGA ピン |
|---------|-----------|
| MDC     | G1        |
| MDIO    | G2        |
| RESET   | H2        |
| GTXCLK  | M6        |
| TXD[0]  | M5        |
| TXD[1]  | M2        |
| TXD[2]  | N4        |
| TXD[3]  | P4        |
| TX_EN   | N5        |
| RXC     | L3/H2     |
| RXD[0]  | N2        |
| RXD[1]  | N3        |
| RXD[2]  | P1        |
| RXD[3]  | P2        |
| RX_DV   | R1        |

---

## ビットストリーム書き込み手順

書き込みには **CH347** (USB-JTAG アダプタ) と **openocd** を使います。

### ステップ 1: ツールチェーンのインストール

openXC7 が提供するスクリプトで一発インストール（Linux/WSL 推奨）:

```bash
wget -qO - https://raw.githubusercontent.com/kintex-chatter/toolchain-installer/main/toolchain-installer.sh | bash
```

インストールされるもの: **yosys** (合成) / **nextpnr-xilinx** (配置配線) / **fasm2frames + xc7frames2bit** (ビットストリーム生成)

### ステップ 2: デモプロジェクトのビルド

```bash
git clone https://github.com/wuxx/demo-projects
cd demo-projects/blinky-colorlight-i9plus
make
```

`make` 完了後に `blinky.bit` が生成されます。

### ステップ 3: openocd のビルド (CH347 パッチ適用)

WCH 社が CH347 用のパッチを提供しています。

```bash
git clone https://github.com/openocd-org/openocd.git
cd openocd
git checkout 3a4f445bd92101d3daee3715178d3fbff3b7b029
cp ~/Colorlight-FPGA-Projects/tools/openocd-patch-for-ch347/ch347.patch .
git apply --reject --whitespace=fix ch347.patch
./bootstrap
./configure --enable-ch347 --disable-werror
make -j
# make install は不推奨 (既存の openocd と競合する可能性あり)
```

### ステップ 4: 書き込みスクリプトの準備

`ch347prog` スクリプト内の `OPENOCD_ROOT` パスを実際の openocd のパスに書き換えます:

```bash
# Colorlight-FPGA-Projects/tools/ch347prog の先頭部分を編集
OPENOCD_ROOT=/path/to/your/openocd   # ← 実際のパスに変更
```

その後、スクリプトを PATH に追加:

```bash
cd ~/Colorlight-FPGA-Projects/tools
source env.sh
```

### ステップ 5: Flash のアンロック (初回のみ必須)

**初回使用時は Flash が書き込み禁止になっているため、必ずアンロックが必要です。**

```bash
ch347prog-sram unlock_flash_xc7a50t.bit
```

### ステップ 6: ビットストリームの書き込み

```bash
cd ~/demo-projects/blinky-colorlight-i9plus

# SRAM への書き込み (電源を切るとリセット)
ch347prog-sram blinky.bit

# SPI Flash への書き込み (永続保存)
ch347prog-flash blinky.bit
```

---

## プロジェクト内のファイル構成

```
Colorlight-FPGA-Projects/
├── colorlight_i9plus_v6.1.md   # i9plus 詳細仕様書
├── demo/
│   └── i9plus/                 # 書き込み済みデモビットストリーム
│       ├── blinky_10.bit           # LED 点滅 (10Hz)
│       ├── blinky_1000.bit         # LED 点滅 (1000Hz)
│       ├── bscan_spi_xc7a50t.bit   # Flash アクセス用
│       └── xc7a50t-pin-scan.bit    # ピンスキャン用
├── doc/                        # データシート・ピン配置画像
├── firmware/                   # 工場出荷時 Flash イメージ
│   ├── flash_image_20201029.bin
│   ├── flash_image_20210824.bin
│   └── flash_image_20220122.bin
├── schematic/
│   └── i9plus-extboard.pdf     # 拡張ボード回路図
└── tools/
    ├── ch347prog               # 書き込みスクリプト本体
    ├── ch347prog-sram          # SRAM 書き込み (ch347prog へのシンボリックリンク相当)
    ├── ch347prog-flash         # Flash 書き込み
    ├── ch347.cfg               # openocd 用 CH347 設定
    ├── bscan_spi_xc7a50t.bit   # Flash アクセス用ビットストリーム
    ├── unlock_flash_xc7a50t.bit# Flash アンロック用ビットストリーム
    ├── openocd-patch-for-ch347/# openocd CH347 パッチ
    └── env.sh                  # PATH 設定スクリプト
```

---

## デモビットストリームの即時試用

ツールチェーンをビルドしなくても、`demo/i9plus/` にあるビットストリームを使ってすぐに動作確認できます。

```bash
cd ~/Colorlight-FPGA-Projects/tools
source env.sh

# Flash アンロック (初回のみ)
ch347prog-sram unlock_flash_xc7a50t.bit

# LED 点滅デモを SRAM に書き込み
ch347prog-sram ~/Colorlight-FPGA-Projects/demo/i9plus/blinky_1000.bit
```

ボードの LED (D2, FPGA ピン A18) が点滅すれば成功です。

---

## 注意事項

- CH347 デバイスの VID/PID は `0x1a86:0x55dd` (ch347.cfg 参照)
- `ch347prog` スクリプトの `OPENOCD_ROOT` は必ず実際のパスに変更すること
- `make install` せずにビルドした場合、スクリプト内のパスが `src/openocd` を指すことを確認すること
- Flash への書き込みは SRAM より時間がかかる
- DDR2-SODIMM 200P コネクタ経由で GPIO を拡張ボードに引き出す構造 (ピン配置は `colorlight_i9plus_v6.1.md` 参照)

---

## 参考リンク

- [openXC7 プロジェクト](https://github.com/openXC7/demo-projects)
- [WCH CH347 (openocd パッチ元)](https://github.com/WCHSoftGroup/ch347)
- [Colorlight リバースエンジニアリング](https://github.com/chmousset/colorlight_reverse)
- [bscan_spi_bitstreams](https://github.com/quartiq/bscan_spi_bitstreams)
