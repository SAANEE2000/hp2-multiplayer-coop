# Локальный запуск и протокол проверки HP2 multiplayer

Этот документ — протокол, а не свидетельство работоспособности кампании. `PREPARED` означает только подготовку конфигурации, `STARTED` — создание процесса. Ни одно из них не означает прохождение игрового теста. Исходный каталог игры не изменяется launch-скриптами.

## Подготовка

На каждом ПК требуется собственная установленная игра M212 и одинаковая версия mod/patches. Рабочая копия по умолчанию: `<repository>/.local/game`; её готовит `Build.ps1`. Сначала выполнить чистую overlay-сборку:

```powershell
.\Build.ps1
```

Не запускать сборку, пока игровые процессы используют её `HGame.u`. Launcher проверяет активный `UCC make`, последний результат сборки и SHA256 пакета перед запуском. Для co-op `-Baseline` недостаточно: необходим скомпилированный overlay с `HPCoopGame/HPCoopHarry`. Проверка процессов не является межпроцессной блокировкой: не начинать новую сборку параллельно с запуском.

Для двух ПК использовать **один приватно перенесённый комплект** `HGame.u` + `M212Share.u` из успешной overlay-сборки поверх собственных лицензированных development copies, затем сравнить SHA256 обоих пакетов, записать версии M212 и контрольные суммы карт. Отдельная сборка на каждом ПК не гарантирует одинаковые пакеты: у двух проверенных сборок M212Share все байты вне GUID совпали, но GUID и SHA256 различаются ([доказательство](iterations/20260920_COMPILE_CLEANUP.md)). Пакеты не добавлять в публичный Git. Совпадение Git commit при разных игровых пакетах недостаточно.

После остановки Game/UCC исходной рабочей копии создать приватный архив:

```powershell
.\scripts\Export-TestBuild.ps1
```

Результат содержит путь ZIP в `.local/distribution` и SHA256 архива. Архив включает только оба пакета, исходный UCC log и `manifest.json` с размерами/хешами, исходным результатом сборки и baseline flag. `exportCommit` обозначает HEAD во время экспорта; commit исходной сборки остаётся неизвестным, если он не был записан её build record. Передавать ZIP только приватно между владельцами лицензированных копий; карту, движок и установку игры архив не содержит.

На втором ПК подготовить собственную development copy и после остановки её Game/UCC проверить и импортировать полученный архив (имя ZIP заменить на фактическое):

```powershell
.\scripts\Prepare-LocalGame.ps1 -GameRoot 'D:\Games\HP2-M212'
.\scripts\Import-TestBuild.ps1 -Artifact '.local\distribution\hp2-test-build-ИМЯ.zip' -ValidateOnly
.\scripts\Import-TestBuild.ps1 -Artifact '.local\distribution\hp2-test-build-ИМЯ.zip'
```

`-ValidateOnly` не изменяет файлы. Импорт сначала проверяет все записи архива, хеши обоих пакетов и PASS исходного лога, отказывается от лишних/повторных/неожиданных путей и требует маркер рабочей копии. Прежние пакеты и build record сохраняются в `.local/imports/<id>`; при ошибке замены выполняется восстановление из этих копий. Новый `.local/last-build.json` явно содержит `origin=imported-test-build`, `localUccRun=false`, исходный `sourceBuild` и результат проверки целостности; это не свидетельство локального запуска UCC. Во время экспорта/импорта не запускать сборку или игру параллельно. После импорта не пересобирать пакеты на втором ПК перед парным тестом.

```powershell
Get-FileHash -LiteralPath '.local\game\System\HGame.u' -Algorithm SHA256
Get-FileHash -LiteralPath '.local\game\System\M212Share.u' -Algorithm SHA256
Get-FileHash -LiteralPath '.local\game\Maps\Ch1Rictusempra.unr' -Algorithm SHA256
```

Подготовить конфигурацию без запуска можно в любой оболочке, поддерживающей `.cmd`:

