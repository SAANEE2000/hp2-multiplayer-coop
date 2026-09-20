# Campaign / single-player-global audit — 2026-09-20

Статический аудит установленного дерева `Гарри Поттер и Тайная комната/HGame/Classes` и соответствующего Engine. Основной handoff: `04_REPORTS/Architecture_Audit_RU.md`. Код игры этим аудитом не изменялся. Номера строк относятся к прочитанному исходному состоянию; SHA-256 каждого файла в инвентаризации позволяет заметить последующие изменения. Ни один пункт ниже не является результатом двухклиентского runtime-теста.

## Ключевой вывод

Совместимость с campaign нельзя получить одним переназначением `HPawn.PlayerHarry`. Этот alias одновременно означает сюжетного Гарри, текущую жертву AI, владельца поднятого существа, покупателя/получателя inventory, получателя HUD/camera effects. Минимальный правильный foundation: отдельные registry/StoryLeader, owner-local presentation и opt-in AI resolver. Проверять один обычный уровень прежде, чем распространять изменения на кампанию.

## Реестр ссылок и границы аудита

`GLOBAL_CONTEXT_INVENTORY.tsv` содержит все **1 662 строки** из **171 HGame-файла**, найденные case-insensitive выражением `\bPlayerHarry\b|\bPlayerHarryActor\b` в `*.uc`. Повторения одного alias в строке объединены. `BaseCam.PlayerHarry` входит в поиск как `PlayerHarry`. SmartStart включён в ручной аудит, но ссылок на эти идентификаторы в нём нет.

- 60 строк имеют `REVIEWED`, ещё 4 — `REVIEWED_MIXED`: операция разобрана непосредственно.
- 77 — объявления или однострочные комментарии, а не исполняемая операция.
- 1 521 — `REVIEW_REQUIRED`. Их перечень контекстов — кандидаты для проверки, а не утверждение о завершённой семантической классификации.
- В таблицу намеренно не копируется оригинальный исходный текст. Даны путь, строка, контексты, причина и source hash.
- Инвентаризация охватывает именно два указанных identifier, не все возможные single-player assumptions (`AllActors(harry)`, `Viewport.Actor`, `PlayerHeroActor`, собственные aliases). Эти дополнительные риски отмечены ниже.

Контексты означают **назначение операции**, а не процесс исполнения: `LOCAL_PLAYER_CONTEXT` включает per-player effects, чья авторитетная часть выполняется на сервере. Owner/caster spell context требует отдельного аудита заклинаний.

## Legacy pointer и lifecycle

| Место | Факт | Следствие |
| --- | --- | --- |
| `Engine/Classes/LevelInfo.uc:213` | PreBeginPlay берёт первого PlayerPawn из AllActors и присваивает также PlayerHeroActor. | Это не реестр подключений и не доказанный slot 0. Story map может иметь размещённого Harry ещё до network login. |
| `Engine/Classes/LevelInfo.uc:245` | В явном replication block нет PlayerHarryActor. | Нельзя рассчитывать на передачу server story alias как local-player alias. |
| `HGame/Classes/HPawn.uc:92` | PreBeginPlay один раз копирует Level.PlayerHarryActor. При None только пишет лог. | Поздний login сам не обновляет уже существующие HPawn; следующие обращения могут читать None или map placeholder. Destroy здесь **не вызывается**. |
| `HGame/Classes/HPawn.uc:120` | PostBeginPlay берёт первую BaseCam из AllActors. | Второй независимый player camera не определяется таким поиском. |
| `HGame/Classes/Director.uc:11` | PreBeginPlay выбирает первого harry через AllActors. | Canonical Director должен явно знать StoryLeader, а не последнего/первого найденного pawn. |
| `HGame/Classes/Director.uc:108` | OnPlayerPossessed снимает capture, включает бессмертие, правит камеру и обращается к Player.Console. | Имеющиеся prototype unlocks опасны для настоящего cutscene lifecycle и dedicated server. |
| `HGame/Classes/harry.uc:329` | StatusManager создаётся для self; PlayerHarry менеджера = self. | Этот существующий per-pawn принцип сохранить; authoritative status и local presentation ещё не разделены. |

Для authority оставить `Level.PlayerHarryActor = GetStoryLeader()` и отдельно проверить `PlayerHeroActor`. На клиенте UI adapter может устанавливать локальный alias только для viewport-owning pawn; удалённый proxy не должен его менять. Локальный alias не должен управлять world events клиента. Для HPawn нужны два различимых источника: canonical story reference и разрешённая для конкретного класса AI target reference.

## Story state и нативная граница

`Engine/Classes/PlayerPawn.uc:278`: `CurrentGameState` — `travel string`. `SetGameState` на строке 5541 проверяет token и сохраняет строку для следующего уровня; это не общая репликация progression. `Engine/Classes/Actor.uc:349`: `bInCurrentGameState` объявлен `const` и, согласно комментарию, устанавливается native `ULevelBase::ScreenActorsByGameState()`. `Actor.uc:2117` читает CurrentGameState через Level.PlayerHarryActor.

