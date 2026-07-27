#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
#Include %A_ScriptDir%\WebView2\WebView2.ahk

; ============================================================
;  영남고 통합앱 (AutoHotkey v2 + WebView2)
;  · 서명된 정품 AutoHotkey로 구동 → 백신 오탐 위험 낮음
;  · 포털(ynhs)을 전체 창으로 로드. 포털은 github.io에서 실시간이라 항상 최신.
;  · 링크(target=_blank·window.open) → 앱 안이 아니라 기본 브라우저로 연다.
;  · 트레이 상주: 닫기(X)는 종료 대신 트레이로 숨김, 트레이/메뉴로 다시 열기·종료.
;  · 중복 실행 방지: 이미 떠 있으면 두 번째 실행은 경고 없이 기존 창만 띄우고 종료.
; ============================================================

APP_URL := "https://kyunghwanp.github.io/ynhs/"
main := 0
wvc := 0

; 두 번째 인스턴스 → 기존 창 띄우기 신호(시스템 전역 고유 메시지)
MSG_SHOW := DllCall("RegisterWindowMessage", "str", "YNHS_APP_SHOW_v1", "uint")

; ── 중복 실행 방지(이름 있는 뮤텍스) ──
hMutex := DllCall("CreateMutexW", "ptr", 0, "int", 0, "str", "Local\YnhsAppSingleton_v1", "ptr")
if (A_LastError = 183) {                        ; ERROR_ALREADY_EXISTS
    PostMessage(MSG_SHOW, 0, 0, , "ahk_id 0xFFFF")   ; HWND_BROADCAST → 기존 인스턴스가 창을 띄움
    ExitApp
}

; ── WebView2Loader.dll 경로 ──
DLL := ""
for p in [A_ScriptDir "\WebView2Loader.dll", A_ScriptDir "\WebView2\WebView2Loader.dll"]
    if FileExist(p) {
        DLL := p
        break
    }
if (DLL = "") {
    MsgBox("WebView2Loader.dll을 찾지 못했습니다.`n압축을 폴더째 풀고 '영남고.exe'를 실행하세요.", "영남고", 0x30)
    ExitApp
}

; ── 메인 창 ──
main := Gui("+Resize", "영남고등학교")
main.BackColor := "FFFFFF"
main.OnEvent("Size", OnSize)
main.OnEvent("Close", (*) => main.Hide())        ; X → 종료 대신 트레이로 숨김
main.Show("w1040 h1010")
SetWindowIcon()

; ── 트레이 ──
try TraySetIcon(A_ScriptDir "\icon.ico")
A_IconTip := "영남고등학교"
A_TrayMenu.Delete()
A_TrayMenu.Add("열기", (*) => ShowApp())
A_TrayMenu.Add("종료", (*) => ExitApp())
A_TrayMenu.Default := "열기"

; 두 번째 실행 신호 수신 → 창 띄우기
OnMessage(MSG_SHOW, (*) => ShowApp())

; 바탕화면 바로가기(영남고 로고) — 없으면 생성
EnsureDesktopShortcut()

; ── WebView2 로드 ──
SESSION := A_AppData "\YnhsApp\Session"
try DirCreate(SESSION)
try {
    env := WebView2.CreateEnvironmentAsync(0, SESSION, "", DLL).await()
    wvc := env.CreateCoreWebView2ControllerAsync(main.Hwnd).await()
    wvc.CoreWebView2.Navigate(APP_URL)
    try wvc.CoreWebView2.add_NewWindowRequested(OnNewWindow)   ; 새 창 → 기본 브라우저
    SetBounds()
} catch as e {
    MsgBox("포털을 여는 데 실패했습니다.`n인터넷 연결을 확인한 뒤 다시 실행해 주세요.`n`n(" e.Message ")", "영남고", 0x30)
}

; ── 함수 ──
ShowApp(*) {
    global main
    if !main
        return
    main.Show()
    try WinActivate("ahk_id " main.Hwnd)
}

OnSize(gui, minmax, w, h) {
    if (minmax = -1)          ; 최소화 상태면 리사이즈 무시
        return
    SetBounds()
}

SetBounds() {
    global wvc, main
    if !wvc
        return
    rc := Buffer(16)
    DllCall("GetClientRect", "ptr", main.Hwnd, "ptr", rc)
    r := Buffer(16)
    NumPut("int", 0, r, 0), NumPut("int", 0, r, 4)
    NumPut("int", NumGet(rc, 8, "int"), r, 8), NumPut("int", NumGet(rc, 12, "int"), r, 12)
    wvc.Bounds := r
}

OnNewWindow(sender, args) {
    ; 앱 안 새 창은 막고 URL을 기본 브라우저로 연다
    try {
        args.Handled := true
        u := args.Uri
        if (u != "")
            Run(u)
    }
}

; 바탕화면에 '영남고' 바로가기 생성(로고 아이콘). 이미 있으면 건너뜀.
EnsureDesktopShortcut() {
    lnk := A_Desktop "\영남고.lnk"
    if FileExist(lnk)
        return
    exe := A_ScriptDir "\영남고.exe"
    if !FileExist(exe)          ; 개발 중(다른 이름) 등엔 만들지 않음
        return
    try FileCreateShortcut(exe, lnk, A_ScriptDir, "", "영남고 포털", A_ScriptDir "\icon.ico")
}

SetWindowIcon() {
    global main
    ico := A_ScriptDir "\icon.ico"
    if !FileExist(ico)
        return
    ; IMAGE_ICON=1, LR_LOADFROMFILE=0x10
    hs := DllCall("LoadImage", "ptr", 0, "str", ico, "uint", 1, "int", 16, "int", 16, "uint", 0x10, "ptr")
    hl := DllCall("LoadImage", "ptr", 0, "str", ico, "uint", 1, "int", 32, "int", 32, "uint", 0x10, "ptr")
    if hs
        SendMessage(0x0080, 0, hs, , "ahk_id " main.Hwnd)   ; WM_SETICON small
    if hl
        SendMessage(0x0080, 1, hl, , "ahk_id " main.Hwnd)   ; WM_SETICON big
}
