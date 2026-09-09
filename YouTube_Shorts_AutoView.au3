#RequireAdmin
; ============================================================================
; YouTube Shorts AutoView — Автоматический просмотр YouTube Shorts
; Версия: 2.0 (интеграция с YouPub API)
; Описание: Скрипт получает URL'ы опубликованных роликов с сервера YouPub,
;           открывает их в Chrome, имитирует поведение реального человека
;           и отправляет статус просмотра обратно.
; Горячая клавиша остановки: F10 или Ctrl+Alt+Q
; ============================================================================

#include <Array.au3>
#include <Date.au3>
#include <File.au3>
#include <String.au3>
#include <WinAPIFiles.au3>
#include <Misc.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>

Opt("GUIOnEventMode", 1)

; ============================================================================
; === НАСТРОЙКИ (ИЗМЕНЯЙТЕ ПОД СЕБЯ) ========================================
; ============================================================================

; --- Сервер API YouPub ---
Global Const $API_BASE_URL = "https://you.1tlt.ru"                  ; Базовый URL сервера YouPub
Global Const $API_GET_URLS = $API_BASE_URL & "/api/autoview/urls"    ; Эндпоинт получения URL'ов
Global Const $API_SEND_STATUS = $API_BASE_URL & "/api/autoview/status" ; Эндпоинт отправки статуса
Global Const $API_LIMIT = 5                                           ; Сколько URL запрашивать за раз

; --- Авторизация ---
; Токен создаётся в MySQL (таблица api_tokens), как раньше:
;   INSERT INTO api_tokens (token, description, is_active)
;   VALUES ('ваш-секрет', 'Бот Win10', 1);
; Хранить в файле token.txt рядом со скриптом (одна строка = токен)
Global $g_sApiToken = ""

; --- Chrome ---
Global Const $CHROME_PATH = "C:\Program Files\Google\Chrome\Application\chrome.exe"
Global Const $CHROME_PROFILE_DIR = @ScriptDir & "\ChromeProfiles" ; Папка для профилей Chrome
Global $g_iProfileCounter = 1                                     ; Счётчик профилей

; --- Worker ID (уникальный для каждого инстанса) ---
Global $g_sWorkerId = "bot_" & @ComputerName & "_" & StringRight(@AutoItPID, 4)

; --- Тайминги ---
Global Const $MIN_WATCH_TIME = 45      ; Минимальное время просмотра (секунды) — если сервер не задал
Global Const $MAX_WATCH_TIME = 130     ; Максимальное время просмотра (секунды) — если сервер не задал
Global Const $MIN_PAUSE = 3            ; Минимальная пауза между действиями (секунды)
Global Const $MAX_PAUSE = 12           ; Максимальная пауза между действиями (секунды)
Global Const $MIN_CHECK_INTERVAL = 30  ; Минимальный интервал проверки новых URL (секунды)
Global Const $MAX_CHECK_INTERVAL = 60  ; Максимальный интервал проверки новых URL (секунды)

; --- Лог ---
Global Const $LOG_FILE = @ScriptDir & "\log.txt"

; --- Состояние скрипта ---
Global $g_bRunning = True              ; Флаг работы скрипта

; --- Мини-панель статуса (правый верхний угол) ---
Global $g_hStatusGui = 0
Global $g_idStatusPhase = 0
Global $g_idStatusDetail = 0
Global $g_idStatusAccount = 0
Global $g_idStatusMeta = 0
Global $g_idStatusStats = 0
Global $g_idBtnStop = 0
Global $g_sStatusPhase = "Старт"
Global $g_hSessionStart = TimerInit()
Global $g_iSessionDone = 0
Global $g_iSessionError = 0
Global $g_iBatchIndex = 0
Global $g_iBatchTotal = 0
Global $g_iCurrentProfile = 0
Global $g_sCurrentAccount = "—"
Global $g_sTokenPrefix = ""
Global $g_sApiHost = ""


; ============================================================================
; === РЕГИСТРАЦИЯ ГОРЯЧИХ КЛАВИШ =============================================
; ============================================================================
HotKeySet("{F10}", "_ExitScript")
HotKeySet("^!q", "_ExitScript")       ; Ctrl+Alt+Q
OnAutoItExitRegister("_StatusPanelDestroy")

; ============================================================================
; === ИНИЦИАЛИЗАЦИЯ ==========================================================
; ============================================================================

; Создаём папку профилей Chrome, если нет
If Not FileExists($CHROME_PROFILE_DIR) Then
    DirCreate($CHROME_PROFILE_DIR)
EndIf

; Загружаем токен из файла, если не задан в настройках
If $g_sApiToken = "" Then
    Local $sTokenFile = @ScriptDir & "\token.txt"
    If FileExists($sTokenFile) Then
        $g_sApiToken = StringStripWS(FileRead($sTokenFile), 3)
        $g_sTokenPrefix = StringLeft($g_sApiToken, 8)
        _WriteLog("Токен загружен из token.txt (" & $g_sTokenPrefix & "...)")
    Else
        _WriteLog("ОШИБКА: Токен не задан! Создайте token.txt с API-токеном или укажите в настройках.")
        MsgBox(16, "Ошибка", "API-токен не найден!" & @CRLF & @CRLF & _
            "1. На сервере MySQL:" & @CRLF & _
            "   INSERT INTO api_tokens (token, description, is_active)" & @CRLF & _
            "   VALUES ('ваш-секрет', 'Бот Win10', 1);" & @CRLF & _
            "2. Создайте token.txt рядом со скриптом" & @CRLF & _
            "3. Впишите туда тот же токен одной строкой")
        Exit
    EndIf
EndIf