**Блокер:** поздний GRI sync в PostLogin не доказывает, что map actors были отфильтрованы по верному состоянию. Вызов `OnResolveGameState` повторно не пересчитывает сам const flag. Нужно runtime-доказательство порядка native travel import, назначения канонического pawn и screening. До этого нельзя заявлять сохранение кампании между картами.

В shared snapshot должны войти CurrentGameState, spell unlocks, objective identifiers, canonical checkpoint, progression/lock/card ownership policy. Per-player остаются health, pawn transform, input, temporary combat effects и camera. `harry.uc:132–171,280–311` содержит travel-массивы status, wizard cards, SpellBook, duel/quidditch/challenge поля: копирование всех этих данных каждому Harry без политики создаёт дублирование наград.

## Cutscenes

| Место | Классификация и риск |
| --- | --- |
| `Cutscene/CutScene.uc:110` | GLOBAL_STORY_CONTEXT: state-based enable/disable; здесь же local fade. Нужно отделить presentation. |
| `Cutscene/CutScene.uc:374` | Touch уже допускает любой harry, а не только global alias. Любой игрок может запросить одну серверную сцену. |
| `Cutscene/CutScene.uc:387` | Trigger проверяет harry(Other).HarryIsDead без проверки cast. Trigger sender может быть не harry. |
| `Cutscene/CutScene.uc:598` | Play защищён bPlaying и bPlayOnce/nPlayedCount, создаёт threads. Это полезная локальная защита, но не replicated campaign transaction. |
| `Cutscene/CutScript.uc:212` | FindCutSubject("baseCam") возвращает canonical Harry.Cam. Это presentation context, встроенный в серверную интерпретацию сценария. |
| `Cutscene/CutScript.uc:271,300` | Прямой доступ к Player.Console для debug/cut log непригоден как dedicated-server предположение. |
| `Cutscene/CutScript.uc:973,985,1111` | GLOBAL_STORY_CONTEXT: CutQuestion actor, TriggerEvent instigator и SetGameState должны оставаться canonical/server. |
| `Cutscene/CutScript.uc:998,1004` | LOCAL_PLAYER_CONTEXT: inputoff/inputon меняют только одного Harry. Нужен session-wide lock, отдельное применение каждому owning client и проверка на server. |
| `Cutscene/CutScript.uc:1065,1746` | LOCAL_PLAYER_CONTEXT: HUD комментарий/ShakeView должны отправляться relevant clients. |
| `Cutscene/CutScript.uc:1076–1097` | GLOBAL_STORY_CONTEXT: save/load commands исполнять один раз; native multiplayer save/load ещё не проверен. |
| `harry.uc:520,528,5368` | Disable/EnablePlayerInput и CutCommand Capture/Release меняют myHUD напрямую. Release дополнительно затрагивает локальный console. |
| `harry.uc:5553` | SendPlayerCaptureMessages счётчиком вызывает PlayerCutCapture/Release **всех actors**. Вызов на двух pawn дублирует world notification. |
| `Cutscene/CutSceneManager.uc:60,74,82,109,179` | LOCAL_PLAYER_CONTEXT: capture/HUD для владельца интерфейса, а не сюжетного proxy. |

Предлагаемая минимальная политика: одна серверная CutScene/CutScript sequence, StoryLeader — canonical cut actor; начало/конец сцены имеют session sequence id и server capture depth. World capture callbacks отправляются один раз. На всех игроках отдельно применяются gameplay lock и replicated local presentation. Второму игроку не запускать собственные world-changing CutScript. Для первой версии допустима общая постановочная камера, получающая серверный transform; server camera/control actor нельзя путать с личными BaseCam. Обязательны release, force-finish, skipped scene, disconnected leader и late-join-in-scene paths. Во всех выходах восстанавливаются собственные camera/ViewTarget, HUD и input. Простое безусловное EnablePlayerInput каждый Tick ломает это требование.

## Triggers и предметы