```powershell
.\HostCoop.cmd -PrepareOnly
.\JoinCoop.cmd -PrepareOnly -PlayerName Harry1
.\HostVersus.cmd -PrepareOnly
.\JoinVersus.cmd -PrepareOnly -PlayerName Harry2
```

Все параметры передаются `scripts/Launch-Multiplayer.ps1`. Доступны `-WorkRoot`, `-Map`, `-Server`, `-Port`, `-PlayerName`, `-PrepareOnly`, а для диагностических запусков — `-Unattended`. Map задаёт сюжетную/аренную карту **сервера**; клиент получает текущую карту от сервера. Это имя установленной карты, без пути и URL-параметров; расширение `.unr` необязательно. Server — IPv4 или DNS-имя, порт задаётся отдельно. Имена игроков допускают латинские буквы, цифры, `_` и `-`. Порт: 1024–65532. Разделители команд, URL-параметры и произвольные пути в этих строковых параметрах отклоняются.

## Co-op на двух физических ПК

По умолчанию сервер открывает `Ch1Rictusempra.unr?game=HGame.HPCoopGame?MaxPlayers=2`. Это кандидат обычного сюжетного уровня. Наличие всех обязательных элементов и доступность перехода нужно подтвердить исследованием карты и прохождением; имя карты само по себе не доказывает Milestone 1.

На ПК A:

```powershell
.\HostCoop.cmd -Map Ch1Rictusempra -Port 7777 -TestStage RictusempraLessonComplete
.\JoinCoop.cmd -Server 127.0.0.1 -Port 7777 -PlayerName Harry1
```

На ПК B, заменив пример адреса действительным LAN IPv4 ПК A:

```powershell
.\JoinCoop.cmd -Server 192.168.0.10 -Port 7777 -PlayerName Harry2
```

Сервер запускается скрыто; клиент — обычным оконным процессом 800×600 с `-NOFRONTEND`, минуя отдельное стартовое меню M212, и `-NewWindow`, чтобы новый клиент не передавал подключение уже открытому окну. В сессионном INI заданы FirstRun=469 и Reconfig=0 по наблюдаемому успешно использовавшемуся профилю этой версии. Скрипт задаёт `__COMPAT_LAYER=RunAsInvoker` только на время создания процесса и восстанавливает прежнее значение. Администраторские права не запрашиваются launch-скриптом. При необходимости настроить доступ к выбранному UDP-порту и порту query `+1` в частной сети. Скрипт не меняет firewall и настройки роутера.

Назначение `-NewWindow` подтверждено статическим разбором development `System/Game.exe` (SHA256 `9a04ff46650d4c51d7cea972572b5feb67e3967f696a24a208030e3ffef9edfa`): по VA `0x14000B745` загружается строка `NewWindow`, по `0x14000B74F` вызывается `Core.appStrfind` с результатом `GetCommandLineW`, а переход по `0x14000B758` при её наличии пропускает поиск `FindWindowExW` и проверку свойства `IsBrowser` через `GetPropW`. Ветка существующего окна начинается по `0x14000BA39`. Это подтверждает выбор аргумента; успешное одновременное подключение двух клиентов отмечается только по отдельному runtime-тесту.

Диагностический `-Unattended` также добавляет native `-FORCEFLUSH`, чтобы буферизация не скрывала последние строки аварийно остановленного клиента. В development `System/Core.dll` (SHA256 `40281c82e47e8e76828cb64736136cf1deafd5bd51ad42cb88c06078db687e27`) строка `FORCEFLUSH` загружается по VA `0x18008FFF0`, `ParseParam` вызывается по `0x18008FFFE`, результат записывается в экспорт `GForceLogFlush` по `0x180090003`. Обычные запуски этот флаг не получают. Подтверждены native разбор флага и генерация аргументов; полнота журнала при принудительном завершении требует отдельного runtime-теста. Перед запуском launcher проверяет SHA256 `HGame.u` и, если build/import record содержит `m212ShareSha256`, также `M212Share.u`; отсутствие файла, несовпадение или недопустимое значение записанного хеша останавливает запуск. Проверенные хеши сохраняются в launch manifest.