If $g_sTokenPrefix = "" And $g_sApiToken <> "" Then $g_sTokenPrefix = StringLeft($g_sApiToken, 8)
$g_sApiHost = StringReplace(StringReplace($API_BASE_URL, "https://", ""), "http://", "")
$g_hSessionStart = TimerInit()

_WriteLog("=== Скрипт запущен (v2.0 YouPub) ===")
_WriteLog("API сервер: " & $API_BASE_URL)
_WriteLog("Worker ID: " & $g_sWorkerId)
_WriteLog("Chrome: " & $CHROME_PATH)
_WriteLog("Горячие клавиши остановки: F10 или Ctrl+Alt+Q")

; Проверяем наличие Chrome
If Not FileExists($CHROME_PATH) Then
    _WriteLog("ОШИБКА: Chrome не найден по пути: " & $CHROME_PATH)
    MsgBox(16, "Ошибка", "Chrome не найден по пути:" & @CRLF & $CHROME_PATH & @CRLF & "Укажите корректный путь в настройках скрипта.")
    Exit
EndIf

_StatusPanelCreate()
_StatusSet("Запуск", $g_sApiHost)

; ============================================================================
; === ГЛАВНЫЙ ЦИКЛ ==========================================================
; ============================================================================

_MainLoop()
_StatusPanelDestroy()

; ============================================================================
; === ФУНКЦИЯ ГЛАВНОГО ЦИКЛА =================================================
; ============================================================================
Func _MainLoop()
    _WriteLog("Запуск главного цикла...")
    _StatusSet("Главный цикл", "ожидание задач")

    While $g_bRunning
        _StatusSet("Запрос URL", "сервер YouPub...")
        Local $aURLs = _GetNewURLs()

        If IsArray($aURLs) And UBound($aURLs) > 0 Then
            _WriteLog("Получено URL'ов: " & UBound($aURLs))
            $g_iBatchTotal = UBound($aURLs)
            $g_iBatchIndex = 0
            _StatusSet("Получено URL: " & $g_iBatchTotal, "старт обработки")

            For $i = 0 To UBound($aURLs) - 1
                If Not $g_bRunning Then ExitLoop

                If IsArray($aURLs[$i]) Then
                    Local $aItem = $aURLs[$i]
                    Local $sURLId = $aItem[0]
                    Local $sURL = $aItem[1]
                    Local $iServerWatchTime = Number($aItem[2])
                    $g_iBatchIndex = $i + 1

                    _WriteLog("Начинаю просмотр URL #" & $sURLId & ": " & $sURL)
                    _StatusSet("Просмотр #" & $sURLId, _ShortUrl($sURL))
                    Local $iWatchTime = _ViewURL($sURL, $sURLId, $iServerWatchTime)

                    If $iWatchTime > 0 Then
                        $g_iSessionDone += 1
                        _StatusSet("Отчёт done", "#" & $sURLId & " · " & $iWatchTime & "с")
                        _SendStatus($sURLId, "done", $iWatchTime)
                        _WriteLog("URL #" & $sURLId & " отработан. Время просмотра: " & $iWatchTime & " сек.")
                    Else
                        $g_iSessionError += 1
                        _StatusSet("Отчёт error", "#" & $sURLId)
                        _SendStatus($sURLId, "error", 0, "Chrome window not found or closed early")
                        _WriteLog("ОШИБКА: Не удалось просмотреть URL #" & $sURLId)
                    EndIf

                    If $g_bRunning And $i < UBound($aURLs) - 1 Then
                        Local $iPauseBetween = Random(5, 15, 1)
                        _WriteLog("Пауза между URL'ами: " & $iPauseBetween & " сек.")
                        _StatusSet("Пауза " & $iPauseBetween & "с", "между URL")
                        _SmartSleep($iPauseBetween * 1000)
                    EndIf
                EndIf
            Next
        Else
            _WriteLog("Нет новых URL'ов или ошибка получения. Ожидаю...")
            _StatusSet("Нет URL", "ожидание очереди")
        EndIf

        If $g_bRunning Then
            Local $iWaitInterval = Random($MIN_CHECK_INTERVAL, $MAX_CHECK_INTERVAL, 1)
            _WriteLog("Следующая проверка URL'ов через " & $iWaitInterval & " сек.")
            _StatusSet("Ожидание " & $iWaitInterval & "с", "следующий опрос API")
            _SmartSleep($iWaitInterval * 1000)
        EndIf
    WEnd

    _StatusSet("Остановлено", "")
    _WriteLog("=== Скрипт остановлен ===")
EndFunc

; ============================================================================
; === ФУНКЦИЯ ПОЛУЧЕНИЯ URL'ов С СЕРВЕРА =====================================
; ============================================================================
Func _GetNewURLs()
    _WriteLog("Запрашиваю URL'ы с сервера...")
    _StatusSet("API GET urls", "limit=" & $API_LIMIT)

    Local $sRequestURL = $API_GET_URLS & "?limit=" & $API_LIMIT & "&worker_id=" & $g_sWorkerId
    Local $sResponse = _HttpGet($sRequestURL)

    If $sResponse = "" Or @error Then
        _WriteLog("ОШИБКА: Не удалось получить ответ от сервера")
        Return SetError(1, 0, "")
    EndIf

    _WriteLog("Ответ сервера: " & StringLeft($sResponse, 300))

    ; Парсим JSON-ответ вручную
    ; Ожидаемый формат: [{"id":1,"url":"https://youtube.com/shorts/xxx","target_watch_time":30}, ...]
    Local $aResult = _ParseURLsFromJSON($sResponse)

    Return $aResult
EndFunc

