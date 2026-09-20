# Canonical Harry disconnect во время CutScript — 20 сентября 2026

**Обычная смена StoryLeader не обеспечивает продолжение активной сцены.** Ссылки CutScript, его pending cues, движение pawn, камера и вспомогательные controllers образуют отдельное состояние. Универсального безопасного переноса этого состояния через текущий Game.Logout не найдено. Этот аудит read-only: Game/Harry, scene interpreter, engine DLL и runtime не изменялись.

Все ссылки исходников Engine/HGame ниже относятся к ignored `.local/game`. Для mod указан полный относительный путь. Номера строк фиксируют изученную development copy; последующие recipe overlays могут их сдвигать.

## Почему нельзя сохранить отключившийся pawn из Logout

В `Engine/Classes/Pawn.uc:1105–1141` событие Destroyed сначала уничтожает breath/shadow, вызывает RemovePawn, уничтожает inventory и очищает Weapon/Inventory. Только затем при bIsPlayer вызывает `Level.Game.Logout(self)` (1127–1128). После Logout уничтожаются PlayerReplicationInfo и FacialAnimChannel, другим pawn сообщается Killed. `PlayerPawn.uc:1235` вызывает этот Super.Destroyed перед удалением HUD и saved moves.

Порядок подтверждён в установленном x64 `Engine.dll`, SHA-256 `e7bd8f53aa1bce2386ba8943fdfc4d4c54c0a27948f49bc0de53dee22cc82391`. Использовались только чтение PE exports/vtable и дизассемблирование, без исполнения/патча DLL.

| Native этап | RVA |
| --- | --- |
| UNetConnection.Destroy вызывает UPlayer.Destroy | `0x128F15` |
| UPlayer.Destroy очищает pawn.Player | `0xEDB88` |
| UPlayer.Destroy вызывает ULevel.DestroyActor | `0xEDBB1`, virtual slot `+0x168` |
| ULevel.DestroyActor dispatch Destroyed | `0xA5647` |
| После Destroyed продолжается cleanup actors/owners/tick parents | `0xA5649` и далее |
| Удаление из level actor array, установка bDeleteMe | `0xA5813–0xA5817` |

Virtual slot проверен по exported ULevel UObject vtable (RVA `0x1AB0E0`): `+0x168` действительно указывает на DestroyActor (`0xA5380`). Начальные native ограничения bStatic/bNoDelete проверяются раньше Destroyed. Изменение bIsPlayer, Owner, CutName или вызов другого GotoState из Logout не отменяет уже начатое уничтожение. Отказ вызывать Super.Destroyed также не отменит native cleanup и дополнительно потеряет обязательную очистку.

`Engine/Classes/Player.uc:17` объявляет Player.Actor как transient const PlayerPawn. В доступном UnrealScript API не найден supported pre-disconnect veto/reparent hook, позволяющий освободить connection от pawn до UPlayer.Destroy. Не использовать изменение const через текстовое свойство или глобальный bNoDelete как обход. В UPlayer.Destroy есть отдельные legacy режимы viewport; они не являются контрактом сохранения сетевого co-op pawn.

Следовательно, вариант «сохранить уходящего canonical pawn временно на сервере» требует native lifecycle расширения либо иной архитектуры **до** начала сцены. Его нельзя реализовать безопасной небольшой вставкой в текущий Logout. Server-only canonical actor, заранее независимый от UPlayer, — отдельный возможный дизайн, но он должен с самого начала владеть сценой; создание replacement в Logout не переносит уже исполняющийся latent action.

## Что остаётся у сцены после смены Level alias

