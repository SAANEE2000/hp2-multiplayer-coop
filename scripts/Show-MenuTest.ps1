[CmdletBinding()]
param(
    [switch]$RenderPreview,
    [switch]$SelfTest,
    [ValidateSet('Main','Coop','Versus','CoopStart','CoopLevels','CoopLoad','CoopHost','CoopJoin','VersusHost','VersusJoin')]
    [string]$PreviewPage = 'Main'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$repo = Split-Path $PSScriptRoot -Parent
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

function Invoke-MenuGame {
    param([string]$Mode, [string]$Address, [int]$PortNumber, [string]$Name,
          [string]$CoopMap = 'Ch1Rictusempra')
    try {
        if ($SelfTest) {
            $result = & (Join-Path $PSScriptRoot 'Start-MenuTest.ps1') `
                -LaunchMode $Mode -Server $Address -Port $PortNumber -PlayerName $Name `
                -CoopMap $CoopMap -DryRun
            $script:lastTestLaunch = $result
            return
        }
        $result = & (Join-Path $PSScriptRoot 'Start-MenuTest.ps1') `
            -LaunchMode $Mode -Server $Address -Port $PortNumber -PlayerName $Name `
            -CoopMap $CoopMap
        if (!$result) { throw 'The game did not report a successful launch.' }
        $script:form.Close()
    } catch {
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
    Clear-MenuPage
    $script:page = 'Mode'
    $script:currentMode = $Mode
    $title = if ($Mode -eq 'Coop') { 'Кооператив' } else { 'Версус' }
    [void](Add-MenuLabel $title 275 35 19)
    [void](Add-MenuButton 'Создать сервер' 355 {
        if ($script:currentMode -eq 'Coop') { Show-CoopStartMenu }
        else { Show-HostMenu }
    })
    [void](Add-MenuButton 'Подключиться' 445 { Show-JoinMenu })
    [void](Add-MenuButton 'Назад' 555 { Show-MainMenu })
    if ($Mode -eq 'Coop') {
        [void](Add-MenuLabel 'Кооперативная кампания пока экспериментальная.' 668 30 10)
    }
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
    $script:nameBox = Add-MenuInput 'Имя игрока' 'Harry' 385 300
    [void](Add-MenuLabel 'Порт сервера: 7777  •  Максимум: 2 игрока' 440 30 11)
    [void](Add-MenuButton 'Запустить сервер' 500 {
        Invoke-MenuGame ($script:currentMode + 'Host') '127.0.0.1' 7777 `
            $script:nameBox.Text $script:coopMap
    })
    [void](Add-MenuButton 'Назад' 595 {
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
    }
}

function Show-JoinMenu {
    Clear-MenuPage
    $script:page = 'Join'
    $title = if ($script:currentMode -eq 'Coop') { 'Кооператив: подключение' } else { 'Версус: подключение' }
    [void](Add-MenuLabel $title 266 35 17)
    $script:addressBox = Add-MenuInput 'IP-адрес или имя сервера' '127.0.0.1' 338 330
    $script:portBox = Add-MenuInput 'Порт' '7777' 414 130
    $script:nameBox = Add-MenuInput 'Имя игрока' 'Harry2' 490 300
    [void](Add-MenuButton 'Подключиться' 548 {
        $portNumber = 0
        if (![int]::TryParse($script:portBox.Text, [ref]$portNumber) -or
            $portNumber -lt 1024 -or $portNumber -gt 65535) {
            [void][System.Windows.Forms.MessageBox]::Show('Порт должен быть числом от 1024 до 65535.',
                'Неверный порт', [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        Invoke-MenuGame ($script:currentMode + 'Join') $script:addressBox.Text $portNumber $script:nameBox.Text
    })
    [void](Add-MenuButton 'Назад' 634 { Show-ModeMenu $script:currentMode })
}

$script:form.Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.KeyCode -ne [System.Windows.Forms.Keys]::Escape) { return }
    if ($script:page -eq 'Host' -and $script:currentMode -eq 'Coop') { Show-CoopStartMenu }
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
        $newButton = @($script:form.Controls | Where-Object {
            $_ -is [System.Windows.Forms.Button] -and $_.Text -eq 'Новая игра'
        }) | Select-Object -First 1
        $newButton.PerformClick()
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
        $hostButton = @($script:form.Controls | Where-Object {
            $_ -is [System.Windows.Forms.Button] -and $_.Text -eq 'Запустить сервер'
        }) | Select-Object -First 1
        $hostButton.PerformClick()
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
        $hostButton = @($script:form.Controls | Where-Object {
            $_ -is [System.Windows.Forms.Button] -and $_.Text -eq 'Запустить сервер'
        }) | Select-Object -First 1
        $hostButton.PerformClick()
        if ($script:lastTestLaunch.CoopMap -ne 'Ch3Diffindo' -or
            $script:lastTestLaunch.URL -ne 'Ch3Diffindo.unr?game=HGame.HPCoopGame?MaxPlayers=2') {
            throw 'Co-op level-selection route failed.'
        }
        Show-ModeMenu 'Versus'
        Show-JoinMenu
        $joinButton = @($script:form.Controls | Where-Object {
            $_ -is [System.Windows.Forms.Button] -and $_.Text -eq 'Подключиться'
        }) | Select-Object -First 1
        $joinButton.PerformClick()
        if ($script:lastTestLaunch.LaunchMode -ne 'VersusJoin' -or
            $script:lastTestLaunch.URL -notmatch 'MPMode=Versus') {
            throw 'Versus join menu route failed.'
        }
        Write-Output 'Menu navigation self-test passed.'
    } elseif ($RenderPreview) {
        switch ($PreviewPage) {
            Coop       { Show-ModeMenu 'Coop' }
            Versus     { Show-ModeMenu 'Versus' }
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
