[CmdletBinding()]
param(
    [switch]$RenderPreview,
    [switch]$SelfTest,
    [ValidateSet('Main','Coop','Versus','VersusCharacters','CoopStart','CoopLevels','CoopLoad','CoopHost','CoopJoin','VersusHost','VersusJoin')]
    [string]$PreviewPage = 'Main'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$repo = Split-Path $PSScriptRoot -Parent
$script:versusProfilePath = Join-Path $repo '.local\versus-menu-player.json'
$script:versusName = 'Harry'
$script:versusCharacter = 'Harry'
$script:versusHostWindowX = 20
$script:versusHostWindowY = 40
$script:versusHostWindowWidth = 800
$script:versusHostWindowHeight = 600
$script:versusJoinWindowX = 840
$script:versusJoinWindowY = 40
$script:versusJoinWindowWidth = 800
$script:versusJoinWindowHeight = 600
if (Test-Path -LiteralPath $script:versusProfilePath) {
    try {
        $savedProfile = Get-Content -LiteralPath $script:versusProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($savedProfile.name -match '^[A-Za-z0-9][A-Za-z0-9_-]{0,22}$') { $script:versusName = $savedProfile.name }
        if ($savedProfile.character -in @('Harry','Ron','Hermione')) { $script:versusCharacter = $savedProfile.character }
        foreach ($setting in @('hostWindowX','hostWindowY','joinWindowX','joinWindowY')) {
            $value = 0
            if ([int]::TryParse([string]$savedProfile.$setting, [ref]$value) -and
                $value -ge -32768 -and $value -le 32767) {
                Set-Variable -Scope Script -Name ('versus' + $setting.Substring(0,1).ToUpperInvariant() + $setting.Substring(1)) -Value $value
            }
        }
        foreach ($setting in @('hostWindowWidth','hostWindowHeight','joinWindowWidth','joinWindowHeight')) {
            $value = 0
            $minimum = if ($setting -like '*Width') { 320 } else { 240 }
            $maximum = if ($setting -like '*Width') { 7680 } else { 4320 }
            if ([int]::TryParse([string]$savedProfile.$setting, [ref]$value) -and
                $value -ge $minimum -and $value -le $maximum) {
                Set-Variable -Scope Script -Name ('versus' + $setting.Substring(0,1).ToUpperInvariant() + $setting.Substring(1)) -Value $value
            }
        }
    } catch { Write-Verbose 'Ignoring unreadable local Versus menu profile.' }
}
function Save-VersusProfile {
    if ($SelfTest) { return }
    if ($script:versusName -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,22}$') { return }
    @{
        name=$script:versusName; character=$script:versusCharacter
        hostWindowX=$script:versusHostWindowX; hostWindowY=$script:versusHostWindowY
        hostWindowWidth=$script:versusHostWindowWidth; hostWindowHeight=$script:versusHostWindowHeight
        joinWindowX=$script:versusJoinWindowX; joinWindowY=$script:versusJoinWindowY
        joinWindowWidth=$script:versusJoinWindowWidth; joinWindowHeight=$script:versusJoinWindowHeight
    } | ConvertTo-Json |
        Set-Content -LiteralPath $script:versusProfilePath -Encoding UTF8
}
function Remember-VersusName {
    if ($script:currentMode -eq 'Versus' -and $script:nameBox -and !$script:nameBox.IsDisposed) {
        $script:versusName = $script:nameBox.Text
        Save-VersusProfile
    }
}
$help = Join-Path $repo '.local\game\Help'
foreach ($file in @('Background.bmp','buttonUp.bmp','buttonDown.bmp')) {
    if (!(Test-Path -LiteralPath (Join-Path $help $file) -PathType Leaf)) {
        throw "Original menu art is missing from the development copy: $file"
    }
}
$script:background = [System.Drawing.Image]::FromFile((Join-Path $help 'Background.bmp'))
$script:buttonUp = [System.Drawing.Image]::FromFile((Join-Path $help 'buttonUp.bmp'))
$script:buttonDown = [System.Drawing.Image]::FromFile((Join-Path $help 'buttonDown.bmp'))
$script:form = New-Object System.Windows.Forms.Form
$script:form.Text = 'Main'
$script:form.ClientSize = New-Object System.Drawing.Size(640, 720)
$script:form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$script:form.MaximizeBox = $false
$script:form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$script:form.BackColor = [System.Drawing.Color]::Black
$script:form.KeyPreview = $true
$script:form.Add_Paint({
    param($sender, $eventArgs)
    $eventArgs.Graphics.DrawImage($script:background, [System.Drawing.Rectangle]::new(0,0,640,535))
})

function Clear-MenuPage {
    while ($script:form.Controls.Count -gt 0) {
        $control = $script:form.Controls[0]
        $script:form.Controls.RemoveAt(0)
        $control.Dispose()
    }
}

function Add-MenuButton {
    param([string]$Caption, [int]$Top, [scriptblock]$OnClick)
    $button = New-Object System.Windows.Forms.Button
    $button.Location = New-Object System.Drawing.Point(205, $Top)
    $button.Size = New-Object System.Drawing.Size(230, 70)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::Black
    $button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::Black
    $button.UseVisualStyleBackColor = $false
    $button.BackgroundImage = $script:buttonUp
    $button.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Stretch
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Font = New-Object System.Drawing.Font('Segoe UI', 13)
    $button.Text = $Caption
    $button.Add_MouseEnter({ $this.BackgroundImage = $script:buttonDown })
    $button.Add_MouseLeave({ $this.BackgroundImage = $script:buttonUp })
    $button.Add_Click($OnClick)
    $script:form.Controls.Add($button)
    return $button
}

function Add-MenuLabel {
    param([string]$Caption, [int]$Top, [int]$Height = 30, [int]$FontSize = 12)
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(75, $Top)
    $label.Size = New-Object System.Drawing.Size(490, $Height)
    $label.BackColor = [System.Drawing.Color]::Transparent
    $label.ForeColor = [System.Drawing.Color]::White
    $label.Font = New-Object System.Drawing.Font('Segoe UI', $FontSize)
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $label.Text = $Caption
    $script:form.Controls.Add($label)
    return $label
}

function Add-MenuInput {
    param([string]$Caption, [string]$Value, [int]$Top, [int]$Width = 330)
    [void](Add-MenuLabel $Caption ($Top - 30) 25 11)
    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = New-Object System.Drawing.Point(([int]((640 - $Width) / 2)), $Top)
    $box.Size = New-Object System.Drawing.Size($Width, 29)
    $box.Font = New-Object System.Drawing.Font('Segoe UI', 12)
    $box.BackColor = [System.Drawing.Color]::FromArgb(22,25,54)
    $box.ForeColor = [System.Drawing.Color]::White
    $box.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $box.Text = $Value
    $script:form.Controls.Add($box)
    return $box
}

function Add-MenuSideInput {
    param([string]$Caption, [string]$Value, [int]$Left, [int]$Top, [int]$Width)
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(($Left - 35), ($Top - 28))
    $label.Size = New-Object System.Drawing.Size(($Width + 70), 24)
    $label.BackColor = [System.Drawing.Color]::Transparent
    $label.ForeColor = [System.Drawing.Color]::White
    $label.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $label.Text = $Caption
    $script:form.Controls.Add($label)

    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = New-Object System.Drawing.Point($Left, $Top)
    $box.Size = New-Object System.Drawing.Size($Width, 29)
    $box.Font = New-Object System.Drawing.Font('Segoe UI', 12)
    $box.BackColor = [System.Drawing.Color]::FromArgb(22,25,54)
    $box.ForeColor = [System.Drawing.Color]::White
    $box.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $box.Text = $Value
    $script:form.Controls.Add($box)
    return $box
}

function Read-WindowPosition {
    param([System.Windows.Forms.TextBox]$XBox, [System.Windows.Forms.TextBox]$YBox,
          [ref]$X, [ref]$Y)
    $xValue = 0
    $yValue = 0
    if (![int]::TryParse($XBox.Text, [ref]$xValue) -or
        ![int]::TryParse($YBox.Text, [ref]$yValue) -or
        $xValue -lt -32768 -or $xValue -gt 32767 -or
        $yValue -lt -32768 -or $yValue -gt 32767) {
        [void][System.Windows.Forms.MessageBox]::Show(
            'Координаты X и Y должны быть целыми числами от -32768 до 32767.',
            'Положение окна', [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return $false
    }
    $X.Value = $xValue
    $Y.Value = $yValue
    return $true
}

function Read-WindowSize {
    param([System.Windows.Forms.TextBox]$WidthBox, [System.Windows.Forms.TextBox]$HeightBox,
          [ref]$Width, [ref]$Height)
    $widthValue = 0
    $heightValue = 0
    if (![int]::TryParse($WidthBox.Text, [ref]$widthValue) -or
        ![int]::TryParse($HeightBox.Text, [ref]$heightValue) -or
        $widthValue -lt 320 -or $widthValue -gt 7680 -or
        $heightValue -lt 240 -or $heightValue -gt 4320) {
        [void][System.Windows.Forms.MessageBox]::Show(
            'Ширина должна быть 320–7680, высота — 240–4320 пикселей.',
            'Размер окна', [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return $false
    }
    $Width.Value = $widthValue
    $Height.Value = $heightValue
    return $true
}

function Invoke-MenuGame {
    param([string]$Mode, [string]$Address, [int]$PortNumber, [string]$Name,
          [string]$CoopMap = 'Ch1Rictusempra', [int]$MaxPlayers = 8, [int]$ScoreLimit = 3,
          [int]$WindowX = 20, [int]$WindowY = 40,
          [int]$WindowWidth = 800, [int]$WindowHeight = 600)
    try {
        if ($Mode -like 'Versus*') { $script:versusName = $Name; Save-VersusProfile }
        $launchParameters = @{
            LaunchMode=$Mode; Server=$Address; Port=$PortNumber; PlayerName=$Name
            Character=$script:versusCharacter; MaxPlayers=$MaxPlayers; ScoreLimit=$ScoreLimit
            WindowX=$WindowX; WindowY=$WindowY; WindowWidth=$WindowWidth; WindowHeight=$WindowHeight
        }
        # Versus has its own fixed arena. Do not pass the unrelated co-op map
        # field: on a fresh menu session $script:coopMap has not been set yet.
        if ($Mode -like 'Coop*') { $launchParameters.CoopMap = $CoopMap }
        if ($SelfTest) {
            $result = & (Join-Path $PSScriptRoot 'Start-MenuTest.ps1') @launchParameters -DryRun
            $script:lastTestLaunch = $result
            return
        }
        $result = & (Join-Path $PSScriptRoot 'Start-MenuTest.ps1') @launchParameters
        if (!$result) { throw 'The game did not report a successful launch.' }
        $script:form.Close()
    } catch {
        if ($SelfTest) { throw }
        [void][System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message, 'Ошибка запуска',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Show-MainMenu {
    Clear-MenuPage
    $script:page = 'Main'
    [void](Add-MenuButton 'Новая игра' 275 { Invoke-MenuGame 'Single' '127.0.0.1' 7777 'Harry' })
    [void](Add-MenuButton 'Загрузка игры' 353 { Invoke-MenuGame 'Original' '127.0.0.1' 7777 'Harry' })
    [void](Add-MenuButton 'Настройка' 431 { Invoke-MenuGame 'Original' '127.0.0.1' 7777 'Harry' })
    [void](Add-MenuButton 'Кооператив' 509 { Show-ModeMenu 'Coop' })
    [void](Add-MenuButton 'Версус' 587 { Show-ModeMenu 'Versus' })
    [void](Add-MenuLabel 'Загрузка и настройка открывают исходное меню игры.' 674 25 9)
}

function Show-ModeMenu {
    param([ValidateSet('Coop','Versus')][string]$Mode)
    Remember-VersusName
    Clear-MenuPage
    $script:page = 'Mode'
    $script:currentMode = $Mode
    $title = if ($Mode -eq 'Coop') { 'Кооператив' } else { 'Версус' }
    [void](Add-MenuLabel $title 275 35 19)
    if ($Mode -eq 'Coop') {
        [void](Add-MenuButton 'Создать сервер' 355 { Show-CoopStartMenu })
        [void](Add-MenuButton 'Подключиться' 445 { Show-JoinMenu })
        [void](Add-MenuButton 'Назад' 555 { Show-MainMenu })
        [void](Add-MenuLabel 'Кооперативная кампания пока экспериментальная.' 668 30 10)
    } else {
        $script:nameBox = Add-MenuInput 'Имя игрока' $script:versusName 333 300
        [void](Add-MenuLabel ("Персонаж: " + $(switch ($script:versusCharacter) {
            Ron { 'Рон' }; Hermione { 'Гермиона' }; default { 'Гарри' }
        })) 372 27 11)
        [void](Add-MenuButton 'Выбрать персонажа' 400 { Remember-VersusName; Show-VersusCharacters })
        [void](Add-MenuButton 'Создать сервер' 478 { Remember-VersusName; Show-HostMenu })
        [void](Add-MenuButton 'Подключиться' 556 { Remember-VersusName; Show-JoinMenu })
        [void](Add-MenuButton 'Назад' 634 { Remember-VersusName; Show-MainMenu })
    }
}

function Show-VersusCharacters {
    Clear-MenuPage
    $script:page = 'VersusCharacters'
    [void](Add-MenuLabel 'Выбор персонажа' 275 38 18)
    [void](Add-MenuLabel ("Выбран: " + $(switch ($script:versusCharacter) {
        Ron { 'Рон' }; Hermione { 'Гермиона' }; default { 'Гарри' }
    })) 314 25 11)
    $harryButton = Add-MenuButton 'Гарри' 349 { $script:versusCharacter='Harry'; Save-VersusProfile; Show-ModeMenu 'Versus' }
    $ronButton = Add-MenuButton 'Рон' 428 { $script:versusCharacter='Ron'; Save-VersusProfile; Show-ModeMenu 'Versus' }
    $hermioneButton = Add-MenuButton 'Гермиона' 507 { $script:versusCharacter='Hermione'; Save-VersusProfile; Show-ModeMenu 'Versus' }
    switch ($script:versusCharacter) {
        Ron { $ronButton.ForeColor = [System.Drawing.Color]::Gold }
        Hermione { $hermioneButton.ForeColor = [System.Drawing.Color]::Gold }
        default { $harryButton.ForeColor = [System.Drawing.Color]::Gold }
    }
    [void](Add-MenuButton 'Назад' 617 { Show-ModeMenu 'Versus' })
}

function Show-CoopStartMenu {
    Clear-MenuPage
    $script:page = 'CoopStart'
    [void](Add-MenuLabel 'Кооператив: создать сервер' 263 38 17)
    [void](Add-MenuButton 'Новая игра' 337 {
        Show-CoopHostMenu 'Ch1Rictusempra'
    })
    [void](Add-MenuButton 'Загрузить' 421 { Show-CoopLoadMenu })
    [void](Add-MenuButton 'Выбор уровня' 505 { Show-CoopLevelsMenu })
    [void](Add-MenuButton 'Назад' 601 { Show-ModeMenu 'Coop' })
    [void](Add-MenuLabel 'Новая игра начинает тест с урока Риктусемпра.' 682 25 9)
}

function Show-CoopLoadMenu {
    Clear-MenuPage
    $script:page = 'CoopLoad'
    [void](Add-MenuLabel 'Загрузка кооператива' 272 38 18)
    [void](Add-MenuLabel 'Сохранения кооператива пока не поддерживаются.' 360 36 12)
    [void](Add-MenuLabel 'Одиночные сохранения здесь открывать нельзя:' 403 30 11)
    [void](Add-MenuLabel 'они не восстанавливают состояние двух игроков.' 435 30 11)
    [void](Add-MenuButton 'Выбор уровня' 520 { Show-CoopLevelsMenu })
    [void](Add-MenuButton 'Назад' 612 { Show-CoopStartMenu })
}

function Show-CoopLevelsMenu {
    Clear-MenuPage
    $script:page = 'CoopLevels'
    [void](Add-MenuLabel 'Выбор уровня' 251 38 18)
    [void](Add-MenuButton 'Риктусемпра' 300 { Show-CoopHostMenu 'Ch1Rictusempra' })
    [void](Add-MenuButton 'Скурдж (эксп.)' 374 { Show-CoopHostMenu 'Ch2Skurge' })
    [void](Add-MenuButton 'Диффиндо (эксп.)' 448 { Show-CoopHostMenu 'Ch3Diffindo' })
    [void](Add-MenuButton 'Спонгифай (эксп.)' 522 { Show-CoopHostMenu 'Ch4Spongify' })
    [void](Add-MenuButton 'Назад' 608 { Show-CoopStartMenu })
    [void](Add-MenuLabel 'Другие уровни — прямой тестовый запуск, без прогресса.' 690 22 9)
}

function Show-CoopHostMenu {
    param([ValidateSet('Ch1Rictusempra','Ch2Skurge','Ch3Diffindo','Ch4Spongify')]
          [string]$Map)
    $script:coopMap = $Map
    Show-HostMenu
}

function Show-HostMenu {
    Clear-MenuPage
    $script:page = 'Host'
    $title = if ($script:currentMode -eq 'Coop') { 'Кооператив: сервер' } else { 'Версус: сервер' }
    [void](Add-MenuLabel $title 275 35 18)
    if ($script:currentMode -eq 'Coop') {
        $mapLabel = switch ($script:coopMap) {
            Ch1Rictusempra { 'Риктусемпра' }
            Ch2Skurge { 'Скурдж (эксп.)' }
            Ch3Diffindo { 'Диффиндо (эксп.)' }
            Ch4Spongify { 'Спонгифай (эксп.)' }
        }
        [void](Add-MenuLabel ("Уровень: " + $mapLabel) 318 30 11)
    }
    if ($script:currentMode -eq 'Versus') {
        [void](Add-MenuLabel ("Игрок: " + $script:versusName) 318 27 11)
        $script:slotsBox = Add-MenuSideInput 'Игроков (2–8)' '8' 160 374 110
        $script:scoreBox = Add-MenuSideInput 'Фрагов (1–99)' '3' 370 374 110
        $script:windowXBox = Add-MenuSideInput 'Окно X' ([string]$script:versusHostWindowX) 220 442 90
        $script:windowYBox = Add-MenuSideInput 'Окно Y' ([string]$script:versusHostWindowY) 330 442 90
        $script:windowWidthBox = Add-MenuSideInput 'Ширина' ([string]$script:versusHostWindowWidth) 220 496 90
        $script:windowHeightBox = Add-MenuSideInput 'Высота' ([string]$script:versusHostWindowHeight) 330 496 90
        [void](Add-MenuButton 'Запустить сервер' 535 {
            $slots = 0; $score = 0; $windowX = 0; $windowY = 0; $windowWidth = 0; $windowHeight = 0
            if (![int]::TryParse($script:slotsBox.Text, [ref]$slots) -or $slots -lt 2 -or $slots -gt 8 -or
                ![int]::TryParse($script:scoreBox.Text, [ref]$score) -or $score -lt 1 -or $score -gt 99) {
                [void][System.Windows.Forms.MessageBox]::Show('Укажите 2–8 игроков и 1–99 фрагов.', 'Параметры матча',
                    [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }
            if (!(Read-WindowPosition $script:windowXBox $script:windowYBox ([ref]$windowX) ([ref]$windowY))) { return }
            if (!(Read-WindowSize $script:windowWidthBox $script:windowHeightBox ([ref]$windowWidth) ([ref]$windowHeight))) { return }
            $script:versusHostWindowX = $windowX
            $script:versusHostWindowY = $windowY
            $script:versusHostWindowWidth = $windowWidth
            $script:versusHostWindowHeight = $windowHeight
            Save-VersusProfile
            Invoke-MenuGame 'VersusHost' '127.0.0.1' 7777 $script:versusName $script:coopMap $slots $score $windowX $windowY $windowWidth $windowHeight
        })
    } else {
        $script:nameBox = Add-MenuInput 'Имя игрока' 'Harry' 385 300
        [void](Add-MenuLabel 'Порт сервера: 7777  •  Максимум: 2 игрока' 440 30 11)
        [void](Add-MenuButton 'Запустить сервер' 500 {
            Invoke-MenuGame 'CoopHost' '127.0.0.1' 7777 $script:nameBox.Text $script:coopMap
        })
    }
    [void](Add-MenuButton 'Назад' 615 {
        if ($script:currentMode -eq 'Coop') { Show-CoopStartMenu }
        else { Show-ModeMenu $script:currentMode }
    })
    if ($script:currentMode -eq 'Coop') {
        $hint = if ($script:coopMap -eq 'Ch1Rictusempra') {
            'Запустятся отдельный сервер и ваше окно игры.'
        } else {
            'Экспериментальный старт; сервер откроет ваше окно игры.'
        }
        [void](Add-MenuLabel $hint 674 28 9)
    } else {
        [void](Add-MenuLabel 'Арена: Startup. Порт: 7777. Вы тоже входите в матч.' 691 22 9)
    }
}

function Show-JoinMenu {
    Clear-MenuPage
    $script:page = 'Join'
    $title = if ($script:currentMode -eq 'Coop') { 'Кооператив: подключение' } else { 'Версус: подключение' }
    [void](Add-MenuLabel $title 266 35 17)
    if ($script:currentMode -eq 'Versus') {
        $script:addressBox = Add-MenuInput 'IP-адрес или имя сервера' '127.0.0.1' 334 330
        [void](Add-MenuLabel ("Игрок: " + $script:versusName) 370 25 10)
        $script:portBox = Add-MenuSideInput 'Порт' '7777' 145 428 100
        $script:windowXBox = Add-MenuSideInput 'Окно X' ([string]$script:versusJoinWindowX) 270 428 100
        $script:windowYBox = Add-MenuSideInput 'Окно Y' ([string]$script:versusJoinWindowY) 395 428 100
        $script:windowWidthBox = Add-MenuSideInput 'Ширина' ([string]$script:versusJoinWindowWidth) 220 486 90
        $script:windowHeightBox = Add-MenuSideInput 'Высота' ([string]$script:versusJoinWindowHeight) 345 486 90
        $joinTop = 525
        $backTop = 615
    } else {
        $script:addressBox = Add-MenuInput 'IP-адрес или имя сервера' '127.0.0.1' 338 330
        $script:portBox = Add-MenuInput 'Порт' '7777' 414 130
        $script:nameBox = Add-MenuInput 'Имя игрока' 'Harry2' 490 300
        $joinTop = 548
        $backTop = 634
    }
    [void](Add-MenuButton 'Подключиться' $joinTop {
        $portNumber = 0; $windowX = 20; $windowY = 40; $windowWidth = 800; $windowHeight = 600
        if (![int]::TryParse($script:portBox.Text, [ref]$portNumber) -or
            $portNumber -lt 1024 -or $portNumber -gt 65535) {
            [void][System.Windows.Forms.MessageBox]::Show('Порт должен быть числом от 1024 до 65535.',
                'Неверный порт', [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        if ($script:currentMode -eq 'Versus') {
            if (!(Read-WindowPosition $script:windowXBox $script:windowYBox ([ref]$windowX) ([ref]$windowY))) { return }
            if (!(Read-WindowSize $script:windowWidthBox $script:windowHeightBox ([ref]$windowWidth) ([ref]$windowHeight))) { return }
            $script:versusJoinWindowX = $windowX
            $script:versusJoinWindowY = $windowY
            $script:versusJoinWindowWidth = $windowWidth
            $script:versusJoinWindowHeight = $windowHeight
            Save-VersusProfile
            $joinName = $script:versusName
        } else {
            $joinName = $script:nameBox.Text
        }
        Invoke-MenuGame ($script:currentMode + 'Join') $script:addressBox.Text $portNumber $joinName 'Ch1Rictusempra' 8 3 $windowX $windowY $windowWidth $windowHeight
    })
    [void](Add-MenuButton 'Назад' $backTop { Show-ModeMenu $script:currentMode })
}

$script:form.Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.KeyCode -ne [System.Windows.Forms.Keys]::Escape) { return }
    if ($script:page -eq 'Host' -and $script:currentMode -eq 'Coop') { Show-CoopStartMenu }
    elseif ($script:page -eq 'VersusCharacters') { Show-ModeMenu 'Versus' }
    elseif ($script:page -eq 'CoopLevels' -or $script:page -eq 'CoopLoad') { Show-CoopStartMenu }
    elseif ($script:page -eq 'CoopStart') { Show-ModeMenu 'Coop' }
    elseif ($script:page -in @('Host','Join')) { Show-ModeMenu $script:currentMode }
    elseif ($script:page -eq 'Mode') { Show-MainMenu }
    else { $script:form.Close() }
})

try {
    Show-MainMenu
    if ($SelfTest) {
        $script:form.Show()
        [System.Windows.Forms.Application]::DoEvents()
        foreach ($step in @(
            @('Кооператив','Mode'), @('Создать сервер','CoopStart'),
            @('Загрузить','CoopLoad'), @('Выбор уровня','CoopLevels'),
            @('Скурдж (эксп.)','Host'), @('Назад','CoopStart'),
            @('Выбор уровня','CoopLevels'), @('Назад','CoopStart'),
            @('Назад','Mode'), @('Подключиться','Join'), @('Назад','Mode'),
            @('Назад','Main'), @('Версус','Mode'), @('Создать сервер','Host'),
            @('Назад','Mode'), @('Назад','Main')
        )) {
            $button = @($script:form.Controls | Where-Object {
                $_ -is [System.Windows.Forms.Button] -and $_.Text -eq $step[0]
            }) | Select-Object -First 1
            if (!$button) { throw "Missing menu button: $($step[0])" }
            Write-Output "Click $($step[0]) from $script:page, mode=$script:currentMode"
            $button.PerformClick()
            [System.Windows.Forms.Application]::DoEvents()
            Write-Output "Reached $script:page, mode=$script:currentMode"
            if ($script:page -ne $step[1]) {
                throw "Click on $($step[0]) led to $script:page instead of $($step[1])."
            }
        }
        Invoke-MenuGame 'Single' '127.0.0.1' 7777 'Harry'
        if ($script:lastTestLaunch.LaunchMode -ne 'Single' -or
            $script:lastTestLaunch.URL -ne 'PrivetDr.unr?game=Engine.GameInfo') {
            throw 'Single-player menu route failed.'
        }
        Show-ModeMenu 'Coop'
        Show-CoopStartMenu
        $newCoopButton = @($script:form.Controls | Where-Object {
            $_ -is [System.Windows.Forms.Button] -and $_.Text -eq 'Новая игра'
        }) | Select-Object -First 1
        $newCoopButton.PerformClick()
        if ($script:page -ne 'Host' -or $script:coopMap -ne 'Ch1Rictusempra') {
            throw 'Co-op new-game menu route failed.'
        }
        Invoke-MenuGame 'CoopHost' '127.0.0.1' 7777 'Harry' $script:coopMap
        if ($script:lastTestLaunch.LaunchMode -ne 'CoopHost' -or
            $script:lastTestLaunch.URL -ne 'Ch1Rictusempra.unr?game=HGame.HPCoopGame?MaxPlayers=2' -or
            $script:lastTestLaunch.Arguments[0] -ne 'server') {
            throw 'Co-op host menu route failed.'
        }
        Show-CoopLevelsMenu
        $levelButton = @($script:form.Controls | Where-Object {
            $_ -is [System.Windows.Forms.Button] -and $_.Text -eq 'Диффиндо (эксп.)'
        }) | Select-Object -First 1
        $levelButton.PerformClick()
        Invoke-MenuGame 'CoopHost' '127.0.0.1' 7777 'Harry' $script:coopMap
        if ($script:lastTestLaunch.CoopMap -ne 'Ch3Diffindo' -or
            $script:lastTestLaunch.URL -ne 'Ch3Diffindo.unr?game=HGame.HPCoopGame?MaxPlayers=2') {
            throw 'Co-op level-selection route failed.'
        }
        Show-ModeMenu 'Versus'
        # Reproduce a fresh process: no co-op page has initialized this value.
        $script:coopMap = $null
        $chooseButton = @($script:form.Controls | Where-Object {
            $_ -is [System.Windows.Forms.Button] -and $_.Text -eq 'Выбрать персонажа'
        }) | Select-Object -First 1
        $chooseButton.PerformClick()
        $ronButton = @($script:form.Controls | Where-Object {
            $_ -is [System.Windows.Forms.Button] -and $_.Text -eq 'Рон'
        }) | Select-Object -First 1
        $ronButton.PerformClick()
        if ($script:versusCharacter -ne 'Ron' -or $script:page -ne 'Mode') { throw 'Versus character selection failed.' }
        Show-HostMenu
        Invoke-MenuGame 'VersusHost' '127.0.0.1' 7777 $script:versusName $null 8 3 $script:versusHostWindowX $script:versusHostWindowY $script:versusHostWindowWidth $script:versusHostWindowHeight
        if ($script:lastTestLaunch.LaunchMode -ne 'VersusHost' -or
            $script:lastTestLaunch.URL -ne 'startup.unr?game=HGame.HPVersusGame?MaxPlayers=8?ScoreLimit=3' -or
            $script:lastTestLaunch.Arguments[0] -ne 'server' -or
            $script:lastTestLaunch.Character -ne 'Ron' -or
            $script:lastTestLaunch.WindowX -ne $script:versusHostWindowX -or
            $script:lastTestLaunch.WindowY -ne $script:versusHostWindowY -or
            $script:lastTestLaunch.WindowWidth -ne $script:versusHostWindowWidth -or
            $script:lastTestLaunch.WindowHeight -ne $script:versusHostWindowHeight) {
            throw 'Versus host menu route failed.'
        }
        Show-JoinMenu
        if ($script:addressBox.Text -ne '127.0.0.1' -or
            $script:portBox.Text -ne '7777' -or
            $script:windowXBox.Text -ne ([string]$script:versusJoinWindowX) -or
            $script:windowYBox.Text -ne ([string]$script:versusJoinWindowY) -or
            $script:windowWidthBox.Text -ne ([string]$script:versusJoinWindowWidth) -or
            $script:windowHeightBox.Text -ne ([string]$script:versusJoinWindowHeight)) {
            throw 'Versus join menu fields failed.'
        }
        Write-Output 'Menu navigation self-test passed.'
    } elseif ($RenderPreview) {
        switch ($PreviewPage) {
            Coop       { Show-ModeMenu 'Coop' }
            Versus     { Show-ModeMenu 'Versus' }
            VersusCharacters { Show-ModeMenu 'Versus'; Show-VersusCharacters }
            CoopStart  { Show-ModeMenu 'Coop'; Show-CoopStartMenu }
            CoopLevels { Show-ModeMenu 'Coop'; Show-CoopLevelsMenu }
            CoopLoad   { Show-ModeMenu 'Coop'; Show-CoopLoadMenu }
            CoopHost   { Show-ModeMenu 'Coop'; Show-CoopHostMenu 'Ch1Rictusempra' }
            CoopJoin   { Show-ModeMenu 'Coop'; Show-JoinMenu }
            VersusHost { Show-ModeMenu 'Versus'; Show-HostMenu }
            VersusJoin { Show-ModeMenu 'Versus'; Show-JoinMenu }
        }
        $script:form.Show()
        [System.Windows.Forms.Application]::DoEvents()
        $bitmap = New-Object System.Drawing.Bitmap($script:form.Width, $script:form.Height)
        try {
            $script:form.DrawToBitmap($bitmap,
                [System.Drawing.Rectangle]::new(0,0,$script:form.Width,$script:form.Height))
            $out = Join-Path $repo ('.local\menu-preview-' + $PreviewPage + '.png')
            $bitmap.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Output $out
        } finally { $bitmap.Dispose(); $script:form.Hide() }
    } else {
        [void]$script:form.ShowDialog()
    }
} finally {
    $script:form.Dispose()
    $script:background.Dispose()
    $script:buttonUp.Dispose()
    $script:buttonDown.Dispose()
}