| Класс/строка | Семантика | Безопасное первое решение |
| --- | --- | --- |
| `Triggers/TriggerChangeLevel.uc:20,32` | GLOBAL_STORY_CONTEXT: любой допустимый запрос переводит общий мир. | В foundation решить, кто вправе инициировать; один server travel transaction. Не просто поменять equality. |
| `Triggers/DisableTrigger.uc:21` | GLOBAL_STORY_CONTEXT: отключает объект с Event tag. | Проверить конкретную карту; если обычная пространственная активация, любой coop player на authority. |
| `Triggers/CardLockTrigger.uc:26,39` | Shared cards/locks расходуются, запускаются четыре lock events, есть UI. | Shared authority inventory и однократный расход, UI fanout. |
| `Triggers/TriggerTurnOnAllSpells.uc:17,28` | Shared spell progression, сейчас флаг только у одного Harry. | Обновление обоих из общей progression модели. |
| `Triggers/NoFallingDamageTrigger.uc:9` | Per-player timer сейчас применён глобальному Harry. | Применить к подтверждённому активатору; проверить Other/EventInstigator выбранной карты. |
| `Triggers/TriggerShakeCamera.uc:25` | Local presentation. | Per-recipient shake или намеренный broadcast, согласно событию. |
| `Misc/SavePoint.uc:82` | Touch принимает любого harry, а OnSaveGame использует cached PlayerHarry. | Canonical save — допустимо, но хранить checkpoint транзакцию на server и не считать toucher's health canonical автоматически. |
| `Cutscene/CutScene.uc:374` | Touch уже допускает обоих Harry. | Сохранить semantic eligibility, добавить authority/transaction discipline. |

Проверка `Other == Level.PlayerHarryActor` не имеет одинакового значения во всех местах. Репликация конкретной двери/мувера тоже требует отдельной проверки: успешный server TriggerEvent ещё не доказывает видимость результата обоим клиентам.

## AI: проверенные пути

| AI | Прочитанные точки | Риск / минимальная адаптация |
| --- | --- | --- |
| Imp | `Enemies/Imp.uc:56,296,306,319,355,427,461–471,620` | attackDistance вычисляется при init из cached target; движение/укус используют PlayerHarry. `Owner == PlayerHarry` означает **кто держит Imp**, а не агро. При carry/throw target нужно закрепить за владельцем; перед укусом заново валидировать выбранную жертву. |
| Spider | `Enemies/Spider.uc:157–182,315,563,603` | Detection зависит от скорости PlayerHarry; Touch использует движение alias, даже если коснулся другой игрок. HitWall исключает только alias. Для контактного squish/damage использовать Other; для pursuit — target resolver. |
| CornishPixie | `Enemies/CornishPixie.uc:123,301–388` | Подлёт, дистанция и damage адресованы alias. Проверка `baseHUD(PlayerHarry.myHUD).bCutSceneMode:357` не является надёжным server cutscene flag. При AI retarget нужен стабильный target на время атаки. |
| Gnome | `Enemies/GNOME.uc:238–242,540,572,613–631,684,758,790,1130–1206` | AI sight/steal/knockback и ownership смешаны. Нельзя выбрать nearest между расчётом количества beans и вычитанием: изменится жертва/получатель. Указатели CombatTarget и transaction/carry victim должны различаться; HUD cut gate убрать из server decision. |
| FireCrab | `Enemies/firecrab.uc:152,178`; `Enemies/firecrabSmall.uc:74,235,281–288,297–325` | Реальная ranged атака находится в subclass firecrabSmall: LoS, TurnTo, Target и SpawnSpell. Общий resolver применим до выбора атаки; spawned spell сохраняет target/caster, не меняется вместе с будущим агро. |
| Humanoid / prefect | `Characters/SlytherinPrefect.uc:5` → `Characters.uc:5` → `HChar.uc:89–125,524–550,682–695` | Конкретный Prefect — data subclass. HChar видит PlayerHarry, исключает Goyle, вызывает caught story event. Bump от любого harry может захватить **другого** cached Harry. Это AI обнаружение + shared stealth failure, не просто damage targeting. |
| Humanoid / duellist | `Characters/Duellist.uc:94,123,199,206,408,590–596,912–921,1009–1045` | Соперник читает именно Harry wand spell list, duel modes/ranks и lane position. Не включать в общий свободный aggro: это отдельная scripted duel subsystem. |
| Boss / Aragog | `Bosses/Aragog.uc:114,414–415,467,527–546,781–808,834–843,934–948,1161` | Movement/bite может выбирать цель. Fear/run-speed modes, StopBossEncounter — shared encounter; ShakeView — local presentation. Вытеснение PlayerHarry nearest-целью потеряет восстановление свойств предыдущего игрока. |

Первый общий resolver размещать в coop game/session, authority only: отфильтрованные зарегистрированные живые players; сохранение допустимой current target, предпочтение подтверждённого attacker, видимость и расстояние с hysteresis. Не сканировать AllActors каждый Tick каждого enemy. Adapter в HPawn/HChar должен быть **opt-in** для проверенных enemy classes и их subclasses; default сохраняет single-player StoryLeader semantics. Получателя carry/steal закреплять отдельно. No-alive-players → безопасная остановка атаки и общий death policy, не dereference None. Смена target по смерти и уничтожению pawn обязательна.

В текущих class implementations нет самостоятельного coop target selection; статический анализ не доказывает, что все AI actors присутствуют/анимируются на обоих клиентах. Проверить relevancy/Role/RemoteRole/animation и authoritative damage на реальной карте.

