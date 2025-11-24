#SingleInstance Force
#UseHook true
#Requires AutoHotkey v2.0

vk1D & Esc:: Reload()

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
#Hotstring EndChars -()[]{}:;'"/\,.?!`n`s`t EndChars -()[]{}:;'"/\,.?!`n`s`t
; ~day 現在の日付と時刻に置き換え
::~day::
{
    Send FormatTime(, "yyyy/MM/dd(ddd) hh:mm:ss")
}

;-----------------------------------------------------------------
#HotIf GetKeyState("vk1D", "P")  ; 無変換キーが押されている間だけ有効

; 矢印キーでマウス移動
global mouseIsDclick := false
global mouseMoveCounter := 0
global mouseStopCounter := 0
global lastPress := Map()   ; 各キーの前回押下時刻を記録するマップ
global ID_HELP := 10

*F1:: {
    helpText := "
    (LTrim
    W/E/R    : 左/中/右クリック
    H/J/K/L  : ←/↓/↑/→
    N/M/,/.  : Home/End/PageUp/PageDown
    F2/F3/F4 : 音量ダウン/アップ/ミュート
    )"
    ToolTip helpText, , ,
        ID_HELP
    SetTimer () => ToolTip("", , , ID_HELP), -5000 ; 5秒後に消す
}

;vi風キー割り当て　(alt+Tabの操作と競合しないようにScanCodeで記述)
*sc023:: SendInput "{Blind}{Left}"   ; 無変換+h → 左
*sc024:: SendInput "{Blind}{Down}"   ; 無変換+j → 下
*sc025:: SendInput "{Blind}{Up}"     ; 無変換+k → 上
*sc026:: SendInput "{Blind}{Right}"  ; 無変換+l → 右

;Home/End/PageUp/PageDownキーを割り当て
*n:: SendInput("{Blind}{Home}")
*m:: SendInput("{Blind}{End}")
*,:: SendInput("{Blind}{PgUp}")
*.:: SendInput("{Blind}{PgDn}")
*a:: SendInput("{Blind}{Home}")
*s:: SendInput("{Blind}{End}")

;アプリキーを割り当て
q::AppsKey

MoveMouseStop() {
    global mouseIsDclick, mouseMoveCounter, mouseStopCounter
    mouseStopCounter := 0
    mouseIsDclick := false
    mouseMoveCounter := 0
    SetTimer MoveMouse, 0
    ToolTip "", , , 10
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
    ToolTip "" step, , , 10
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
    lastPress[key] := true
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

; F2,F3,F4 → 音量下,上、ミュート切り替え
F2:: SoundSetVolume "-5"  ; 現在の音量から -5%
F3:: SoundSetVolume "+5"  ; 現在の音量から +5%
F4:: SoundSetMute -1  ; ミュート切り替え

#HotIf ; GetKeyState("vk1D", "P")  ; 無変換キーが押されている間だけ有効

; 無変換キーを離したら強制停止（安全策）Upが取れないことが多い
*vk1D Up:: {
    lastPress.Clear()
    MoveMouseStop()
    OutputDebug "vk1D Up"
}

; Alt+Tabの画面でも hjklでカーソル移動
#HotIf WinActive("ahk_class XamlExplorerHostIslandWindow")
*sc023:: Send "{Blind}{Left}"   ; h
*sc024:: Send "{Blind}{Down}"   ; j
*sc025:: Send "{Blind}{Up}"     ; k
*sc026:: Send "{Blind}{Right}"  ; l
#HotIf