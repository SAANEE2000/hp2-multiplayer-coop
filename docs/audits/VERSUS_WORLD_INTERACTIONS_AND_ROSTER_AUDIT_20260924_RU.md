# HP2 Versus FFA: аудит world interactions и ростера

Дата: 2026-09-24. База: рабочая цепочка v16 после `11d11e2`; последующие коммиты меняли только отчёт/упаковку. v18 рассмотрен исключительно как donor/reference.

## Найденная штатная цепочка заклинаний

| Механика | Stock/v16 | v18 | Решение для Versus |
|---|---|---|---|
| Alohomora | `spellAlohomora.OnSpellHitHPawn -> HPawn.HandleSpellAlohomora`; `HAlohomora` вызывает `TriggerEvent` и уничтожается; `Padlock` наследует этот путь; `spellTrigger.Touch` фильтрует `SpellType` | `HPVersusAlohomora` дублирует большой projectile-код | Оставить штатные callbacks. Новый тонкий authoritative projectile не наносит PvP damage и передаёт попадание в `HandleSpellAlohomora`; `spellTrigger` получает оригинальный `Touch` |
| Flipendo | `spellFlipendo.OnSpellHitHPawn -> HPawn.HandleSpellFlipendo`; `Boulder`, `HChar`, `GenericSpawner` и другие классы имеют собственные state machine; `spellTrigger` фильтрует `SPELL_Flipendo` | Versus-вариант сохранил только PvP damage/push | Сохранить принятую PvP-ветку и добавить отдельную ветку для любого не-player `HPawn`, вызывающую его штатный `HandleSpellFlipendo` |
| Expelliarmus | В дуэли Duellist заряжает `spellDuelExpelliarmus` при приближении летящего заклинания и переходит в `stateDefence`; сам hit-handler возвращает `False`. Это защитное окно, а не обычный damage bolt | Эксперимент v18 смешивал damage и shield state | Убрать damage. Успешное попадание серверно срывает текущую зарядку и даёт короткий disarm/cast lock; Mimblewimble остаётся более долгим mute с damage |
| Spongify | `HandleSpellSpongify -> SpongifyPad.stateGoingToEnabled -> stateEnabled`; `harry.Landed` запоминает pad, затем `OnBounce` вычисляет траекторию к `SpongifyTarget` | Versus donor вызывает `Trigger()` напрямую, что у штатного pad означает переход в disabled | Прямо не переносить. Отдельно адаптировать исходный `HandleSpellSpongify` и bounce transaction, не заменяя её вертикальным импульсом |

`baseSpell.ProcessTouch` уже различает `harry`, `HPawn` и `spellTrigger`. Поэтому новый слой не требует собственной универсальной interaction framework. Projectile существует на authority; не-simulated callbacks и map events исполняются на dedicated server.

## Риски donor-кода v18

- `HPVersusSpongify.TryActivateSpongifyTarget` вызывает `SpongifyPad.Trigger()`, но штатный `Trigger()` переводит pad в `stateDisabled`; это семантически обратный путь.
- v18 содержит повторённый projectile/FX boilerplate вместо наследования принятого `HPVersusSpell`.
- shield-поля Expelliarmus не следуют исходному дуэльному поведению и пересекаются с cast/cooldown state.
- Hagrid-player/HideSeek и AI-player классы не относятся к текущей архитектуре и не используются.

## Предварительный аудит ростера

Ростер будет представлен одним `HPVersusHarry` и replicated profile. До включения каждого профиля проверяются mesh/skeleton, полный locomotion/cast/hit/death набор, wand bone, robe/cloak channels, масштаб, floor/camera offsets и единая gameplay capsule. NPC AI-классы PlayerPawn-ами не становятся.

Статусы совместимости будут выставлены после инвентаризации пакетов и runtime smoke: `PASS`, `NEEDS EXTRA CHANNEL`, `NEEDS CUSTOM ANIM PROFILE`, `NEEDS VISUAL FIX`, `BLOCKED`. Harry/Ron/Hermione остаются принятой контрольной группой.

## Этап 1: реализация и проверка

Добавлены слот 5/Alohomora, серверный whitelist и HUD-имя; Flipendo направляет не-player `HPawn` в его исходный handler. Expelliarmus теперь не наносит урон: authority выставляет короткое окно disarm, owning client прекращает зарядку и возвращает wand animation в idle. Disarm очищается по таймеру, при смерти, respawn и начале нового матча.

Сборка `20260924-223337-044`: `Success - 0 error(s), 273 warnings`. Двухклиентный dedicated-прогон `versus-host-20260924-223436-370-87e338` завершил 12 проверок `HPVersusMechanicsProbe` без `FAIL`, включая `expelliarmus-disarm-without-damage`. Оба участника были настоящими `Game.exe`; server process — `UCC.exe`.

## Этап 2: Spongify transaction

Добавлен `HPVersusSpongify`, который вызывает исходный `HandleSpellSpongify`, и сетевой наследник `SpongifyPad`. Адаптер остаётся в отдельном нейтральном state, поскольку унаследованный `stateDisabled.HandleSpellSpongify` имеет более высокий приоритет, чем global override. Authority активирует pad, выбирает target и использует исходный `ComputeTrajectoryByTime`; owning client получает ту же стартовую скорость для presentation/prediction, а сервер остаётся источником physics и конечного положения. Обычный Native movement код не менялся.

Сборка `20260924-224242-182`: `Success - 0 error(s), 274 warnings`. Dedicated-прогон с двумя `Game.exe` `versus-host-20260924-224314-867-de51ab` завершил 14 проверок без `FAIL`. Дополнительные PASS: `spongify-authoritative-activation-and-bounce` и `death-clears-spongify`; весь прежний combat/pickup/respawn набор также прошёл.

## Этап 3: отдельная interaction arena

`startup.unr` не изменён. Скрипт `Prepare-VersusInteractionArena.ps1` создаёт его побайтовую копию `HPV_Interactions.unr`, а `HPVersusInteractionArena` добавляет тестовые объекты только при загрузке этой карты. Такой способ сохраняет принятую арену и делает fixture воспроизводимым без ручного редактирования бинарной карты.

На fixture размещены два штатных `Padlock`-пути Alohomora с health/speed pickup, штатный cauldron и `spellTrigger` для Flipendo, а также связка `SpongifyPad + SpongifyTarget`. Тонкие сетевые barrier-actors получают одноразовый server event и реплицируют открытое положение; сами spell callbacks остаются исходными HP2.

Сборка `20260924-225429-401`: `Success - 0 error(s), 276 warnings`. Dedicated-прогон `versus-host-20260924-225502-273-1527f2` использовал два настоящих клиента `Game.exe` (`ArenaA2/Harry` и `ArenaB2/Ron`). Сначала повторно прошли все 14 combat/pickup/respawn проверок, затем world probe завершился без `FAIL`:

- `alohomora-stock-lock-event-opens-door`;
- `flipendo-stock-object-state`;
- `flipendo-stock-spelltrigger-event`;
- `spongify-pad-active-owner-launched`;
- `spongify-server-endpoint` с отклонением `3.667526` от target по XY;
- `spongify-no-fall-damage`;
- `spongify-next-native-movement-ready`.

Серверный журнал подтверждает вход обоих клиентов и authoritative state transitions. В этом прогоне M212 не создал доступные отдельные client engine logs (`client-stdout.log` остался пустым), поэтому визуальное подтверждение remote-proxy в отчёте не подменяется автоматическим утверждением: оно остаётся пунктом ручного визуального прогона. Серверная репликация, endpoint и отсутствие регрессии Native movement проверены автоматически.
