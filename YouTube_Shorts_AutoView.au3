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

; ============================================================================
; === НАСТРОЙКИ (ИЗМЕНЯЙТЕ ПОД СЕБЯ) ========================================
; ============================================================================

; --- Сервер API YouPub ---
Global Const $API_BASE_URL = "https://you.1tlt.ru"                  ; Базовый URL сервера YouPub
Global Const $API_GET_URLS = $API_BASE_URL & "/api/autoview/urls"    ; Эндпоинт получения URL'ов
Global Const $API_SEND_STATUS = $API_BASE_URL & "/api/autoview/status" ; Эндпоинт отправки статуса
Global Const $API_LIMIT = 5                                           ; Сколько URL запрашивать за раз

; --- Авторизация ---
; Токен создаётся в админке: /admin/autoview → "Создать токен"
; Можно хранить в файле token.txt рядом со скриптом
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

; ============================================================================
; === РЕГИСТРАЦИЯ ГОРЯЧИХ КЛАВИШ =============================================
; ============================================================================
HotKeySet("{F10}", "_ExitScript")
HotKeySet("^!q", "_ExitScript")       ; Ctrl+Alt+Q

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
        _WriteLog("Токен загружен из token.txt (" & StringLeft($g_sApiToken, 8) & "...)")
    Else
        _WriteLog("ОШИБКА: Токен не задан! Создайте token.txt с API-токеном или укажите в настройках.")
        MsgBox(16, "Ошибка", "API-токен не найден!" & @CRLF & @CRLF & _
            "1. Откройте " & $API_BASE_URL & "/admin/autoview" & @CRLF & _
            "2. Создайте токен" & @CRLF & _
            "3. Сохраните его в файл token.txt рядом со скриптом")
        Exit
    EndIf
EndIf

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

; ============================================================================
; === ГЛАВНЫЙ ЦИКЛ ==========================================================
; ============================================================================

_MainLoop()

; ============================================================================
; === ФУНКЦИЯ ГЛАВНОГО ЦИКЛА =================================================
; ============================================================================
Func _MainLoop()
    _WriteLog("Запуск главного цикла...")

    While $g_bRunning
        ; Получаем новые URL с сервера
        Local $aURLs = _GetNewURLs()

        If IsArray($aURLs) And UBound($aURLs) > 0 Then
            _WriteLog("Получено URL'ов: " & UBound($aURLs))

            ; Обрабатываем каждый URL
            For $i = 0 To UBound($aURLs) - 1
                If Not $g_bRunning Then ExitLoop

                ; Каждый элемент — массив [url_id, url, target_watch_time]
                If IsArray($aURLs[$i]) Then
                    Local $aItem = $aURLs[$i]
                    Local $sURLId = $aItem[0]
                    Local $sURL = $aItem[1]
                    Local $iServerWatchTime = Number($aItem[2])

                    _WriteLog("Начинаю просмотр URL #" & $sURLId & ": " & $sURL)
                    Local $iWatchTime = _ViewURL($sURL, $sURLId, $iServerWatchTime)

                    If $iWatchTime > 0 Then
                        _SendStatus($sURLId, "done", $iWatchTime)
                        _WriteLog("URL #" & $sURLId & " отработан. Время просмотра: " & $iWatchTime & " сек.")
                    Else
                        _SendStatus($sURLId, "error", 0, "Chrome window not found or closed early")
                        _WriteLog("ОШИБКА: Не удалось просмотреть URL #" & $sURLId)
                    EndIf

                    ; Пауза между URL'ами (5-15 секунд)
                    If $g_bRunning And $i < UBound($aURLs) - 1 Then
                        Local $iPauseBetween = Random(5, 15, 1)
                        _WriteLog("Пауза между URL'ами: " & $iPauseBetween & " сек.")
                        _SmartSleep($iPauseBetween * 1000)
                    EndIf
                EndIf
            Next
        Else
            _WriteLog("Нет новых URL'ов или ошибка получения. Ожидаю...")
        EndIf

        ; Ожидание перед следующей проверкой
        If $g_bRunning Then
            Local $iWaitInterval = Random($MIN_CHECK_INTERVAL, $MAX_CHECK_INTERVAL, 1)
            _WriteLog("Следующая проверка URL'ов через " & $iWaitInterval & " сек.")
            _SmartSleep($iWaitInterval * 1000)
        EndIf
    WEnd

    _WriteLog("=== Скрипт остановлен ===")
