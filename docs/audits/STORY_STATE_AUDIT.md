# Ch1 launch stage и порядок native screening — 20 сентября 2026

Минимальное состояние после урока Rictusempra: **`GSTATE030`**, числовой cache **30**, четыре заклинания **Flipendo, Lumos, Alohomora, Rictusempra**. `STATE030` не является допустимым token. Это воспроизводимая launch fixture, а не сохранение кампании или доказанный перенос состояния через уровни.

## Точные исходные свидетельства

- `Engine/Classes/PlayerPawn.uc:5631–5634`: длина token 9, master list включает `GSTATE030`, исходное `CurrentGameState="None"`.
- `System/cutscenes/02080DADARictaEnd.int:51`: команда `Harry changegamestate gstate030`; строка 55 запускает `ChangeLevelCh1Rictusempra`.
- `HGame/Classes/Triggers/SpellLessonTrigger.uc:842–853`: `EndLesson` для Rictusempra добавляет только `spellRictusempra`.
- `HGame/Classes/harry.uc:335–338`: `PreBeginPlay` добавляет Flipendo/Lumos/Alohomora и выключает `bNoSpellBookCheck`.
- `harry.uc:156` и `Engine/Classes/PlayerPawn.uc:278`: SpellBook[32] и CurrentGameState являются travel properties. Числовой `harry.iGameState` — отдельный cache (`harry.uc:314`), обновляемый в `SetGameState` (`5673–5688`) и `TravelPostAccept` (`960`). Одной записи строкового состояния недостаточно для пользователей cache.

Все пути исходников в этом отчёте относятся к локальной development copy `.local/game`. Исходные ресурсы не включаются в Git.

## Фактический порядок в установленном M212

Проверен установленный 64-bit `System/Engine.dll`, SHA-256 `e7bd8f53aa1bce2386ba8943fdfc4d4c54c0a27948f49bc0de53dee22cc82391`. Экспорты PE разрешены по именам; инструкции `UGameEngine::LoadMap` и `ULevel::ScreenActorsByGameState` прочитаны Capstone без запуска/изменения DLL. Локальные заметки: `.local/engine-export-audit.json`, `.local/engine-loadmap-disassembly.txt`, `.local/engine-screen-disassembly.txt`.

В свежей ветке загрузки вызовы следуют в таком порядке (RVA относительно image base, не адрес запущенного процесса):

| Этап | RVA свидетельства |
| --- | --- |
| `AGameInfo::eventInitGame` | `0x9BCA0` — прямой вызов |
| Цикл actor `PreBeginPlay` | `0x9BCF5` — имя события; dispatch `0x9BD11` |
| Цикл actor `BeginPlay` | `0x9BD58`; dispatch `0x9BD74` |
| Цикл actor `PostBeginPlay` | `0x9BE08`; dispatch `0x9BE24` |
| Позднее native `ScreenActorsByGameState` | `0x9C60E` — прямой вызов |

Следовательно, **screening здесь происходит после PostBeginPlay**, а не до него. `Game.InitGame` подходит для установки fixture до обоих этапов; свежий `Game.PostBeginPlay` подходит для CaptureFrom после завершения всех PreBeginPlay, но менять состояние впервые там менее надёжно: остальные PostBeginPlay могли уже прочитать его. Не переносить этот порядок без проверки на другую версию движка. Save/load и client pending ветки имеют дополнительные условия; их полная эквивалентность fresh dedicated load не утверждается.

Native screening не начинает с `Level.PlayerHarryActor`. В `ScreenActorsByGameState` (RVA `0xAAFA0`) цикл `0xAB000–0xAB024` перебирает actors и выбирает первого `IsPlayer`: проверяются `Actor+0xB4 & 0x40` и `Pawn+0x710 & 2`. Экспорт `AActor::IsPlayer` (RVA `0x46040`) использует те же два флага — `bIsPawn` и `bIsPlayer`. Далее берётся состояние этого pawn. Значение `NONE` приводит к раннему выходу (`0xAB051–0xAB064`, строка `NONE` по RVA `0x1C0578`). Для групп `GSTATE...` и исключений вычисляется `bInCurrentGameState`; затем отправляется `OnResolveGameState` (`0xAB315–0xAB354`).

Поэтому **нельзя ставить map legacy Harry `bIsPlayer=False` в Game.PostBeginPlay до native прохода**. Записать только Level alias или только новый pawn позднего Login недостаточно. Оставить legacy флаг до окончания загрузки; отключить его в последующем Login, когда выбран настоящий StoryLeader. Скрыть visual/коллизию legacy отдельно можно, но из состояния `None` screening не получится.

`LevelInfo.PreBeginPlay` сам выбирает первого PlayerPawn для `Level.PlayerHarryActor` (`Engine/Classes/LevelInfo.uc:213–221`). В InitGame legacy нужно находить обходом акторов, не предполагать, что Level alias уже заполнен. Для этой fixture следует подтвердить, что первый native IsPlayer — именно ожидаемый map Harry.

