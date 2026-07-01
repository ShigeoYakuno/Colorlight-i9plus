# Colorlight i9plus-v6.1 Setup

Colorlight i9plus-v6.1 (Xilinx Artix-7 XC7A50T) の開発環境セットアップと LED 点滅デモの記録。

## 環境

- **OS**: Windows 11 + WSL2 (Ubuntu 22.04)
- **ツール**: Vivado (ビットストリーム生成) + openocd CH347対応版 (書き込み)
- **JTAG**: CH347 (ボード内蔵, usbipd-win 経由で WSL から使用)

## 完了内容

- openocd に CH347 パッチを適用してビルド
- usbipd-win で CH347 を WSL に接続
- Flash アンロック (初回)
- Vivado でビットストリーム生成 → Flash 書き込み → 電源投入自動起動を確認

## ドキュメント

| ファイル | 内容 |
|---------|------|
| [docs/getting-started.md](docs/getting-started.md) | ボード概要・ピン配置 |
| [docs/windows-guide.md](docs/windows-guide.md) | Windows/WSL 環境構築の詳細手順 |
| [docs/process.md](docs/process.md) | 書き込みコマンド (毎回使う手順) |
| [docs/history.md](docs/history.md) | 実施したコマンドの全履歴 |
| [docs/blinky-i9plus.v](docs/blinky-i9plus.v) | Vivado 用 Verilog サンプル |
| [docs/blinky-i9plus.xdc](docs/blinky-i9plus.xdc) | Vivado 用 XDC 制約ファイル |

## Board

- **FPGA**: Xilinx XC7A50T-FGG484 (Artix-7)
- **Flash**: MX25L128 16MB
- **SDRAM**: M12L64322A 8MB
- **Ethernet**: Broadcom B50612D x2 (1Gbps)