; ============================================================================
; === ФУНКЦИЯ ПРОСМОТРА ОДНОГО URL ===========================================
; ============================================================================
Func _ViewURL($sURL, $sURLId, $iServerWatchTime = 0)
    ; Определяем время просмотра: берём от сервера или случайное
    Local $iTargetWatchTime
    If $iServerWatchTime > 0 Then
        ; Добавляем ±20% случайности к серверному времени
        Local $iJitter = Int($iServerWatchTime * 0.2)
        $iTargetWatchTime = $iServerWatchTime + Random(-$iJitter, $iJitter, 1)
        If $iTargetWatchTime < 10 Then $iTargetWatchTime = 10
        _WriteLog("Целевое время (от сервера ±20%): " & $iTargetWatchTime & " сек. (базовое: " & $iServerWatchTime & ")")
    Else
        $iTargetWatchTime = Random($MIN_WATCH_TIME, $MAX_WATCH_TIME, 1)
        _WriteLog("Целевое время (случайное): " & $iTargetWatchTime & " сек.")
    EndIf

    ; Выбираем профиль Chrome (чередуем для разного отпечатка)
    Local $iProfileNum = $g_iProfileCounter
    Local $sProfilePath = $CHROME_PROFILE_DIR & "\profile" & $iProfileNum
    $g_iCurrentProfile = $iProfileNum
    $g_sCurrentAccount = _AccountLabel($iProfileNum)
    $g_iProfileCounter += 1
    If $g_iProfileCounter > 5 Then $g_iProfileCounter = 1

    If Not FileExists($sProfilePath) Then
        DirCreate($sProfilePath)
    EndIf

    ; На всякий случай закрываем старые окна нашего профиля (чтобы не плодились)
    _KillChromeByProfile($sProfilePath)

    Local $aOldWindows = _ChromeWindowSnapshot()

    ; Полный экран + отдельный профиль
    Local $sChromeArgs = '--new-window --start-fullscreen '
    $sChromeArgs &= '--user-data-dir="' & $sProfilePath & '" '
    $sChromeArgs &= '--disable-extensions --no-first-run --disable-default-apps '
    $sChromeArgs &= '--disable-popup-blocking --disable-translate '
    $sChromeArgs &= '--disable-session-crashed-bubble --disable-infobars '
    $sChromeArgs &= '"' & $sURL & '"'

    _WriteLog("Запуск Chrome fullscreen, профиль: profile" & $iProfileNum & " (" & $g_sCurrentAccount & ")")
    _StatusSet("Chrome #" & $sURLId, $g_sCurrentAccount & " · fullscreen · " & $iTargetWatchTime & "с")

    Local $iPID = Run('"' & $CHROME_PATH & '" ' & $sChromeArgs)

    If $iPID = 0 Or @error Then
        _WriteLog("ОШИБКА: Не удалось запустить Chrome! Код ошибки: " & @error)
        Return 0
    EndIf

    _WriteLog("Chrome запущен, PID: " & $iPID)

    Local $hWnd = _WaitForNewChromeWindow($aOldWindows, 20)

    If $hWnd = 0 Then
        _WriteLog("ПРЕДУПРЕЖДЕНИЕ: Новое окно Chrome не найдено, повтор...")
        _SmartSleep(2000)
        $hWnd = _WaitForNewChromeWindow($aOldWindows, 10)
    EndIf

    If $hWnd <> 0 Then
        WinActivate($hWnd)
        WinWaitActive($hWnd, "", 5)
        WinSetState($hWnd, "", @SW_MAXIMIZE)
        _SmartSleep(400)
        ; Дожимаем fullscreen, если Chrome не ушёл в F11 сам
        Local $aPosCheck = WinGetPos($hWnd)
        If IsArray($aPosCheck) And ($aPosCheck[2] < @DesktopWidth - 20 Or $aPosCheck[3] < @DesktopHeight - 40) Then
            Send("{F11}")
            _SmartSleep(400)
        EndIf

        ; Координаты для имитации — весь экран
        Local $iWinX = 0
        Local $iWinY = 0
        Local $iWinW = @DesktopWidth
        Local $iWinH = @DesktopHeight
        Local $aPos = WinGetPos($hWnd)
        If IsArray($aPos) Then
            $iWinX = $aPos[0]
            $iWinY = $aPos[1]
            $iWinW = $aPos[2]
            $iWinH = $aPos[3]
        EndIf

        _WriteLog("Окно Chrome fullscreen: " & $iWinX & "," & $iWinY & " " & $iWinW & "x" & $iWinH)

        Local $iLoadWait = Random(5, 8, 1)
        _WriteLog("Ожидание загрузки страницы: " & $iLoadWait & " сек.")
        _StatusSet("Загрузка страницы", $iLoadWait & "с · #" & $sURLId)
        _SmartSleep($iLoadWait * 1000)

        ; Клик по центру — кнопка Play на YouTube (в fullscreen она по центру)
        If $g_bRunning And WinExists($hWnd) Then
            _ClickCenterPlay($hWnd, $iWinX, $iWinY, $iWinW, $iWinH)
        EndIf

        Local $hTimer = TimerInit()
        Local $iElapsed = 0
        Local $iActionCount = 0
        Local $iLastStatusSec = -1

        While $iElapsed < ($iTargetWatchTime * 1000) And $g_bRunning
            If Not WinExists($hWnd) Then
                _WriteLog("ПРЕДУПРЕЖДЕНИЕ: Окно Chrome закрыто раньше времени")
                ExitLoop
            EndIf

            Local $iLeftSec = Int(($iTargetWatchTime * 1000 - $iElapsed) / 1000)
            If $iLeftSec < 0 Then $iLeftSec = 0
            If $iLeftSec <> $iLastStatusSec Then
                _StatusSet("Смотрю #" & $sURLId, "~" & $iLeftSec & "с · " & $g_sCurrentAccount)
                $iLastStatusSec = $iLeftSec
            EndIf

            If Not WinActive($hWnd) Then
                WinActivate($hWnd)
                Sleep(300)
            EndIf

            Local $iAction = Random(1, 100, 1)

            If $iAction <= 35 Then
                Local $iMaxX = $iWinW - 100
                If $iMaxX < 200 Then $iMaxX = 200
                Local $iMaxY = $iWinH - 100
                If $iMaxY < 250 Then $iMaxY = 250
                Local $iTargetX = $iWinX + Random(100, $iMaxX, 1)
                Local $iTargetY = $iWinY + Random(150, $iMaxY, 1)
                _HumanMouseMove($iTargetX, $iTargetY, Random(6, 12, 1))

            ElseIf $iAction <= 55 Then
                Local $iScrollDir = Random(0, 1, 1)
                Local $iScrollAmount = Random(1, 5, 1)
                If $iScrollDir = 0 Then
                    _HumanScroll("down", $iScrollAmount)
                Else
                    _HumanScroll("up", $iScrollAmount)
                EndIf

            ElseIf $iAction <= 70 Then
                Local $iMaxCX = $iWinW - 200
                If $iMaxCX < 300 Then $iMaxCX = 300
                Local $iMaxCY = $iWinH - 200
                If $iMaxCY < 350 Then $iMaxCY = 350
                Local $iClickX = $iWinX + Random(200, $iMaxCX, 1)
                Local $iClickY = $iWinY + Random(250, $iMaxCY, 1)
                _HumanMouseMove($iClickX, $iClickY, Random(5, 10, 1))
                Sleep(Random(200, 600, 1))
                MouseClick("left", $iClickX, $iClickY, 1, Random(5, 15, 1))

            ElseIf $iAction <= 85 Then
                ; пауза — смотрит
            Else
                _HumanMouseJitter(3, 8)
            EndIf

            $iActionCount += 1
            Local $iPause = Random($MIN_PAUSE * 1000, $MAX_PAUSE * 1000, 1)
            _SmartSleep($iPause)
            $iElapsed = TimerDiff($hTimer)
        WEnd

        _WriteLog("Выполнено действий: " & $iActionCount)
    Else
        _WriteLog("ОШИБКА: Не удалось найти окно Chrome. Ожидаю целевое время...")
        _SmartSleep($iTargetWatchTime * 1000)
    EndIf

    ; Закрываем ИМЕННО это окно + процессы профиля
    _CloseChromeWindow($hWnd, $iPID, $sProfilePath)

    Local $iActualWatchTime = Int($iTargetWatchTime)
    Return $iActualWatchTime