## Почему повторный поздний resolve не является исправлением

`PlayerPawn.SetGameState` (`5541–5577`) валидирует и сохраняет строку «to be applied when we load a level». Он не вызывает screening. Доступного UnrealScript native API `ScreenActorsByGameState` в предоставленных классах нет. Поле `bInCurrentGameState` const (`Actor.uc:349`). Вызов одного `OnResolveGameState` не вычисляет его заново.

Последствия старого решения могут быть необратимыми: `Mover.OnResolveGameState` уничтожает неподходящий движущийся actor (`Mover.uc:171–179`); `Triggers.OnResolveGameState` выключает Trigger и коллизию (`Triggers.uc:10–19`); HPawn скрывается и теряет коллизию (`HPawn.uc:139–145`); CutScene переходит в disabled (`CutScene.uc:110–130`). Нельзя имитировать native проход поздним принудительным `bInCurrentGameState=True` или повторным запуском cutscene.

## Минимальный helper и интеграция

Добавлен отдельный `mod/HGame/Classes/HPCoopCampaignState.uc`; Game/Harry/launcher/Build этим аудитом не изменены. Helper самостоятельно не запускается и не меняет карту.

1. Game разбирает явный опциональный token **`RictusempraLessonComplete`**, по умолчанию fixture выключена. Неизвестный token/другая карта должны завершать запуск с ошибкой. Наличие слова Rictusempra в map name само по себе не включает fixture.
2. В fresh `InitGame` найти map Harry и вызвать `HPCoopCampaignState.Static.SeedCh1TestStage(H)`. Функция дополнительно требует Ch1Rictusempra, authority, нулевое Level.TimeSeconds, пустой/None story state и отсутствие уже освоенных небазовых заклинаний. Она не очищает настоящий spellbook, а отказывается от неожиданного входа; выставляет ровно GSTATE030/cache30 и четыре разрешённых заклинания. Точное имя текущей карты проверяется через package outer LevelInfo.
3. Сохранить `bIsPlayer` этого Harry до native screening. В Game.PostBeginPlay создать state actor, вызвать `CaptureFrom(LegacyHarry, AppliedFixture)` после всех actor PreBeginPlay. При выключенной fixture второй аргумент пустой. Ошибка CaptureFrom должна удерживать session readiness; нельзя запускать неполный snapshot.
4. До server ready/casting применить `ApplyTo(H)` к зарегистрированному co-op pawn. Передать state actor владельцу через RPC/GRI; на клиенте повторять попытку только до первого успешного `ApplyTo` к собственному Harry. На simulated proxy helper отказывается применять данные.
5. Реплицируются все 32 class slots, StoryState/StoryIndex, origin metadata и readiness. Дополнительно реплицируется `LearnedSpellCount`: один `bInitialized` не означает, что массив уже дошёл. `IsSnapshotReady` проверяет число/индексы непустых slots, три базовых заклинания и согласованность string/cache; для тестового snapshot — также четвёртое заклинание и fixture token. Array replication требует проверки в UCC и двух клиентах.
6. `ApplyTo` копирует ровно snapshot, включая пустые slots, и отключает `bNoSpellBookCheck`. Не вызывать каждый Tick после первого успешного применения: иначе последующее legitimate story/spell изменение будет затёрто старым начальным snapshot. Для настоящего progression нужны revisions и обновление от authority, которые этот helper пока не реализует.

Fixture не добавляет Skurge, Diffindo, Spongify или duel spells. Не вызывает Trigger, BeginChallenge, SaveGame, SavePActors, SetGameState с побочными UI callbacks или ServerTravel. `HPCoopCampaignState` пока не скомпилирован/не запускался этим аудитом; root выполняет общий UCC gate.

## Содержимое самой Ch1 карты и граница fixture

Read-only разбор serialized property tags `Ch1Rictusempra.unr` выполнен до конца каждого исследованного actor payload; сведения сохранены в `.local/ch1-stage-properties.json`. `Harry0` не содержит собственного CurrentGameState override и имеет Group `None,StartRoom`. `CutScene1` задаёт `FileName=Ch1RictuIntro`, `bLevelLoadStarts=True`, Group `None,CutScene`. Исследованные CutScene не содержат собственного GSTATE group. Это не заменяет полного аудита всех акторов карты.

`SmartStart0` ожидает `PreviousLevelName=Entryhall_hub`, `SmartStart1` — `Grandstaircase_hub`; оба явно имеют `bDoLevelSave=True`. Поэтому для теста не подделывать PreviousLevelName ради выбора SmartStart: `harry.TravelPostAccept:986–1004` одновременно может инициировать SaveGame. Существующий отдельный co-op spawn остаётся отдельной проверяемой механикой. Fixture намеренно не копирует house points, карты, награды урока, objective, здоровье или доказательство посещения hub; утверждение «точный save после урока» было бы неверно.

## Настоящий travel/save: отдельный контракт