Проверка этой диагностики в Windows PowerShell 5: PASS для совпадающего хеша и старой записи без поля; ожидаемый отказ для несовпадающего, отсутствующего, пустого и недопустимого хеша. Четыре `-PrepareOnly` случая Host/Join с `-Unattended` и без него подтвердили добавление `FORCEFLUSH` только при диагностическом запуске. Проверялся настоящий guard из AST launcher на отдельных фиктивных файлах; игровые пакеты и процессы не менялись.

Управление co-op: WASD — штатные `Axis aForward/aStrafe`, Space/правая кнопка мыши — Jump, левая кнопка — AltFire (прицеливание/оригинальное заклинание), Shift — Walking. Сохранены специальные кнопки исходного управления для контекста broom/vendor/duel; это не подтверждение работоспособности самих специальных механик. Все унаследованные `bVersus...` bindings удалены из co-op USERINI. Ручной `set input` для обычного запуска не требуется.

Во время сетевого подключения движок может создать локальную фоновую карту. Для Join launcher теперь задаёт `Map=Entry.unr`, `LocalMap=Entry.unr`, `DefaultGame=Engine.GameInfo`, локальный `Class=HGame.harry`. Endpoint имеет вид `unreal://127.0.0.1:7787/?Name=Harry1`, без `game`/`Class` overrides. Правильные `HPCoopHarry`/`HPVersusHarry` назначаются authoritative сервером в Login. Локальный Harry фоновой карты не является вторым сетевым игроком и не должен засчитываться в C01.

Это исправляет конкретный дефект прежней конфигурации: клиент брал `HPV_Entry` из исходного Default.ini, запускал на ней `HPCoopGame` и падал при поиске single-player start. У HPVersusStart флаг bSinglePlayerStart=False; в Entry есть обычный PlayerStart. В журнале проблемной сессии `coop-join-20260920-152328-415-40abf0` ошибка возникает уже после успешной инициализации rendering, поэтому её нельзя считать ошибкой видеодрайвера.

Для проверки порта manifest отдельно содержит `connectUrl`, `port` и `defaultUrlPort`. Клиентский URL.Port остаётся 7777; адрес подключения всегда явно содержит выбранный `-Port`. Проверка генератора подтверждает, что URI для тестового 7787 содержит этот порт. Реальное native подключение должно подтверждаться серверным `TcpNetDriver on port 7787` и последующим соединением именно проверяемой клиентской сессии. Отсутствие порта в старой строке Browse само по себе не доказывает его потерю: старый INI уже задавал этот порт как значение по умолчанию.

Для этой проверки `-TestStage RictusempraLessonComplete` — явный тестовый старт
Ch1 с GSTATE030 и четырьмя spells после урока. Флаг допускается только на Coop Host
с Ch1Rictusempra; клиентам он не нужен. Без флага используются map defaults,
которые не включают предшествующий урок. Это не настоящий save после урока и не
готовый campaign travel. До readiness оба клиента должны записать
`local-initial-state=GSTATE030 spells=4 test-stage=True`.

## Изоляция и журналирование

Каждый запуск получает уникальный ASCII session ID. Конфигурации создаются внутри `<WorkRoot>/System`; INI, USERINI и log передаются как простые относительные имена, потому что абсолютный INI-путь с пробелами/Unicode неправильно разбирался предоставленным UCC. **Фактический engine log может находиться в Documents/UserFolder, а не в System.** Это подтверждено первым клиентским запуском.