EndFunc

; ============================================================================
; === ФУНКЦИЯ ОТПРАВКИ СТАТУСА НА СЕРВЕР =====================================
; ============================================================================
Func _SendStatus($sURLId, $sStatus = "done", $iWatchSeconds = 0, $sError = "")
    _WriteLog("Отправка статуса '" & $sStatus & "' для URL #" & $sURLId & " (время: " & $iWatchSeconds & " сек.)")

    Local $sPostData = "url_id=" & $sURLId & "&status=" & $sStatus & "&watch_time=" & $iWatchSeconds & "&worker_id=" & $g_sWorkerId
    If $sError <> "" Then
        $sPostData &= "&error=" & $sError
    EndIf

    Local $sResponse = _HttpPost($API_SEND_STATUS, $sPostData)

    If $sResponse = "" Or @error Then
        _WriteLog("ОШИБКА: Не удалось отправить статус на сервер!")
        Return SetError(1, 0, False)
    EndIf

    _WriteLog("Ответ сервера на статус: " & StringLeft($sResponse, 200))
    Return True
EndFunc

; ============================================================================
; === ФУНКЦИЯ ПЛАВНОГО ЧЕЛОВЕЧЕСКОГО ДВИЖЕНИЯ МЫШИ ===========================
; Используется кривая Безье через несколько промежуточных точек
; ============================================================================
Func _HumanMouseMove($iTargetX, $iTargetY, $iSpeed = 8)
    Local $aMousePos = MouseGetPos()
    Local $iStartX = $aMousePos[0]
    Local $iStartY = $aMousePos[1]

    ; Вычисляем расстояние
    Local $iDist = Sqrt(($iTargetX - $iStartX) ^ 2 + ($iTargetY - $iStartY) ^ 2)

    ; Определяем количество шагов на основе расстояния
    Local $iSteps = Int($iDist / $iSpeed)
    If $iSteps < 10 Then $iSteps = 10
    If $iSteps > 100 Then $iSteps = 100

    ; Генерируем 2 контрольные точки для кривой Безье
    ; Добавляем случайное отклонение для естественности
    Local $iDeviation = Random(30, 100, 1)

    Local $iCtrl1X = $iStartX + ($iTargetX - $iStartX) * 0.3 + Random(-$iDeviation, $iDeviation, 1)
    Local $iCtrl1Y = $iStartY + ($iTargetY - $iStartY) * 0.3 + Random(-$iDeviation, $iDeviation, 1)
    Local $iCtrl2X = $iStartX + ($iTargetX - $iStartX) * 0.7 + Random(-$iDeviation, $iDeviation, 1)
    Local $iCtrl2Y = $iStartY + ($iTargetY - $iStartY) * 0.7 + Random(-$iDeviation, $iDeviation, 1)

    ; Двигаем мышь по кубической кривой Безье
    For $i = 1 To $iSteps
        Local $t = $i / $iSteps

        ; Кубическая кривая Безье: B(t) = (1-t)^3*P0 + 3*(1-t)^2*t*P1 + 3*(1-t)*t^2*P2 + t^3*P3
        Local $iX = (1 - $t) ^ 3 * $iStartX + _
                     3 * (1 - $t) ^ 2 * $t * $iCtrl1X + _
                     3 * (1 - $t) * $t ^ 2 * $iCtrl2X + _
                     $t ^ 3 * $iTargetX

        Local $iY = (1 - $t) ^ 3 * $iStartY + _
                     3 * (1 - $t) ^ 2 * $t * $iCtrl1Y + _
                     3 * (1 - $t) * $t ^ 2 * $iCtrl2Y + _
                     $t ^ 3 * $iTargetY

        MouseMove(Int($iX), Int($iY), 0)

        ; Случайная микро-задержка между шагами (имитация скорости человека)
        ; Медленнее в начале и конце, быстрее в середине
        Local $iDelay = 5
        If $t < 0.2 Or $t > 0.8 Then
            $iDelay = Random(8, 15, 1)
        Else
            $iDelay = Random(3, 8, 1)
        EndIf

        Sleep($iDelay)
    Next

    ; Финальная корректировка позиции
    MouseMove($iTargetX, $iTargetY, 0)
