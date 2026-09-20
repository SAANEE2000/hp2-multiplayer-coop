# Первый co-op smoke test на двух ПК

Цель: проверить подключение двух настоящих клиентов, личные камеры/управление, intro Ch1, заклинания и одиночную смерть/возрождение. Это **диагностическая сборка, не завершённый Milestone 1**. Ledge/mount, campaign travel/save и disconnect во время сцены пока отмечать **NOT RUN**. Серверные health/Lumos fixtures прошли loopback, но их визуальная и физическая двух-PC проверка ещё нужна. Полный протокол: [LOCAL_TEST_PROTOCOL.md](LOCAL_TEST_PROTOCOL.md).

## 1. Подготовить оба ПК

На каждом ПК нужна собственная установленная HP2/M212 и одна версия этих scripts. Распакуйте source ZIP в отдельный каталог, откройте там PowerShell. Исходная игра — только источник копирования. Подставьте **свой** путь; он может различаться на ПК A и B:

```powershell
$ErrorActionPreference = 'Stop'
$gameRoot = 'D:\Games\HP2-M212'
$workRoot = Join-Path (Get-Location) '.local\game'
.\scripts\Prepare-LocalGame.ps1 -GameRoot $gameRoot -WorkRoot $workRoot
```

Prepare создаёт `.hp2-development-copy.json` и выбирает отдельный bootstrap profile в Default.ini копии. Оригинал и его сохранения не изменяются. Во время подготовки/импорта остановите Game/UCC этой рабочей копии. На импортирующем ПК **Build запускать не нужно**.

Из одного приватного test kit положите одинаковые binary ZIP и runtime JSON в `.local\distribution` обоих source-каталогов. Для текущего комплекта:

```powershell
$artifact = '.local\distribution\hp2-test-build-20260920-174718-213-0e6031d4.zip'
$runtime = '.local\distribution\hp2-runtime-20260920-163839-818-d45d6265.json'
.\scripts\Test-RuntimeCompatibility.ps1 -WorkRoot $workRoot -Manifest $runtime
if ($LASTEXITCODE -ne 0) { throw 'Runtime differs; keep the INCOMPATIBLE report and stop here.' }
.\scripts\Import-TestBuild.ps1 -WorkRoot $workRoot -Artifact $artifact -ValidateOnly
.\scripts\Import-TestBuild.ps1 -WorkRoot $workRoot -Artifact $artifact
```

Требуется `COMPATIBLE`, затем успешный import. `MISSING`, `AMBIGUOUS` или `MISMATCH` перечисляют конкретные файлы; сравните свою версию M212 с комплектом до запуска. Не подменяйте эталон JSON и не копируйте случайные DLL. Проверяются Engine/Core DLL и U, Game/UCC EXE, IpDrv DLL/U, Entry и Ch1 карты. HGame.u и M212Share.u проверяются отдельно внутри import. Этот набор хешей не проверяет все textures/audio/drivers и сам по себе не доказывает gameplay.

ZIP содержит одну сборку HGame.u + M212Share.u; его SHA-256: `32478d7eb852f8d06329761dcd519c699679d2194d537bfd0e7294a932543a59`. Runtime JSON SHA-256: `cebbaa5db04fad8b87ae0df4798858df2819044d79f0a9e70c8610db133b4fd0`. После import не пересобирайте пакеты независимо на двух ПК: UCC GUID может различаться. В этом artifact `sourceDirty=true`; source commit/ZIP не являются утверждением, что бинарники собраны из чистого commit. Точные пакеты определяются записанными хешами.

## 2. Запустить сервер и два клиента

Оба ПК должны быть в одной LAN. На ПК A узнайте его LAN IPv4 через `ipconfig`. Если Windows спрашивает доступ к сети, разрешите Game.exe/UCC.exe рабочей копии в частной сети; не отключайте firewall. Сервер использует выбранный UDP port 7777. При блокировке соединения сохраните ошибку/логи.

На **ПК A** в том же PowerShell:

```powershell
$hostRun = .\scripts\Launch-Multiplayer.ps1 -Mode Coop -Role Host -WorkRoot $workRoot -Map Ch1Rictusempra -Port 7777 -TestStage RictusempraLessonComplete
$joinRun = .\scripts\Launch-Multiplayer.ps1 -Mode Coop -Role Join -WorkRoot $workRoot -Server 127.0.0.1 -Port 7777 -PlayerName HarryA
$hostRun, $joinRun | Format-Table session, processId, status
```

На **ПК B**, заменив пример IP адресом ПК A:

```powershell
$joinRun = .\scripts\Launch-Multiplayer.ps1 -Mode Coop -Role Join -WorkRoot $workRoot -Server 192.168.0.10 -Port 7777 -PlayerName HarryB
$joinRun | Format-Table session, processId, status
```

Host — скрытый dedicated server; у игрока A отдельный Join. До подключения/готовности обоих ожидается пауза. `STARTED` означает только создание процесса. `-TestStage` нужен **только Host**: явно задаёт Ch1/GSTATE030 с Flipendo, Lumos, Alohomora, Rictusempra после урока; это тестовый старт, не восстановленное сохранение.