| Данные | Место |
|---|---|
| Manifest, PID, аргументы, SHA256 пакета | `.local/runs/<session>/launch.json` |
| Копия начальных engine/user конфигураций | `.local/runs/<session>/Engine.ini`, `User.ini` |
| stdout/stderr dedicated server или клиента | `.local/runs/<session>/server-stdout.log`, `server-stderr.log` или `client-stdout.log`, `client-stderr.log` |
| Runtime INI/USERINI | `<WorkRoot>/System/HP2MP-<session>.ini`, `HP2MP-<session>-user.ini` |
| Engine log | Кандидаты System и Documents/UserFolder записаны в `engineLogCandidates`; после collection `engineLog` содержит найденный путь |
| Снимки найденных engine logs | `.local/runs/<session>/engine-0.log` и далее после collection |
| Запрошенные SavePath/CachePath | `<WorkRoot>/MPProfiles/<session>/Save`, `Cache` |
| Запрошенный M212 UserFolder | `HP2-MP-<session>`; начальная native bootstrap-конфигурация может выбрать другой каталог |

Публичные `UdpServerUplink` и web server удалены из ServerActors; LAN beacon отключён, поэтому подключение выполняется по явному адресу. Необходимые ServerPackages сохранены. Скрипт не удаляет старые сессии и сохранения.

**Изоляция сохранений на уровне native M212 пока не подтверждена.** Первый клиент использовал `Documents/Harry - Coding Evolved/Save`, хотя сессионный INI запрашивал отдельные SavePath и UserFolder. При этом native runtime изменил сам сессионный INI в System: относительный INI действительно загружался, а начальный каталог выбирался раньше либо другим путём. Нельзя утверждать, что сохранения защищены только уникальным UserFolder в этом файле. Перед действиями с сохранениями нужно настроить отдельный начальный UserFolder именно в Default.ini рабочей development-копии и подтвердить `Save Slot Path` по журналу. Исходный Default.ini и пользовательский Game.ini в Documents не менять.

Сбор найденных журналов не запускает игру и записывает только снимки/manifest в `.local/runs`:

```powershell
.\scripts\Launch-Multiplayer.ps1 -CollectSession coop-join-YYYYMMDD-HHMMSS-mmm-abcdef
```

Подставить реальный session ID. Команда сохраняет `collectedLogs`, `observedSaveSlotPaths`, `engineLogLocationVerified` в manifest. Отсутствие engine log или завершение лога до engine initialization означает необходимость дальнейшей диагностики. Первый неудачный запуск остановился после Save Slot Path; старый успешный журнал показывал далее frontend M212. `-NOFRONTEND` добавлен на основании наличия этого native switch и этой последовательности; его новый runtime-результат должен быть отмечен отдельно.

Per-process сохранения и повторное использование кампании после полного перезапуска пока не подтверждены. Проверка checkpoint/save в таблице ниже не должна считаться пройденной до подтверждения фактического профиля и корректной политики общего campaign save.

Для остановки скрытого dedicated server сначала прочитать `processId`, `executable` и время запуска из нужного manifest. Проверить процесс по PID и завершить именно его. Не использовать массовое завершение всех `UCC.exe`/`Game.exe`: это может остановить сборку или другую сессию. Пример после подстановки реально проверенного PID:

```powershell
Get-Process -Id 12345 | Select-Object Id,StartTime,Path
Stop-Process -Id 12345
```

## Доказательства на каждую итерацию

Заполнить шапку для конкретного запуска:

```text
Commit:
Branch:
Changed files:
Why:
Build: PASS / FAIL, ссылка на UCC log и SHA256 HGame.u
M212 version and map hashes:
Server session / PC:
Client A session / PC:
Client B session / PC:
Network: LAN/WAN, observed latency, packet-loss setup if used
Automated/local tests:
2-PC tests required:
Confirmed working:
Unconfirmed:
Known regressions:
Next step:
```

К каждой строке таблицы приложить номера сессий, таймкод видео и строки server/client A/client B логов. Использовать `NOT RUN`, `PASS`, `FAIL`, `BLOCKED`. Статический просмотр кода отмечать отдельно. Два окна на одном ПК можно записать только как локальный smoke-test; это не результат двух физических ПК.

## Milestone 1: таблица выполнения

Все значения ниже первоначально `NOT RUN`. Не заменять их на PASS на основании сборки, подготовки INI или наличия реализации.