EndFunc

; ============================================================================
; === ФУНКЦИЯ ДРОЖАНИЯ МЫШИ (МИКРО-ДВИЖЕНИЯ) =================================
; ============================================================================
Func _HumanMouseJitter($iMinPixels = 2, $iMaxPixels = 6)
    Local $aPos = MouseGetPos()
    Local $iJitterCount = Random(3, 8, 1)

    For $i = 1 To $iJitterCount
        Local $iDx = Random(-$iMaxPixels, $iMaxPixels, 1)
        Local $iDy = Random(-$iMaxPixels, $iMaxPixels, 1)

        MouseMove($aPos[0] + $iDx, $aPos[1] + $iDy, Random(2, 5, 1))
        Sleep(Random(50, 200, 1))
    Next

    ; Возвращаемся примерно в исходную точку
    MouseMove($aPos[0] + Random(-2, 2, 1), $aPos[1] + Random(-2, 2, 1), Random(3, 6, 1))
EndFunc

; ============================================================================
; === ФУНКЦИЯ ЧЕЛОВЕЧЕСКОГО СКРОЛЛИНГА =======================================
; ============================================================================
Func _HumanScroll($sDirection = "down", $iAmount = 3)
    For $i = 1 To $iAmount
        If $sDirection = "down" Then
            MouseWheel($MOUSE_WHEEL_DOWN, Random(1, 3, 1))
        Else
            MouseWheel($MOUSE_WHEEL_UP, Random(1, 3, 1))
        EndIf

        ; Случайная пауза между прокрутками
        Sleep(Random(100, 400, 1))
    Next
EndFunc

; ============================================================================
; === HTTP GET ЗАПРОС ЧЕРЕЗ WinHTTP (с Bearer-токеном) =======================
; ============================================================================
Func _HttpGet($sURL)
    Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")

    If Not IsObj($oHTTP) Then
        _WriteLog("ОШИБКА: Не удалось создать WinHTTP объект")
        Return SetError(1, 0, "")
    EndIf

    ; Устанавливаем таймауты (resolve, connect, send, receive) в миллисекундах
    $oHTTP.SetTimeouts(5000, 10000, 10000, 15000)

    ; Открываем GET запрос
    $oHTTP.Open("GET", $sURL, False)

    ; Устанавливаем заголовки
    $oHTTP.SetRequestHeader("User-Agent", "YouPub-AutoView/2.0 (" & $g_sWorkerId & ")")
    $oHTTP.SetRequestHeader("Accept", "application/json")
    $oHTTP.SetRequestHeader("Accept-Language", "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7")

    ; Авторизация по Bearer-токену
    If $g_sApiToken <> "" Then
        $oHTTP.SetRequestHeader("Authorization", "Bearer " & $g_sApiToken)
    EndIf

    ; Отправляем запрос
    Local $bSuccess = Execute('$oHTTP.Send()')

    If @error Then
        _WriteLog("ОШИБКА HTTP GET: Не удалось отправить запрос к " & $sURL)
        Return SetError(2, 0, "")
    EndIf

    ; Проверяем статус ответа
    Local $iStatus = $oHTTP.Status

    If $iStatus = 401 Then
        _WriteLog("ОШИБКА: Неверный или просроченный API-токен (401 Unauthorized)")
        Return SetError(3, $iStatus, "")
    EndIf

    If $iStatus <> 200 Then
        _WriteLog("ОШИБКА HTTP GET: Статус " & $iStatus & " от " & $sURL)
        Return SetError(3, $iStatus, "")
    EndIf

    Local $sResponse = $oHTTP.ResponseText
    Return $sResponse
EndFunc