## Travel, save и checkpoint

- `harry.uc:888–920` сохраняет persistent Character metadata, выполняет SavePActors и достигает travel через `HPConsole(Player.Console).ChangeLevel`. Dedicated server не должен требовать локального Player.Console.
- `Internal/HPConsole.uc:1036` вызывает Level.ServerTravel. Значит нужный механизм уже есть, проблема — UI-зависимый вход.
- `Engine/Classes/LevelInfo.uc:227` блокирует второй travel, пока NextURL непуст. `Engine/Classes/GameInfo.uc:659–697` рассылает ClientTravel всем PlayerPawn с NetConnection. Это правильный UE1 route, не ручной reconnect.
- `harry.uc:951–1040` TravelPostAccept смешивает per-pawn weapon/status restore и shared RemoveHarryOwnedCardsFromLevel/duel setup/SmartStart SaveGame. Оба pawn будут перемещены в одну SmartStart location. Разделить shared once-only posttravel и per-player bootstrap; slot 1 ставить на collision-tested offset.
- `SmartStart.uc:5–8` — только PreviousLevelName и bDoLevelSave; собственной multiplayer логики нет.
- `harry.uc:876–885` PreSaveGame копирует status и меняет PreviousLevelName; `Engine/Classes/PlayerPawn.uc:402–411` SaveGame только ставит bQueuedToSaveGame. Поведение native queued save на dedicated server требует проверки.
- `Misc/SavePoint.uc:54–79` временно повышает canonical health до минимума, вызывает SaveGame и сразу возвращает health. Native timing сохранения уже скрыт за queue; нельзя выводить MP restore из этого source path.
- `harry.uc:1764` death load использует `ConsoleCommand("LoadGame 0")`. Замена одиночной смерти на обычный native load может оборвать второму игроку мир.

Минимальный checkpoint сначала можно реализовать отдельным authoritative coop snapshot + безопасным respawn, явно обозначив, что это ещё **не полное native save/load**. При одной смерти игрок появляется возле живого teammate/проверенного checkpoint. При обеих — shared recovery один раз, с новой session generation и bootstrap обоих. Требуется сохранить даже случай, когда slot 0 умер, а slot 1 жив: canonical story progression не должен зависеть от alive target выбора.

## Специальные механики, найденные по реальным исходникам

Не включать в первый generic AI patch: `Misc/FlyingFordDirector.uc`, `Quidditch/QuidditchDirector.uc`, `Quidditch/QuidditchLessonDirector.uc`, `Characters/Duellist.uc`, `Triggers/HarryToGoyleTrigger.uc`, `HChar` stealth/capture, `Bosses/Basilisk.uc`, `Bosses/Aragog.uc`, `Bosses/BossRailMove.uc`, `Characters/Characters.uc` vendors/persistent companions, `Triggers/SpellLessonTrigger.uc`, `Triggers/SpellChallengeTrigger.uc`, `Misc/Adv1TutManager.uc`, wizard-card status groups. Их наличие подтверждено; работоспособность в coop не проверена.

## Следующий минимальный milestone

Предварительный кандидат — установленная `Adv3DungeonQuest.unr` с `System/cutscenes/Adv3DungeonQuestEnd.int`. Это **кандидат**, а не доказанный набор необходимых test fixtures: actors, enemy, ledge, pickup, spell target и transition должны быть инвентаризированы export/runtime. `Adv1Willow` содержит tutorial/Willow/Ford особенности и менее удобна для первого обычного loop.

1. Dedicated world с отдельными HPCoopGame/HPCoopHarry и проверенным registry; обе pawn независимы, world story actor определён ещё до его первого использования.
2. Один enemy family, одна оригинальная spell interaction, один конкретный trigger и pickup — server результат один раз, виден обоим. Остальные enemy adapters не объявлять завершёнными.
3. Один cutscene с возвратом обоих camera/input/HUD и единственными world changes.
4. Один подтверждённый ServerTravel с сохранением canonical state **до** native screening следующей карты.
5. Single death, dual death/checkpoint recovery, late join и reconnect. После этого несколько последовательных карт.

Обязательные логи: session generation, slot/PRI/pawn identity, StoryLeader, CurrentGameState до/после travel, source+destination map, trigger/cutscene sequence id, camera owner, AI old/new target/reason, damage victim/instigator, checkpoint generation. Логировать переходы/ошибки; Tick spam только с debug flag.

## Неподтверждённое и условия завершения

Этот аудит не запускал UCC, dedicated/client runtime и тест на двух физических ПК. Native map screening и save serialization — явные внешние границы доказательства. Включённый реестр является исчерпывающим lexical inventory, но **не завершённым campaign-wide semantic audit**. Глубокая доработка Versus до перечисленных coop gates не требуется.