| ID | Действие | Критерий прохождения | Статус | Доказательства / дефект |
|---|---|---|---|---|
| C01 | Dedicated + два физических клиента | Два независимых PlayerPawn, слоты 0/1, корректные possession и ownership | NOT RUN | |
| C02 | Каждый двигается отдельно | Один input не двигает второго; input без ручных fix-команд | NOT RUN | |
| C03 | Камеры до/после движения | Свои BaseCam, ViewTarget, HUD, cursor, wand у обоих | NOT RUN | |
| C04 | Idle/walk/run/back/strafe/diagonal/turn | Одинаковое поведение owner/server/observer, без заметного jelly | NOT RUN | |
| C05 | Jump/running jump/fall/landing | Правильная дуга и завершение анимации у всех копий | NOT RUN | |
| C06 | Slopes/steps/walls/player collision | Нет прохождения сквозь мир, непредсказуемого ускорения/отскоков | NOT RUN | |
| C07 | Moving platform + jump from it | Base и перенос скорости корректны после correction | NOT RUN | |
| C08 | Low/medium/high ledge, falling catch | Штатные Mounting/MountFinish доходят до ходьбы у обоих игроков | NOT RUN | |
| C09 | Correction during every mount phase | Нет teleport/desync; capsule/PrePivot и камера восстановлены | NOT RUN | |
| C10 | Observer watches other player climb | Видны правильная фаза, высота, root animation и выход наверх | NOT RUN | |
| C11 | Оба применяют оригинальные spells | Верный caster/owner, нет подмены сюжетных заклинаний HPVersusSpell | NOT RUN | |
| C12 | Оба воздействуют на spellTrigger | Мир изменён один раз и одинаков у обоих | NOT RUN | |
| C13 | Оба активируют дверь/кнопку/trigger | Срабатывание разрешено по семантике; story не дублируется | NOT RUN | |
| C14 | Enemy switches between players | AI выбирает живого подходящего игрока и реально наносит урон обоим | NOT RUN | |
| C15 | Damage + knockback + falling damage | Server health меняется один раз, HUD соответствует ему | NOT RUN | |
| C16 | Один игрок умирает | Другой продолжает; умерший корректно возвращается | NOT RUN | |
| C17 | Оба игрока умирают | Общий checkpoint reload; камера/input/spells восстановлены обоим | NOT RUN | |
| C18 | Pickup / inventory | Один мир, явно проверенная shared/per-player политика | NOT RUN | |
| C19 | Сюжетный cutscene/event | Server выполняет мир один раз, input блокируется у обоих | NOT RUN | |
| C20 | Cutscene завершается | Обоим возвращены личные camera/HUD/input; без зависания второго | NOT RUN | |
| C21 | Переход на следующую карту | Оба автоматически travel; не требуется повторный open IP | NOT RUN | |
| C22 | Disconnect/reconnect | Освободившийся slot использован безопасно; camera/wand не чужие | NOT RUN | |
| C23 | Латентность/потери | Нет двойной симуляции, неограниченных correction spikes и зависаний | NOT RUN | |

Для C08–C10 отдельно записывать `Role`, `RemoteRole`, `Physics`, `State`, `Location`, `Velocity`, `Acceleration`, `Rotation`, `DesiredRotation`, `Base`, `Floor`, `AnimSequence/Frame/Rate`, `MountDelta/MountBase`, capsule и render offset. PHYS_None у observer сам по себе не FAIL; сопоставлять actor position и изображение. Подробности реального state flow — в `audits/MOVEMENT_AUDIT.md`.

Если Ch1Rictusempra не содержит требуемой сцены/перехода или entry point сломан, записать BLOCKED и конкретную причину; выбрать следующую настоящую сюжетную карту через `-Map`. Техническая arena не заменяет сюжетное прохождение.

## Milestone 2 и регрессии

