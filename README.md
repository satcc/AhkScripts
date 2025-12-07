# AhkScripts

Self-made Key Remapping & Utility Scripts using AutoHotkey v2.

## Overview
このプロジェクトは、Windows 環境でのキーボード操作を効率化するための AutoHotkey v2 スクリプトと、物理キーのリマップを行うレジストリ設定ファイルを含んでいます。

主な目的は、ホームポジションから手を離さずにカーソル移動やIME切り替え、マウス操作を行えるようにし、Vim ライクな操作感を実現することです。

## Features

### 1. Key Remapping (Registry Level)
Windows のレジストリ (`Scancode Map`) を使用して、あまり使わないキーを機能キーとして再割り当てしています。
*   **無変換 (Muhenkan)** -> **F13**
*   **変換 (Henkan)** -> **F14**
*   **CapsLock** -> **F15**

適用するには `RemapKeys.reg` を実行し、Windows を再起動してください。

### 2. AutoHotkey Script (`Basic.ah2`)

#### Mode Switching
リマップされたキーを修飾キー（Modifieir）として使用し、特殊なモードを発動します。

*   **Mouse Mode** (`F13` held down)
    *   `H/J/K/L`: カーソル移動 (←/↓/↑/→)
    *   `W/E/R`: マウス左/中/右クリック
    *   矢印キー: マウスカーソル移動（加速機能付き）
    *   `[/]`: マウスホイール Up/Down

*   **Symbol Mode** (`F14` held down)
    *   ホームポジション付近のキーで記号を入力
    *   `H`: `;` `:`
    *   `J`: `+` `=`
    *   `K`: `-` `_`
    *   `U`: `/` `\` など

#### IME Control
*   **Space**: IME 切り替え (Mac風)
    *   IME ON/OFF 時にカーソルそばにツールチップで状態を表示 (`あ` / `A`)
*   **F14 (Single Press)**: 
    *   Mac の「かな」キーのように、F14 単独押しで IME ON (または特定の機能) を割り当て可能

#### Other Shortcuts
*   **O**: Enter
*   **U**: Tab
*   **I / Shift+I**: Backspace / Delete
*   **D**: Backspace
*   **Z**: Escape
*   **F2/F3/F4**: 音量制御 (Mute / Down / Up)
*   **Wheel + Win**: ウィンドウの透明度変更

## Installation

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Apply Registry Map:
    *   Double click `RemapKeys.reg` and restart Windows.
3. Run Script:
    *   Double click `Basic.ah2`.

## License
MIT