| Объект/поле | Семантика и риск |
| --- | --- |
| `CutScript.aCapturedActors`, `Actor.CutNotifyActor`, `sCutNotifyCue` | CaptureActor (`CutScript.uc:83–137`) вызывает CAPTURE, затем сохраняет двустороннюю связь. ReleaseActor (`178–207`) ищет actor по CutName. После удаления Harry capture entry не становится автоматически новым Harry; pending cue от старого может никогда не прийти. |
| `CutScript.CutQuestionActor` | Play сохраняет текущий Level.PlayerHarryActor (`1750–1756`); поздняя смена Level alias эту ссылку не меняет. |
| ScriptLayers, command cursor, nPendingCues/aPendingCues, aCues, aErrorCues | Это прогресс интерпретатора. `Running.Tick:1817` читает следующую команду только при нуле pending cues. Нельзя обнулять pending или подделывать CutCue, чтобы «разблокировать» сцену. |
| TimedCue | Script Sleep (`851–868`) создаёт timer с CutNotifyActor=script: он не нуждается в смене владельца. Actor Say (`Actor.uc:1592,1663`) создаёт timer с CutNotifyActor=говорящий actor: его получатель может исчезнуть. `TimedCue.Timer:5–13` выдаёт cue и уничтожается. |
| Pawn movement/animation/spline | WalkTo/RunTo (`Pawn.uc:4096–4167`) запускает `stateMovingToLoc`, хранит путь, индекс и sCutNotifyCue. `stateMovingToLoc:2788` содержит latent MoveTo; `stateTurningTo:3128` — latent TurnToward; animation/spline имеют собственное состояние. Копирование имени state через GotoState не переносит latent instruction pointer и native movement state. |
| TurnToController/SplineManager | TurnToController обращается к Pawn(Owner).TurnTo_TargetActor каждый Tick (`TurnToController.uc:8–11`). SplineManager хранится в Pawn и управляется отдельно (`Pawn.uc:3166`). Рутинное удаление controllers выдаёт другое поведение, чем завершение исходной команды. |
| BaseCam и CamTarget | `FindCutSubject("baseCam")` каждый раз возвращает **текущий** `harry(Level.PlayerHarryActor).Cam` (`CutScript.uc:217–221`), а текущая камера, captured references, CutNotifyActor и fly state могут остаться прежними. Новые команды и текущая анимация тогда направляются в разные камеры. |
| CamTarget.aAttachedTo, TickParent; HPawn.aFlyToActor | CamTarget.TickParent следует attached actor (`BaseCamTarget.uc:43–45`), FlyToController.GetVDest использует aFlyToActor (`HiddenHPawn/FlyToController.uc:84–101`). Native destroy очищает некоторые tick/owner связи, но не выполняет смысловую замену target новым лидером. |
| HPawn._FlyToController | Контроллер сохраняет и Owner, и отдельный cached HPawn H (`FlyToController.uc:7–22`), время/траектория лежат в H. Одного SetOwner недостаточно. HPawn.Destroyed уничтожает _FlyToController (`HPawn.uc:157–171`). Harry непосредственно extends PlayerPawn; этот пункт относится к BaseCam/HPawn, а не к Harry как HPawn. |
| FOVController / FadeViewController | Оба extends Actor и кешируют harry PlayerHarry (`Misc/FOVController.uc:16,49`; `Misc/FadeViewController.uc:12,17`). Текущий обход HPawn/Director в AdoptStoryLeader их не охватывает. Их elapsed time/исходные значения нельзя инициализировать заново. |
| Shared presentation | `mod/HGame/Classes/HPCoopCutsceneView.uc` сохраняет SourceCamera и SourceCanonical. Смена StoryLeader не перепривязывает их автоматически. Повторный SetStoryCaptured(True) сейчас может завершиться early return, так как capture flag уже True. |

`CutScript.ReCaptureActor` не выполняет нового CAPTURE, но только добавляет найденный actor в capture array и меняет CutNotifyActor (`141–174`); он не переносит movement/timers/camera и не является complete handoff. Обычный CAPTURE/RELEASE имеет глобальные эффекты: Characters.OnHarryCaptured, HUD, SendPlayerCaptureMessages и destruction controllers (`harry.uc:5498–5537`). Поэтому повторять их при технической смене лидера нельзя.

## Минимальное безопасное поведение сейчас

При disconnect текущего canonical во время активной сцены следует **зафиксировать recovery-required и остановить её продвижение**, сохранив причину и диагностику. Это честный отказ от недоказанного resume, а не успешное завершение сцены. Нет основания автоматически выдавать reward, BeginChallenge, Release, game-state change или следующую карту.