; ============================================================================
; === HTTP POST ЗАПРОС ЧЕРЕЗ WinHTTP (с Bearer-токеном) ======================
; ============================================================================
Func _HttpPost($sURL, $sPostData)
    Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")

    If Not IsObj($oHTTP) Then
        _WriteLog("ОШИБКА: Не удалось создать WinHTTP объект")
        Return SetError(1, 0, "")
    EndIf

    ; Устанавливаем таймауты
    $oHTTP.SetTimeouts(5000, 10000, 10000, 15000)

    ; Открываем POST запрос
    $oHTTP.Open("POST", $sURL, False)

    ; Устанавливаем заголовки
    $oHTTP.SetRequestHeader("User-Agent", "YouPub-AutoView/2.0 (" & $g_sWorkerId & ")")
    $oHTTP.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
    $oHTTP.SetRequestHeader("Accept", "application/json")

    ; Авторизация по Bearer-токену
    If $g_sApiToken <> "" Then
        $oHTTP.SetRequestHeader("Authorization", "Bearer " & $g_sApiToken)
    EndIf

    ; Отправляем запрос с данными
    Local $bSuccess = Execute('$oHTTP.Send("' & $sPostData & '")')

    If @error Then
        _WriteLog("ОШИБКА HTTP POST: Не удалось отправить запрос к " & $sURL)
        Return SetError(2, 0, "")
    EndIf

    ; Проверяем статус ответа
    Local $iStatus = $oHTTP.Status

    If $iStatus = 401 Then
        _WriteLog("ОШИБКА: Неверный или просроченный API-токен (401 Unauthorized)")
        Return SetError(3, $iStatus, "")
    EndIf

    If $iStatus <> 200 Then
        _WriteLog("ОШИБКА HTTP POST: Статус " & $iStatus & " от " & $sURL)
        Return SetError(3, $iStatus, "")
    EndIf

    Local $sResponse = $oHTTP.ResponseText
    Return $sResponse
EndFunc

