#SingleInstance Force
#UseHook true
#Requires AutoHotkey v2.0

vk1D & Esc:: Reload()
F13 & Esc:: Reload()

; # Win, ! Alt, ^ Ctrl, + Shift

SetTransparent(x) {
    WID := WinGetID("A")
    t := WinGetTransparent(WID)
    if (t == "") {
        t := 255
    }
    t := t + x
    if (120 <= t && t <= 255) {
        WinSetTransparent(t, WID)
    }
}
#WheelDown:: SetTransparent(-20)
#WheelUp:: SetTransparent(20)

; Shift + BS -> Del
+BS:: Send("{Del}")
^+BS:: Send("^{Del}")

;SC029は半角全角キーのスキャンコード。「1」キーの左のキーが半角全角キーである想定。1回押下はIME切り替えで、2連打はEscの機能とする。チルダ(~)があるのでSend("{SC029}")の記述は不要。
~SC029::
{
    if (A_PriorHotkey == A_ThisHotkey && A_TimeSincePriorHotkey < 400) {
        Send("{Esc}")
    }
}

; ホットストリング
#Hotstring EndChars -()[]{}:;'"/\,.?!`n`s`t
; ~day 現在の日付と時刻に置き換え
::~day::
{
    Send FormatTime(, "yyyy/MM/dd(ddd) hh:mm:ss")
}

;-----------------------------------------------------------------
#HotIf GetKeyState("vk1D", "P") || GetKeyState("F13", "P") ; 無変換キーが押されている間だけ有効

; 矢印キーでマウス移動
global mouseIsDclick := false
global mouseMoveCounter := 0
global mouseStopCounter := 0
global lastPress := Map()   ; 各キーの前回押下時刻を記録するマップ
global ID_MOUSE := 10
global ID_HELP := 11
global ID_IME := 12

; キャレット位置を取得してToolTipを表示
ShowToolTip(tipText, id, showTimeSec) {
    ; キャレット位置を取得
    try {
        CaretGetPos(&x, &y)
        ; キャレットの少し下に表示
        tipX := x
        tipY := y + 20
    } catch {
        ; キャレット位置が取得できない場合はマウス位置を使用
        MouseGetPos(&tipX, &tipY)
        tipY += 20
    }

    ; ToolTipを表示
    ToolTip(tipText, tipX, tipY, id)
    ; showTimeMSec後に消す
    SetTimer(() => ToolTip("", , , id), -showTimeSec * 1000)
}

; IMEの状態を取得する関数（改善版）
GetIMEState() {
    ; 現在のDetectHiddenWindows設定を保存し、Trueにする（IMEウィンドウ操作に必要）
    dhw := A_DetectHiddenWindows
    DetectHiddenWindows(true)

    ; アクティブウィンドウのハンドルを取得
    hwnd := WinGetID("A")
    if (!hwnd) {
        DetectHiddenWindows(dhw)
        return 0
    }

    ; 本当にフォーカスを持っているウィンドウ（コントロール）を取得する
    ; これを行わないと、メモ帳(Win11)などで正しいIME状態が取れない場合がある
    cbSize := 24 + 6 * A_PtrSize
    gti := Buffer(cbSize, 0)
    NumPut("UInt", cbSize, gti, 0)

    ; GetGUIThreadInfo(0, &gti)
    if DllCall("GetGUIThreadInfo", "UInt", 0, "Ptr", gti.Ptr) {
        hwndFocus := NumGet(gti, 8 + A_PtrSize, "Ptr") ; hwndFocusオフセット
        if (hwndFocus) {
            hwnd := hwndFocus
        }
    }

    ; デフォルトIMEウィンドウを取得
    DefaultIMEWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")

    ; IMEウィンドウが取得できない場合は、元の設定に戻して0を返す
    if (!DefaultIMEWnd) {
        OutputDebug("GetIMEState: DefaultIMEWnd is null")
        DetectHiddenWindows(dhw)
        return 0
    }

    ; IME状態を取得（try-catchでエラーハンドリング）
    try {
        ; WM_IME_CONTROL (0x283), IMC_GETOPENSTATUS (0x005)
        result := SendMessage(0x283, 0x005, 0, , DefaultIMEWnd)
        OutputDebug("GetIMEState: hwnd=" . hwnd . " DefaultIMEWnd=" . DefaultIMEWnd . " result=" . result)
        DetectHiddenWindows(dhw)
        return result
    } catch as err {
        ; エラーが発生した場合
        OutputDebug("GetIMEState Error: " . err.Message)
        DetectHiddenWindows(dhw)
        return 0
    }
}