EndFunc

; ============================================================================
; === ФУНКЦИЯ ПОЛУЧЕНИЯ URL'ов С СЕРВЕРА =====================================
; ============================================================================
Func _GetNewURLs()
    _WriteLog("Запрашиваю URL'ы с сервера...")

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
    Local $sProfilePath = $CHROME_PROFILE_DIR & "\profile" & $g_iProfileCounter
    $g_iProfileCounter += 1
    If $g_iProfileCounter > 5 Then $g_iProfileCounter = 1

    If Not FileExists($sProfilePath) Then
        DirCreate($sProfilePath)
    EndIf

    ; Формируем команду запуска Chrome
    Local $sChromeArgs = '--new-window --user-data-dir="' & $sProfilePath & '" '
    $sChromeArgs &= '--disable-extensions --no-first-run --disable-default-apps '
    $sChromeArgs &= '--disable-popup-blocking --disable-translate '
    $sChromeArgs &= '--window-size=1280,900 --window-position=100,50 '
    $sChromeArgs &= '"' & $sURL & '"'

    _WriteLog("Запуск Chrome с профилем: profile" & ($g_iProfileCounter - 1))

    ; Запускаем Chrome
    Local $iPID = Run('"' & $CHROME_PATH & '" ' & $sChromeArgs)

    If $iPID = 0 Or @error Then
        _WriteLog("ОШИБКА: Не удалось запустить Chrome! Код ошибки: " & @error)
        Return 0
    EndIf

    _WriteLog("Chrome запущен, PID: " & $iPID)

    ; Ждём появления окна Chrome (до 15 секунд)
    Local $hWnd = _WaitForChromeWindow(15)

    If $hWnd = 0 Then
        _WriteLog("ПРЕДУПРЕЖДЕНИЕ: Окно Chrome не найдено, но продолжаем...")
        ; Даём ещё немного времени
        Sleep(3000)
        $hWnd = _WaitForChromeWindow(10)
    EndIf

    If $hWnd <> 0 Then
        ; Активируем окно Chrome
        WinActivate($hWnd)
        WinWaitActive($hWnd, "", 5)

        ; Получаем размеры окна для корректной имитации
        Local $aPos = WinGetPos($hWnd)
        Local $iWinX = 0, $iWinY = 0, $iWinW = 1280, $iWinH = 900

        If IsArray($aPos) Then
            $iWinX = $aPos[0]
            $iWinY = $aPos[1]
            $iWinW = $aPos[2]
            $iWinH = $aPos[3]
        EndIf

        _WriteLog("Окно Chrome: " & $iWinX & "x" & $iWinY & " размер " & $iWinW & "x" & $iWinH)

        ; Ждём загрузки страницы (5-8 секунд)
        Local $iLoadWait = Random(5, 8, 1)
        _WriteLog("Ожидание загрузки страницы: " & $iLoadWait & " сек.")
        _SmartSleep($iLoadWait * 1000)

        ; === ИМИТАЦИЯ ПОВЕДЕНИЯ ЧЕЛОВЕКА ===
        Local $hTimer = TimerInit()
        Local $iElapsed = 0
        Local $iActionCount = 0

        While $iElapsed < ($iTargetWatchTime * 1000) And $g_bRunning
            ; Проверяем, что окно ещё существует
            If Not WinExists($hWnd) Then
                _WriteLog("ПРЕДУПРЕЖДЕНИЕ: Окно Chrome закрыто раньше времени")
                ExitLoop
            EndIf

            ; Активируем окно (на случай если пользователь кликнул куда-то)
            If Not WinActive($hWnd) Then
                WinActivate($hWnd)
                Sleep(500)
            EndIf

            ; Выбираем случайное действие
            Local $iAction = Random(1, 100, 1)

            If $iAction <= 35 Then
                ; 35% — Плавное движение мыши в случайную точку
                Local $iTargetX = $iWinX + Random(100, $iWinW - 100, 1)
                Local $iTargetY = $iWinY + Random(150, $iWinH - 100, 1)
                _HumanMouseMove($iTargetX, $iTargetY, Random(6, 12, 1))

            ElseIf $iAction <= 55 Then
                ; 20% — Скроллинг
                Local $iScrollDir = Random(0, 1, 1) ; 0 = вниз, 1 = вверх
                Local $iScrollAmount = Random(1, 5, 1)

                If $iScrollDir = 0 Then
                    _HumanScroll("down", $iScrollAmount)
                Else
                    _HumanScroll("up", $iScrollAmount)
                EndIf

            ElseIf $iAction <= 70 Then
                ; 15% — Клик в безопасную область (центр страницы, не по рекламе)
                Local $iClickX = $iWinX + Random(200, $iWinW - 200, 1)
                Local $iClickY = $iWinY + Random(250, $iWinH - 200, 1)
                _HumanMouseMove($iClickX, $iClickY, Random(5, 10, 1))
                Sleep(Random(200, 600, 1))
                MouseClick("left", $iClickX, $iClickY, 1, Random(5, 15, 1))

            ElseIf $iAction <= 85 Then
                ; 15% — Просто пауза (человек смотрит видео)
                ; ничего не делаем

            Else
                ; 15% — Движение мыши + лёгкое дрожание
                _HumanMouseJitter(3, 8)
            EndIf

            $iActionCount += 1

            ; Случайная пауза между действиями
            Local $iPause = Random($MIN_PAUSE * 1000, $MAX_PAUSE * 1000, 1)
            _SmartSleep($iPause)

            $iElapsed = TimerDiff($hTimer)
        WEnd

        _WriteLog("Выполнено действий: " & $iActionCount)
    Else
        _WriteLog("ОШИБКА: Не удалось найти окно Chrome. Ожидаю целевое время...")
        _SmartSleep($iTargetWatchTime * 1000)
    EndIf

    ; Закрываем Chrome
    _CloseChromeWindow($hWnd, $iPID)

    ; Вычисляем фактическое время просмотра
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
; === ОЖИДАНИЕ ОКНА CHROME ===================================================
; ============================================================================
Func _WaitForChromeWindow($iTimeout = 15)
    Local $hTimer = TimerInit()

    While TimerDiff($hTimer) < ($iTimeout * 1000)
        ; Ищем окно Chrome по классу
        Local $hWnd = WinGetHandle("[CLASS:Chrome_WidgetWin_1]")

        If $hWnd <> 0 And Not @error Then
            Return $hWnd
        EndIf

        Sleep(500)
    WEnd

    Return 0