; ============================================================================
; === ПАРСИНГ JSON ОТВЕТА С URL'ами ==========================================
; Формат: [{"id":1,"url":"https://...","target_watch_time":30}, ...]
; ============================================================================
Func _ParseURLsFromJSON($sJSON)
    ; Убираем внешние скобки массива
    $sJSON = StringStripWS($sJSON, 3)

    If StringLeft($sJSON, 1) <> "[" Or StringRight($sJSON, 1) <> "]" Then
        _WriteLog("ОШИБКА парсинга: JSON не является массивом")
        Return SetError(1, 0, "")
    EndIf

    ; Убираем [ и ]
    $sJSON = StringMid($sJSON, 2, StringLen($sJSON) - 2)

    ; Пустой массив
    If StringStripWS($sJSON, 3) = "" Then
        _WriteLog("Сервер вернул пустой массив — нет URL'ов")
        Local $aEmpty[0]
        Return $aEmpty
    EndIf

    ; Разбиваем на объекты по },{ (упрощённый парсинг)
    Local $sDelimiter = "|||SPLIT|||"
    Local $sClean = StringReplace($sJSON, "},{", "}" & $sDelimiter & "{")
    Local $aObjects = StringSplit($sClean, $sDelimiter, 1)

    If $aObjects[0] = 0 Then
        _WriteLog("ОШИБКА парсинга: Нет объектов в JSON")
        Return SetError(2, 0, "")
    EndIf

    ; Создаём массив результатов
    Local $aResult[$aObjects[0]]

    For $i = 1 To $aObjects[0]
        Local $sObj = $aObjects[$i]

        ; Извлекаем поля
        Local $sId = _ExtractJSONValue($sObj, "id")
        Local $sUrl = _ExtractJSONValue($sObj, "url")
        Local $sWatchTime = _ExtractJSONValue($sObj, "target_watch_time")

        If $sId <> "" And $sUrl <> "" Then
            Local $aItem[3] = [$sId, $sUrl, $sWatchTime]
            $aResult[$i - 1] = $aItem
        Else
            _WriteLog("ПРЕДУПРЕЖДЕНИЕ: Не удалось распарсить объект: " & StringLeft($sObj, 100))
            ; Создаём пустой элемент
            Local $aEmpty[3] = ["", "", "0"]
            $aResult[$i - 1] = $aEmpty
        EndIf
    Next

    Return $aResult
EndFunc

; ============================================================================
; === ИЗВЛЕЧЕНИЕ ЗНАЧЕНИЯ ИЗ JSON ПО КЛЮЧУ ==================================
; ============================================================================
Func _ExtractJSONValue($sJSON, $sKey)
    ; Ищем "key":"value" или "key": "value"
    Local $aRegExp = StringRegExp($sJSON, '"' & $sKey & '"\s*:\s*"([^"]*)"', 3)

    If IsArray($aRegExp) And UBound($aRegExp) > 0 Then
        Return $aRegExp[0]
    EndIf

    ; Пробуем числовое значение: "key": 123
    $aRegExp = StringRegExp($sJSON, '"' & $sKey & '"\s*:\s*(\d+)', 3)

    If IsArray($aRegExp) And UBound($aRegExp) > 0 Then
        Return $aRegExp[0]
    EndIf

    Return ""
EndFunc

; ============================================================================
; === КЛИК ПО ЦЕНТРУ (PLAY) =================================================
; ============================================================================
Func _ClickCenterPlay($hWnd, $iWinX, $iWinY, $iWinW, $iWinH)
    _StatusSet("Play", "клик по центру")
    _WriteLog("Клик по центру экрана для запуска воспроизведения")

    WinActivate($hWnd)
    WinWaitActive($hWnd, "", 3)

    Local $iCX = $iWinX + Int($iWinW / 2)
    Local $iCY = $iWinY + Int($iWinH / 2)
    ; Чуть выше геометрического центра — кнопка Play обычно там
    $iCY = $iCY - Int($iWinH * 0.02)

    _HumanMouseMove($iCX, $iCY, Random(5, 9, 1))
    Sleep(Random(200, 450, 1))
    MouseClick("left", $iCX, $iCY, 1, Random(4, 10, 1))
    Sleep(Random(400, 800, 1))

    ; Иногда первый клик только убирает оверлей — второй по центру
    If Random(0, 1, 1) = 1 Then
        MouseClick("left", $iCX + Random(-8, 8, 1), $iCY + Random(-8, 8, 1), 1, Random(4, 8, 1))
        Sleep(Random(300, 600, 1))
    EndIf

    ; Space как запасной старт playback
    Send("{SPACE}")
    Sleep(Random(250, 500, 1))
EndFunc

; ============================================================================
; === ОКНА CHROME: СНИМОК / ОЖИДАНИЕ / ЗАКРЫТИЕ ==============================
; ============================================================================
Func _ChromeWindowSnapshot()
    Local $aList = WinList("[CLASS:Chrome_WidgetWin_1]")
    Local $sOut = "|"
    If IsArray($aList) Then
        For $i = 1 To $aList[0][0]
            If $aList[$i][1] <> 0 Then $sOut &= String($aList[$i][1]) & "|"
        Next
    EndIf
    Return $sOut
EndFunc

Func _WaitForNewChromeWindow($sOldSnapshot, $iTimeout = 15)
    Local $hTimer = TimerInit()
    While TimerDiff($hTimer) < ($iTimeout * 1000)
        Local $aList = WinList("[CLASS:Chrome_WidgetWin_1]")
        If IsArray($aList) Then
            For $i = 1 To $aList[0][0]
                Local $hWnd = $aList[$i][1]
                If $hWnd = 0 Then ContinueLoop
                If Not WinExists($hWnd) Then ContinueLoop
                If StringInStr($sOldSnapshot, "|" & String($hWnd) & "|") = 0 Then
                    ; Берём видимое окно с заголовком
                    If BitAND(WinGetState($hWnd), 2) Then ; exists+visible roughly
                        Return $hWnd
                    EndIf
                    Return $hWnd
                EndIf
            Next
        EndIf
        Sleep(300)
    WEnd
    Return 0
EndFunc

Func _KillChromeByProfile($sProfilePath)
    If $sProfilePath = "" Then Return
    _WriteLog("Очистка Chrome-процессов профиля: " & $sProfilePath)
    Local $sPsFile = @TempDir & "\autoview_kill_chrome.ps1"
    Local $sPs = "param([string]$ProfilePath)" & @CRLF & _
            "Get-CimInstance Win32_Process -Filter ""Name='chrome.exe'"" |" & @CRLF & _
            "  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($ProfilePath) } |" & @CRLF & _
            "  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
    Local $h = FileOpen($sPsFile, 2 + 8) ; write + create UTF8 without BOM maybe just 2
    If $h <> -1 Then
        FileWrite($h, $sPs)
        FileClose($h)
        RunWait('powershell -NoProfile -ExecutionPolicy Bypass -File "' & $sPsFile & '" -ProfilePath "' & $sProfilePath & '"', "", @SW_HIDE)
    EndIf
    Sleep(400)
EndFunc

Func _CloseChromeWindow($hWnd, $iPID, $sProfilePath = "")
    _WriteLog("Закрытие Chrome-окна просмотра...")
    _StatusSet("Закрытие Chrome", "одно окно")

    If $hWnd <> 0 And WinExists($hWnd) Then
        WinActivate($hWnd)
        Sleep(200)
        ; Выйти из F11, чтобы корректно закрыть
        Send("{F11}")
        Sleep(250)
        WinClose($hWnd)
        Local $iWait = 0
        While WinExists($hWnd) And $iWait < 8
            Sleep(250)
            $iWait += 1
        WEnd
        If WinExists($hWnd) Then
            WinKill($hWnd)
            Sleep(300)
        EndIf
    EndIf

    ; Гарантированно убиваем процессы именно этого user-data-dir
    If $sProfilePath <> "" Then
        _KillChromeByProfile($sProfilePath)
    ElseIf $iPID > 0 And ProcessExists($iPID) Then
        RunWait(@ComSpec & " /c taskkill /F /PID " & $iPID & " /T", "", @SW_HIDE)
        ProcessWaitClose($iPID, 5)
    EndIf

    Sleep(800)
    _WriteLog("Chrome окно закрыто")
EndFunc

; ============================================================================
; === УМНЫЙ SLEEP С ПРОВЕРКОЙ ФЛАГА ОСТАНОВКИ ================================
; ============================================================================
Func _SmartSleep($iMilliseconds)
    Local $hTimer = TimerInit()

    While TimerDiff($hTimer) < $iMilliseconds And $g_bRunning
        Sleep(100)
    WEnd
EndFunc

; ============================================================================
; === ЗАПИСЬ В ЛОГ-ФАЙЛ =====================================================
; ============================================================================
Func _WriteLog($sMessage)
    Local $sTimestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $sLogLine = "[" & $sTimestamp & "] " & $sMessage

    ; Выводим в консоль (для отладки)
    ConsoleWrite($sLogLine & @CRLF)

    ; Записываем в файл
    Local $hFile = FileOpen($LOG_FILE, $FO_APPEND + $FO_UTF8)
    If $hFile <> -1 Then
        FileWriteLine($hFile, $sLogLine)
        FileClose($hFile)
    EndIf
EndFunc

; ============================================================================
; === МИНИ-ПАНЕЛЬ СТАТУСА (ПРАВЫЙ ВЕРХНИЙ УГОЛ) ==============================
; ============================================================================
Func _StatusPanelCreate()
    If $g_hStatusGui <> 0 Then Return

    Local $iW = 310
    Local $iH = 188
    Local $iX = @DesktopWidth - $iW - 14
    Local $iY = 14

    $g_hStatusGui = GUICreate("AutoView", $iW, $iH, $iX, $iY, _
            BitOR($WS_POPUP, $WS_BORDER), _
            BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))

    GUISetBkColor(0x1B222C)
    GUICtrlCreateLabel("AutoView", 10, 8, 160, 18)
    GUICtrlSetFont(-1, 9, 700)
    GUICtrlSetColor(-1, 0x8EC5FF)

    $g_idStatusPhase = GUICtrlCreateLabel("Старт...", 10, 28, 290, 18, $SS_LEFTNOWORDWRAP)
    GUICtrlSetFont(-1, 10, 600)
    GUICtrlSetColor(-1, 0xF0F4F8)
    GUICtrlSetBkColor(-1, 0x1B222C)

    $g_idStatusDetail = GUICtrlCreateLabel("—", 10, 48, 290, 16, $SS_LEFTNOWORDWRAP)
    GUICtrlSetFont(-1, 8, 400)
    GUICtrlSetColor(-1, 0xC5D0DE)
    GUICtrlSetBkColor(-1, 0x1B222C)

    $g_idStatusAccount = GUICtrlCreateLabel("Акк: —", 10, 68, 290, 16, $SS_LEFTNOWORDWRAP)
    GUICtrlSetFont(-1, 8, 600)
    GUICtrlSetColor(-1, 0x7DDEB5)
    GUICtrlSetBkColor(-1, 0x1B222C)

    $g_idStatusMeta = GUICtrlCreateLabel("Worker / token / API", 10, 86, 290, 16, $SS_LEFTNOWORDWRAP)
    GUICtrlSetFont(-1, 7, 400)
    GUICtrlSetColor(-1, 0x9AA8B8)
    GUICtrlSetBkColor(-1, 0x1B222C)

    $g_idStatusStats = GUICtrlCreateLabel("Сессия: —", 10, 104, 290, 16, $SS_LEFTNOWORDWRAP)
    GUICtrlSetFont(-1, 8, 400)
    GUICtrlSetColor(-1, 0xB8C4D4)
    GUICtrlSetBkColor(-1, 0x1B222C)

    $g_idBtnStop = GUICtrlCreateButton("Стоп", 10, 130, 290, 42)
    GUICtrlSetBkColor(-1, 0xB33A3A)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 10, 700)
    GUICtrlSetOnEvent($g_idBtnStop, "_ExitScript")

    GUISetOnEvent($GUI_EVENT_CLOSE, "_ExitScript")
    GUISetState(@SW_SHOW, $g_hStatusGui)
    WinSetTrans($g_hStatusGui, "", 235)
    _StatusRefreshMeta()