1. Проверять canonical participation по всем live CutScript: capture array, CutQuestionActor, notify chain и текущая canonical camera; одного bStoryCaptured недостаточно для асинхронных/вложенных скриптов. При неполной классификации выбирать остановку.
2. Установить session recovery latch, который имеет приоритет над RefreshSession/SetPause/new player ready. Сохранить last valid shared camera snapshot. Пауза только CutScript.Tick недостаточна: TimedCue, camera controllers, NPC и triggers продолжают работать. Нужна проверенная остановка world time; native pause semantics для timers/network ещё должна пройти отдельный runtime gate.
3. Не вызывать Play, FastForward, CutBypass, Release или Timer вручную. `Play` добавляет MAIN layer снова; `FastForward:1765–1785` напрямую вызывает timers/Bypass; `Pause` переводит в Idle, а повторный Running.BeginState сбрасывает часть script flags. Даже Pause→Play не является resume.
4. После уничтожения старого pawn автоматический resume не обещать. Recovery следует выполнять через явно поддержанный checkpoint/reload с учётом отдельного save/travel контракта. Перезаход клиента сам по себе не восстанавливает latent state. В acceptance report такой запуск остаётся DISCONNECT_RECOVERY_REQUIRED, а не PASS.

Это рекомендация для следующей небольшой правки root, а не уже реализованный recovery механизм. Обычный disconnect вне сцены и новый successor требуют собственного smoke gate, отдельно от active scene recovery.

## Возможный ограниченный перенос на спокойной границе

Для первого seamless handoff можно поддержать **явно проверяемое подмножество**, например scene sleep, когда canonical Harry находится в известном cut-idle состоянии и не исполняет асинхронную команду. Проверка только `nPendingCues==0` или пустого Harry.sCutNotifyCue недостаточна: commands с `*` и looping actions могут идти без pending cue. Нужны command tracking либо полный whitelist известных безопасных состояний/controllers.

До любых изменений preflight должен подтвердить живого зарегистрированного successor, доступный текущий script/camera, отсутствие Harry-owned timers, movement/animation/spline/turn/follow actions и неизвестных callbacks. Для первой версии отказывать также при FOV/fade или actor attachment, направленных на Harry, вместо попытки универсального клонирования.

Если весь preflight пройден, в одном authority callback без выдачи scene commands:

1. Сохранить прежнюю **server BaseCam** и CamTarget как те же объекты; новый canonical.Cam должен указывать на эту камеру. Не создавать/инициализировать новую камеру посередине её траектории. Обновить только известные ссылки на прежнего Harry, включая CamTarget attachment/aFlyToActor и presentation SourceCanonical. Не затрагивать client LocalCoopCamera.
2. Заменить exact old actor entries в existing aCapturedActors, CutQuestionActor и строго связанные actor fields; перенести CutNotifyActor, capture flags/counters, canonical CutName и нужное story state в successor. Прежнему обнулить только переданные ссылки, не вызывать Release. Все независимые участники/scene ownership остаются прежними.
3. Сохранить script object, layers/cursor, cue queues, parentCutScene threads, existing script-owned timers и camera elapsed time. Обновить shared view sources без нового SceneSerial и без повторного capture broadcast.
4. Повторно проверить, что ни одна поддерживаемая ссылка не указывает на уничтожаемого Harry, затем продолжить тот же interpreter. Любая неизвестная связь ведёт в recovery-required; не пытаться «доделать» текущую команду вручную.

Такой механизм всё ещё требует собственного UCC/runtime доказательства. Для произвольного mid-WalkTo/Say/Animate transfer этого whitelist недостаточно. Он не должен называться полноценной поддержкой disconnect во всех сценах.

## Проверки для принятия реализации

- Disconnect canonical отдельно в Sleep, Say/Talk, WalkTo/TurnTo, Animate, BaseCam fly/attached target, FOV/fade, вложенном/параллельном CutScript; disconnect companion как контроль.
- Проверить без повторного Trigger/Play/BeginChallenge: один scene serial, неизменённый cursor, exactly-once естественные cues/rewards и один конечный Release. Проверять события по логу, не только исчезновение letterbox.
- Для неподдержанного состояния: сцена/world не продвигается, камера остаётся валидной, награда/state/карта не меняются, new join не снимает recovery latch.
- Для разрешённого спокойного переноса: server camera и timers остаются теми же actor, old actor references отсутствуют, оба клиента получают правильное capture/release, successor жив и может продолжить после сцены.
- Стресс: одновременный последний logout, disconnected pawn без Player уже внутри Destroyed, successor умер/отключается в тот же кадр, потеря соединения во время fade/Travel. Не считать проверку одного normal capture/release доказательством этих сценариев.

Локальные вспомогательные дизассемблирования: `.local/engine-UPlayerDestroy-disassembly.txt`, `.local/engine-NetConnectionDestroyTail-disassembly.txt`, `.local/engine-DestroyActor-disassembly.txt`; proprietary binary/source bytes не добавлялись в Git.