; 前回のIME状態を保持（トグル判定用）
global lastIMEState := 0

; キャレット位置を取得してToolTipを表示（切り替え前の状態を受け取る）
ShowIMEToolTip(imeState) {
    global ID_IME

    ; IMEがON（日本語モード）なら「あ」、OFF（英語モード）なら「A」
    tipText := imeState ? "あ" : "A"

    ; 共通関数を使ってToolTipを表示 (1秒)
    ShowToolTip(tipText, ID_IME, 1)
}

SetIMEState(state) {
    ; 現在のDetectHiddenWindows設定を保存し、Trueにする
    dhw := A_DetectHiddenWindows
    DetectHiddenWindows(true)

    hwnd := WinGetID("A")
    if (!hwnd) {
        DetectHiddenWindows(dhw)
        return
    }

    ; 本当にフォーカスを持っているウィンドウ（コントロール）を取得
    cbSize := 24 + 6 * A_PtrSize
    gti := Buffer(cbSize, 0)
    NumPut("UInt", cbSize, gti, 0)

    if DllCall("GetGUIThreadInfo", "UInt", 0, "Ptr", gti.Ptr) {
        hwndFocus := NumGet(gti, 8 + A_PtrSize, "Ptr")
        if (hwndFocus) {
            hwnd := hwndFocus
        }
    }

    DefaultIMEWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if (!DefaultIMEWnd) {
        DetectHiddenWindows(dhw)
        return
    }

    try {
        SendMessage(0x283, 0x006, state, , DefaultIMEWnd)
    }

    DetectHiddenWindows(dhw)
    ShowIMEToolTip(state)
}

*F1:: {
    helpText := "
    (LTrim
    W/E/R         :   左/中/右クリック
    H/J/K/L       :   ←/↓/↑/→
    N/M/,/.       :   Home/PageDown/PageUp/End
    U             :   Tab
    O             :   Enter
    I,Shift+I     :   BS/Del
    Z             :   Esc
    Space         :   IME切り替え
    F2/F3/F4      :   音量ミュート/ダウン/アップ
    )"
    ToolTip(helpText, , , ID_HELP)
    SetTimer () => ToolTip("", , , ID_HELP), -5000 ; 5秒後に消す
}

;vi風キー割り当て　(alt+Tabの操作と競合しないようにScanCodeで記述)
*sc023:: SendInput("{Blind}{Left}")   ; 無変換+h → 左
*sc024:: SendInput("{Blind}{Down}")   ; 無変換+j → 下
*sc025:: SendInput("{Blind}{Up}")     ; 無変換+k → 上
*sc026:: SendInput("{Blind}{Right}")  ; 無変換+l → 右

;Home/End/PageUp/PageDownキーを割り当て
*n:: SendInput("{Blind}{Home}")
*m:: SendInput("{Blind}{PgDn}")
*,:: SendInput("{Blind}{PgUp}")
*.:: SendInput("{Blind}{End}")
*a:: SendInput("{Blind}{Home}")
*s:: SendInput("{Blind}{End}")

; U → Tab
*u:: SendInput("{Blind}{Tab}")

; I/Shift+I → Backspace/Del
i:: SendInput("{Backspace}")
^i:: SendInput("^{Backspace}")
+i:: SendInput("{Del}")
^+i:: SendInput("^{Del}")

; D/Shift+D → Backspace/Del
d:: SendInput("{Backspace}")
^d:: SendInput("^{Backspace}")
+d:: SendInput("{Del}")
^+d:: SendInput("^{Del}")

; O → Enter
*o:: SendInput("{Blind}{Enter}")

; Space -> IME切り替え
Space:: {
    ; 切り替え前のIME状態を取得
    beforeState := GetIMEState()
    ; IMEを切り替え
    SendInput("{vkF3}")
    ; ToolTipを表示
    ShowIMEToolTip(!beforeState)
}