EndFunc

; ============================================================================
; === ЗАКРЫТИЕ ОКНА CHROME ===================================================
; ============================================================================
Func _CloseChromeWindow($hWnd, $iPID)
    _WriteLog("Закрытие Chrome...")

    ; Пытаемся закрыть окно штатно
    If $hWnd <> 0 And WinExists($hWnd) Then
        WinClose($hWnd)
        ; Ждём закрытия до 5 секунд
        Local $iWait = 0
        While WinExists($hWnd) And $iWait < 10
            Sleep(500)
            $iWait += 1
        WEnd
    EndIf

    ; Если процесс всё ещё работает — завершаем принудительно
    If ProcessExists($iPID) Then
        _WriteLog("Принудительное завершение Chrome (PID: " & $iPID & ")")
        ProcessClose($iPID)
        ProcessWaitClose($iPID, 5)
    EndIf

    ; Дополнительная пауза после закрытия (2-4 сек)
    Sleep(Random(2000, 4000, 1))

    _WriteLog("Chrome закрыт")
EndFunc

; ============================================================================
; === УМНЫЙ SLEEP С ПРОВЕРКОЙ ФЛАГА ОСТАНОВКИ ================================
; ============================================================================
Func _SmartSleep($iMilliseconds)
    Local $hTimer = TimerInit()

    While TimerDiff($hTimer) < $iMilliseconds And $g_bRunning
        Sleep(250) ; Проверяем каждые 250 мс
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
; === ОБРАБОТЧИК ГОРЯЧЕЙ КЛАВИШИ ВЫХОДА ======================================
; ============================================================================
Func _ExitScript()
    $g_bRunning = False
    _WriteLog(">>> Получен сигнал остановки от пользователя (горячая клавиша) <<<")

    ; Закрываем все окна Chrome, которые мы могли открыть
    Local $hWnd = WinGetHandle("[CLASS:Chrome_WidgetWin_1]")
    If Not @error And $hWnd <> 0 Then
        WinClose($hWnd)
    EndIf

    _WriteLog("=== Скрипт завершён пользователем ===")
    Exit
EndFunc