EndFunc

Func _StatusSet($sPhase, $sDetail = "")
    If $g_hStatusGui = 0 Then Return
    $g_sStatusPhase = $sPhase
    If $g_idStatusPhase <> 0 Then GUICtrlSetData($g_idStatusPhase, $sPhase)
    If $g_idStatusDetail <> 0 Then GUICtrlSetData($g_idStatusDetail, $sDetail)
    _StatusRefreshMeta()
EndFunc

Func _StatusRefreshMeta()
    If $g_hStatusGui = 0 Then Return

    Local $sAcc = "Акк: " & $g_sCurrentAccount
    If $g_iCurrentProfile > 0 Then $sAcc &= "  ·  profile" & $g_iCurrentProfile
    If $g_idStatusAccount <> 0 Then GUICtrlSetData($g_idStatusAccount, $sAcc)

    Local $sMeta = $g_sWorkerId & "  ·  tok " & $g_sTokenPrefix & "…  ·  " & $g_sApiHost
    If $g_idStatusMeta <> 0 Then GUICtrlSetData($g_idStatusMeta, $sMeta)

    Local $iUptimeMin = Int(TimerDiff($g_hSessionStart) / 60000)
    Local $sBatch = ""
    If $g_iBatchTotal > 0 Then
        $sBatch = "  ·  пачка " & $g_iBatchIndex & "/" & $g_iBatchTotal
    EndIf
    Local $sStats = "Сессия: OK " & $g_iSessionDone & " / ERR " & $g_iSessionError & $sBatch & "  ·  " & $iUptimeMin & " мин"
    If $g_idStatusStats <> 0 Then GUICtrlSetData($g_idStatusStats, $sStats)
EndFunc

Func _AccountLabel($iProfileNum)
    ; Опционально: accounts.ini рядом со скриптом
    ; [labels]
    ; 1=Основной
    ; 2=Резерв
    Local $sIni = @ScriptDir & "\accounts.ini"
    If FileExists($sIni) Then
        Local $sName = IniRead($sIni, "labels", String($iProfileNum), "")
        If $sName <> "" Then Return $sName
    EndIf
    Return "Chrome profile" & $iProfileNum
EndFunc

Func _ShortUrl($sURL)
    Local $s = StringStripWS($sURL, 3)
    If StringLen($s) <= 46 Then Return $s
    Return StringLeft($s, 43) & "..."
EndFunc

Func _StatusPanelDestroy()
    If $g_hStatusGui <> 0 Then
        GUIDelete($g_hStatusGui)
        $g_hStatusGui = 0
        $g_idStatusPhase = 0
        $g_idStatusDetail = 0
        $g_idStatusAccount = 0
        $g_idStatusMeta = 0
        $g_idStatusStats = 0
        $g_idBtnStop = 0
    EndIf
EndFunc

; ============================================================================
; === ОБРАБОТЧИК ГОРЯЧЕЙ КЛАВИШИ / КНОПКИ СТОП ===============================
; ============================================================================
Func _ExitScript()
    $g_bRunning = False
    _StatusSet("Остановка...", "закрытие Chrome")
    _WriteLog(">>> Получен сигнал остановки от пользователя <<<")

    ; Закрываем все окна/процессы наших профилей AutoView
    For $i = 1 To 5
        _KillChromeByProfile($CHROME_PROFILE_DIR & "\profile" & $i)
    Next

    _WriteLog("=== Скрипт завершён пользователем ===")
    _StatusPanelDestroy()
    Exit
EndFunc