Обычный путь: cutscene меняет game state → TriggerChangeLevel → `harry.LoadLevel` (`888–919`) сохраняет persistent character state и вызывает `SavePActors`, затем HPConsole.ChangeLevel → `Level.ServerTravel(lev, flag)` (`Internal/HPConsole.uc:1036–1046`). `PreClientTravel` (`harry.uc:922–949`) переносит previous map/status/health; `TravelPostAccept` (`951–1026`) восстанавливает status, карты, SmartStart и часть UI. Просто копировать CurrentGameState/SpellBook не воспроизводит этот цикл.

Для настоящей кампании нужен отдельный авторитетный snapshot с origin `campaign-travel`/`campaign-save`, source/destination, revision/session identity, objective/status и политикой shared versus personal rewards; его восстановление должно быть подготовлено до native screening. Test-stage origin должен оставаться явно отмеченным в launch/session diagnostics. Не включать fixture повторно при restart, load или последующем travel; сохранённый непустой state имеет приоритет и в helper вызывает отказ от reseed.

## Client pending: найденная граница решения

В той же DLL есть встроенная URL option **`?GameState=GSTATE030`**. `LoadMap` получает `GAMESTATE=` через `FURL::GetOption` (RVA `0x9B647–0x9B656`), сообщает `URL had a GState command, %s`, затем ищет map PlayerPawn и присваивает его `CurrentGameState` по offset `0x1930` (`0x9B6AF–0x9B723`). Это раньше InitGame/PreBeginPlay. Данный путь не обновляет Harry.iGameState и не выдаёт заклинания; он не заменяет fixture/snapshot. Для server seed текущий helper намеренно откажет при уже непустом состоянии — без отдельного обоснования нельзя одновременно включать native GameState option и считать такую загрузку fresh.

**Одна такая URL option не решает client screening.** Сразу после неё `LoadMap` вызывает `ULevel::IsServer` (RVA `0x9B9D7`, vtable slot `+0x148`). В client ветке `0x9B9E1–0x9BA3F` движок удаляет map actors без `bStatic`/`bNoDelete` (`Actor+0xB0 & 0x11`) через `ULevel::DestroyActor`; у оставшихся меняет местами Role/RemoteRole (`0x9BA23–0x9BA37`). Это происходит **до InitGame/PreBeginPlay**. Обычный map Harry имеет именно такой удаляемый lifecycle; в его source hierarchy нет default bStatic/bNoDelete. Установка CurrentGameState перед этим удалением не сохраняет источник для более позднего screening.

Проверены оба vtable адреса в exported `ULevel` UObject vtable (RVA `0x1AB0E0`): slot `+0x148` указывает на `ULevel::IsServer` (`0xAD370`), `+0x168` — на `ULevel::DestroyActor` (`0xA5380`). Сама `ScreenActorsByGameState` не имеет проверки NetMode/client: она требует живого IsPlayer actor в загружаемом уровне. Не смешивать viewport pawn из Entry с pawn загружаемого Ch1.

Независимое подтверждение уже есть в runtime root: `.local/runs/coop-join-20260920-162408-304-a157a7/engine-0.log:1355` содержит `Can't find a valid player` после `Bringing Level Ch1Rictusempra... up for play`. Только затем приходят own HPCoopHarry и `local-initial-state=GSTATE030 spells=4 test-stage=True` (строка 1362). Это положительное наблюдение initial snapshot для одного loopback владельца, одновременно доказательство того, что snapshot опоздал для native screening. Клиентский мир этой записью **не проверен**.

У конкретного Ch1Rictusempra package весь name table не содержит ни GSTATE names, ни имени `ExcludeGameStates`. Поиск исходных defaultproperties в Engine/HGame/HProps также не нашёл присваивания `ExcludeGameStates=` или Group с GSTATE. Поэтому явных serialized GSTATE selectors для этой карты не обнаружено; это основание ограничить milestone этой fixture, но не заявлять общую эквивалентность клиентского мира. Не исключены runtime изменения groups/состояния, и полный визуальный/коллизионный аудит здесь не выполнен.

Минимальное честное действие для текущего milestone — сохранить этот gate открытым и отдельно проверять Ch1 actors/коллизии. Для общей кампании потребуется отдельное раннее решение: native override источника story state или специально спроектированный surviving bootstrap actor в уровне до screening. Любой такой вариант требует нового lifecycle/network аудита. Глобальное `harry.bNoDelete=True`, повторный поздний OnResolve и принудительный const bInCurrentGameState не являются исправлением. Самостоятельно native/library/map изменения этим аудитом не выполнялись.

Не подтверждены: seed/replication на двух физических ПК, эквивалентность client world screening, save ветки, полноценный travel/save, прохождение challenge и отсутствие регрессий NPC. Общий UCC/runtime gate выполняет root; этот аудит не запускал и не пересобирал игру. Read-only сведения URL/client cleanup внесены после первых loopback runs, а не выданы за их успешное исправление.