; Z-> Escape
z:: SendInput("{Esc}")

; F2,F3,F4 → 音量ミュート,ダウン,アップ切り替え
F2:: SoundSetMute -1  ; ミュート切り替え
F3:: SoundSetVolume "-5"  ; 現在の音量から -5%
F4:: SoundSetVolume "+5"  ; 現在の音量から +5%

;アプリキーを割り当て
q::AppsKey

;-------------------------------------------------
; マウス操作系
MoveMouseStop() {
    global mouseIsDclick, mouseMoveCounter, mouseStopCounter
    mouseStopCounter := 0
    mouseIsDclick := false
    mouseMoveCounter := 0
    SetTimer MoveMouse, 0
    ToolTip("", , , ID_MOUSE)
}

MoveMouse() {
    global mouseIsDclick, mouseMoveCounter, mouseStopCounter

    step := 15
    if (mouseIsDclick) {
        step := 15 * 2
    } else if (mouseMoveCounter < 10) {
        step := 5
    } else if (mouseMoveCounter < 20) {
        step := 10
    }

    ; 矢印キーの状態を確認
    is_press := false
    move_x := 0
    move_y := 0
    if (GetKeyState("Up", "P")) {
        move_y := move_y - step
        is_press := true
    }
    if (GetKeyState("Down", "P")) {
        move_y := move_y + step
        is_press := true
    }
    if (GetKeyState("Left", "P")) {
        move_x := move_x - step
        is_press := true
    }
    if (GetKeyState("Right", "P")) {
        move_x := move_x + step
        is_press := true
    }
    if (!is_press) {
        mouseStopCounter++
        if (mouseStopCounter > 10) {
            MoveMouseStop()
        }
        OutputDebug "Counter:" mouseMoveCounter " StopCounter: " mouseStopCounter " step:" step
        return
    }
    mouseStopCounter := 0
    if (move_x = 0 && move_y = 0) {
        OutputDebug "Counter:" mouseMoveCounter " StopCounter: " mouseStopCounter " step:" step
        return
    }

    mouseMoveCounter++
    MouseMove move_x, move_y, 0, "R"
    ToolTip("" step, , , ID_MOUSE)
    OutputDebug "Counter:" mouseMoveCounter " StopCounter: " mouseStopCounter " MoveMouse: " move_x "," move_y " step:" step
}

MouseKeyDown(key := "") {
    global lastPress, mouseIsDclick
    OutputDebug "key: " key

    now := A_TickCount
    if (lastPress.Has(key) && now - lastPress[key] < 150) {
        mouseIsDclick := true
    }

    interval := 30
    SetTimer MoveMouse, interval
}

MouseKeyUp(key := "") {
    lastPress[key] := A_TickCount
}

*Up:: MouseKeyDown("Up")
*Up Up:: MouseKeyUp("Up")
*Down:: MouseKeyDown("Down")
*Down Up:: MouseKeyUp("Down")
*Left:: MouseKeyDown("Left")
*Left Up:: MouseKeyUp("Left")
*Right:: MouseKeyDown("Right")
*Right Up:: MouseKeyUp("Right")

MouseClickDown(key := "", button := "Left") {
    global lastPress
    if (lastPress.Has(key)) {
        return
    }
    lastPress[key] := A_TickCount
    Click button " Down"
}
MouseClickUp(key := "", button := "Left") {
    global lastPress
    lastPress.Delete(key)
    Click button " Up"
}

; W/E/R → 左/中/右クリック
*w:: MouseClickDown("w", "Left")
*w Up:: MouseClickUp("w", "Left")
*e:: MouseClickDown("e", "Middle")
*e Up:: MouseClickUp("e", "Middle")
*r:: MouseClickDown("r", "Right")
*r Up:: MouseClickUp("r", "Right")

; [/] → ホイールアップ/ダウン
*[:: Send "{Blind}{WheelUp}"
*]:: Send "{Blind}{WheelDown}"

; マウス操作系
;-------------------------------------------------

#HotIf ; GetKeyState("vk1D", "P")  ; 無変換キーが押されている間だけ有効