## 3. Проверить 10–15 минут и записать результат

- Intro: оба видят одну сцену; управление блокируется и возвращается обоим. Нет повторного intro, зависшего кадра или чужой камеры.
- По очереди походить WASD, повернуть камеру мышью, выполнить обычный прыжок Space на ровном месте. Второй игрок наблюдает движение, но его собственная камера/управление не меняются. Не использовать ledge/mount как критерий этого smoke test.
- Наведение и ЛКМ используют исходный выбор заклинания по цели, **не клавиши Versus 1–6**. Проверить Rictusempra на улитке/крабе, Flipendo на доступной подходящей цели, Alohomora на подходящем замке/сундуке; повторить доступные действия от обоих игроков. Записать отдельно появление FX, реальное изменение цели и то, что видит наблюдатель. Недоступную без дальнейшего прохождения цель отметить NOT RUN.
- Lumos: у доступной гаргульи активировать свет сначала одним, затем другим игроком. Проверить видимость света у обоих, работу светового объекта и отсутствие выключения чужого источника при завершении своего. Записать место и последовательность; если до гаргульи не дошли, отметить NOT RUN.
- Урон/смерть: после проверки управления по очереди дать одному игроку получить естественный урон, пока второй жив и стоит на ровном безопасном полу. Записать чей HUD меняется, анимацию смерти, появление рядом с напарником с 41 HP и восстановление управления. Затем поменяться ролями. Движущиеся платформы пока не подходят для этой проверки. Если оба умерли, ожидается сообщение о недоступном shared checkpoint; закончить эту сессию и собрать логи.
- При первом дефекте записать ПК A/B, примерное время, действие и ожидаемое/фактическое поведение. Не применять `set`, summon, all-spells, force release или другие ручные исправления: исходный дефект нужен в логах.

Известные ограничения этого комплекта: канонический Гарри ещё может не выполнять scripted walk во вступлении, хотя камера и release проходят; AI пока не адаптирован для выбора обоих игроков. Подбор предметов, книги checkpoint и меню save/load ещё не готовы — в этом smoke test их не использовать. Не включать `-RuntimeProbe`: автоматические fixtures меняют здоровье/инвентарь и предназначены для отдельной разработки.

В клиентских логах ожидается `local-initial-state=GSTATE030 spells=4 test-stage=True`. Для диагностики полезны `[MP_LOGIN]`, `[MP_CAMERA]`, `[MP_CUTSCENE]`, `[MP_SPELL]`, `[MP_LUMOS]`. Native `Can't find a valid player` при client map screening — известная незакрытая граница; её наличие не скрывать. Начальный snapshot не доказывает полную корректность client world state.

## 4. Вернуть логи

Сначала закройте оба клиентских окна обычным способом. Затем на A остановите **только свой dedicated server**: возьмите processId из `$hostRun`/его `launch.json` и сверьте Path и StartTime через `Get-Process -Id <PID> | Select Id,Path,StartTime`; после сверки выполните `Stop-Process -Id <PID>` для этого сервера. Не используйте остановку всех UCC по имени.

**Collection выполнять после остановки клиентов и сервера**: M212 держит активный engine log с эксклюзивным доступом, поэтому копирование во время работы может завершиться ошибкой. На каждом ПК, пока сохранена переменная `$joinRun`, соберите журнал; на A дополнительно серверный:

```powershell
.\scripts\Launch-Multiplayer.ps1 -CollectSession $joinRun.session
# Только на A:
.\scripts\Launch-Multiplayer.ps1 -CollectSession $hostRun.session
```

Если PowerShell уже закрыт, session ID — имя соответствующего каталога `.local\runs\coop-join-...` / `coop-host-...`; подставьте его строкой в `-CollectSession`. Collection находит engine logs в реальном M212 profile, который может находиться в Documents, и копирует их в каталог session.

С каждого ПК отправьте приватно ZIP выбранных **тестовых session-каталогов** из `.local/runs` с `launch.json`, `engine-*.log`, stdout/stderr и INI, а также `.local/last-build.json`, эталон runtime JSON и краткий текст результатов по пунктам выше. Назовите архивы `PC-A-logs.zip` и `PC-B-logs.zip`. При визуальном дефекте приложите кадр/короткую запись обоих экранов, если удобно. Не добавляйте папку игры, сохранения, игровые packages или весь `.local` в архив логов. Логи могут содержать локальные пути и LAN IP; пересылайте их приватно.

## Для подготовки следующего test kit

Из своей уже отмеченной development copy создать manifest можно командой `scripts\Test-RuntimeCompatibility.ps1 -Generate -WorkRoot <copy>`. Она только читает перечисленные runtime файлы и пишет новый JSON в `.local/distribution`; установку-источник не изменяет. Эталон создаётся на стороне подготовившего сборку, затем **тот же JSON** передаётся обоим тестовым ПК. Проверка через `-Manifest` ничего не записывает и не запускает игру.