| ID | Проверка | Статус | Доказательства / дефект |
|---|---|---|---|
| M01 | Несколько последовательных сюжетных карт без ручного reconnect | NOT RUN | |
| M02 | Shared progression, открытые двери, spell unlock после travel | NOT RUN | |
| M03 | Checkpoint, enemy reset, смерть одного/обоих на следующей карте | NOT RUN | |
| M04 | Server/StoryLeader save-load, включая перезапуск процесса | NOT RUN | |
| M05 | Новая игра и полный путь до конца кампании | NOT RUN | |
| R01 | Single-player на собранных изменённых пакетах: movement/spells/story/camera/save | NOT RUN | |
| R02 | Сохранённый Versus: connect, movement, camera, cast smoke-test | NOT RUN | |
| S01 | Whomping Willow / Flying Ford | NOT RUN | |
| S02 | Quidditch/broom / dueling | NOT RUN | |
| S03 | Polyjuice/Goyle/stealth/vendors/lessons/collectibles | NOT RUN | |
| S04 | Aragog/Basilisk/rail movement/scripted companions | NOT RUN | |

R01 должен использовать именно пакеты проверяемой сборки в отдельном single-player test profile. Запуск неизменённой исходной установки не доказывает отсутствие регрессии mod. Для специальных систем пока нужна отдельная реализация/проверка, а не автоматический PASS после обычной карты.

## Versus — после завершённого co-op

Launcher сохранён для регрессий существующего foundation; глубокая доработка Versus ждёт завершения co-op.

```powershell
.\HostVersus.cmd -Map HPV_Entry -Port 7787
.\JoinVersus.cmd -Server 127.0.0.1 -Port 7787 -PlayerName Harry1
# На втором ПК:
.\JoinVersus.cmd -Server 192.168.0.10 -Port 7787 -PlayerName Harry2
```

MaxPlayers=2, ScoreLimit=3. WASD/стрелки используют `Button bVersusMove...`, Space/правая кнопка — `Button bVersusJump`, левая — AltFire, 1–6 — существующие VersusSpell1…6. Это сохраняет исходный direct fallback v18; launcher не объявляет native movement включённым и не добавляет одновременно вторую ось к button-пути. После изменения movement foundation обновить контракт управления и повторить тест.

| ID | Действие | Критерий | Статус | Доказательства / дефект |
|---|---|---|---|---|
| V01 | Join, character selection, spawn | Выбор подтверждён сервером и одинаков у обоих | NOT RUN | |
| V02 | Движение/прыжок/подтягивание/анимации | Отдельные камеры и управление без ручных fix-команд | NOT RUN | |
| V03 | Каждое из шести заклинаний | Server validation, spawn, collision, реальный hit/damage; одних FX недостаточно | NOT RUN | |
| V04 | Death → score → respawn | Один kill credit, PRI/HUD верны, управление восстановлено | NOT RUN | |
| V05 | First to 3 | Матч действительно завершён, winner отображён | NOT RUN | |
| V06 | Restart/rematch/reconnect | Состояние матча и pawn ownership восстановлены | NOT RUN | |

## Проверка самих launch-скриптов в этой итерации

Выполнена подготовка конфигураций всех четырёх сочетаний Mode/Role, синтаксический разбор PowerShell, проверка host/join URL, изоляции имён файлов, отсутствия публичных uplink и Versus bindings в co-op, ScoreLimit=3 и отклонения недопустимых map/server/name/port. После runtime-диагностики основного агента добавлены NOFRONTEND/FirstRun, сбор логов и отдельная безопасная локальная карта клиента. Повторная генерация подтверждает Entry/Engine.GameInfo для обоих Join, сохранение игровых классов/карт Host, явный endpoint 7787 при клиентском default 7777. Сбор существующего клиентского лога подтвердил реальный Documents-путь и исходный Save Slot Path. Чтение JSON явно использует UTF-8, включая Windows PowerShell 5, чтобы не портить кириллические пути. Игровые процессы самим разработчиком launch-tooling не запускались; runtime smoke-tests основного агента учитываются отдельно. Проверка генерации конфигурации и разбор URI библиотекой .NET не доказывают native подключение или применение движком всех значений INI.