; Alt+Tabの画面でも hjklでカーソル移動
#HotIf WinActive("ahk_class XamlExplorerHostIslandWindow")
*sc023:: Send "{Blind}{Left}"   ; h
*sc024:: Send "{Blind}{Down}"   ; j
*sc025:: Send "{Blind}{Up}"     ; k
*sc026:: Send "{Blind}{Right}"  ; l
#HotIf

;-----------------------------------------------------------------
; 変換キー(vk1C) + キー で記号入力
;-----------------------------------------------------------------
#HotIf GetKeyState("vk1C", "P") || GetKeyState("F14", "P")

*F1:: {
    helpText := "
    (LTrim
    H             :   ; , :
    J             :   + , =
    K             :   - , _
    U             :   / , \
    I             :   * , |
    O             :   ? , ~
    N             :   { , [
    M             :   } , ]
    D             :   BS , Del
    Space         :   Enter
    )"
    ToolTip(helpText, , , ID_HELP)
    SetTimer () => ToolTip("", , , ID_HELP), -5000 ; 5秒後に消す
}

; Space -> Enter
*Space:: SendInput("{Blind}{Enter}")

; D/Shift+D -> Backspace/Del
*d:: SendInput("{Backspace}")
^d:: SendInput("^{Backspace}")
+d:: SendInput("{Del}")
^+d:: SendInput("^{Del}")

; H/Shift+H -> ;/:
*sc023:: {
    if GetKeyState("Shift", "P")
        SendInput("{Blind}{Text}:")
    else
        SendInput("{Blind}{;}")
}

; J/Shift+J -> +/=
*sc024:: {
    if GetKeyState("Shift", "P")
        SendInput("{Blind}{=}")
    else
        SendInput("{Blind}{+}")
}

; K/Shift+K -> -/_
*sc025:: {
    if GetKeyState("Shift", "P")
        SendInput("{Blind}{_}")
    else
        SendInput("{Blind}{-}")
}

; U/Shift+U -> /,\
*u:: {
    if GetKeyState("Shift", "P")
        SendInput("{Blind}{Text}\")
    else
        SendInput("{Blind}{/}")
}

; I/Shift+I -> */|
*i:: {
    if GetKeyState("Shift", "P")
        SendInput("{Blind}{|}")
    else
        SendInput("{Blind}{*}")
}

; O/Shift+O -> ?/~
*o:: {
    if GetKeyState("Shift", "P")
        SendInput("{Blind}{~}")
    else
        SendInput("{Blind}{?}")
}

; n/Shift+n -> [/{
*n:: {
    if GetKeyState("Shift", "P")
        SendInput("{Blind}{Text}[")
    else
        SendInput("{Blind}{Text}{")
}

; m/Shift+m -> ]/}
*m:: {
    if GetKeyState("Shift", "P")
        SendInput("{Blind}{Text}]")
    else
        SendInput("{Blind}{Text}}")
}

#HotIf

; =================================================================
; 設定値 (Configuration)
; =================================================================
DOUBLE_CLICK_TIME := 450

;-----------------------------------------------------------------
; キーハンドラー共通関数
;-----------------------------------------------------------------
HandleKeyDoubleClick(keyName, clickAction) {
    KeyWait keyName

    ; 共通の安全策（マウス移動停止）
    if keyName = "vk1D" || keyName = "F13" {
        lastPress.Clear()
        MoveMouseStop()
    }

    if (A_PriorHotkey == A_ThisHotkey && A_TimeSincePriorHotkey < DOUBLE_CLICK_TIME) {
        clickAction()
    }
}

;-----------------------------------------------------------------
; 無変換キー(vk1D/F13)の制御
; 単独押下は無効、ダブルクリックでIMEをOFF
; キーUpでマウス移動停止（安全策）
;-----------------------------------------------------------------
vk1D:: HandleKeyDoubleClick("vk1D", () => (SetIMEState(0)))
F13:: HandleKeyDoubleClick("F13", () => (SetIMEState(0)))

;-----------------------------------------------------------------
; 変換キー(vk1C/F14)の制御
; 単独押下は無効、ダブルクリックでIMEをON
;-----------------------------------------------------------------
vk1C:: HandleKeyDoubleClick("vk1C", () => (SetIMEState(1)))
F14:: HandleKeyDoubleClick("F14", () => (SetIMEState(1)))