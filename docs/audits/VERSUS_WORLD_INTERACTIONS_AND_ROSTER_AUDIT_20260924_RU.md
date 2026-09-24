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

## Этап 4: централизованные character profiles

Добавлен `HPVersusCharacterProfiles`: один табличный registry содержит `Id`, display/group, mesh, DrawScale, animation strategy, cloak strategy, wand bone, visual offset, прозрачность, generic-student skins, selectable-флаг и статус аудита. `HPVersusPRI.SetSelectedCharacter` валидирует Id через registry; `HPVersusHarry.ApplyCharacterSkin` больше не содержит цепочку специальных веток. Все варианты остаются `HPVersusHarry`, получают `skHarryAnims` только как presentation animation set и сохраняют единую gameplay-капсулу `15x42`, 100 HP, скорость, прыжок, damage и cooldown.

NPC AI-классы, ghost physics/no-collision и HagridPlayer не используются. Myrtle/Nick сохраняют только косметическую прозрачность; collision и hit registration остаются обычными PvP. Generic Gryffindor/Slytherin используют штатные duel meshes и stock texture sets.

### Матрица совместимости

Автопроверка для каждого профиля проверяет spawn/mesh, `Bip01 R Hand`, общую капсулу, idle, run, runback, strafe L/R, jump, fall, land, cast/aim и `faint` death. Stock `harry.PlayHit()` пустой, поэтому выдуманная обязательная последовательность `hit` не используется: получение урона проверяется общим combat probe, смерть — `faint`.

| Группа | Профиль | Статус | Результат |
|---|---|---|---|
| Gryffindor | Harry | PASS | Контрольный stock mesh |
| Gryffindor | Ron | PASS | Player mesh + Harry body set + male cloak channels |
| Gryffindor | Hermione | PASS | Player mesh + Harry body set + female cloak channels |
| Gryffindor | Ginny | PASS | Полный набор, wand bone 54, female cloak roots 89/120 |
| Gryffindor | Fred, George, Percy, Oliver Wood | NEEDS EXTRA CHANNEL | Тело/cast/death/wand работают; совместимых `~Cloak01/02` нет |
| Gryffindor | Generic student M/F | PASS | Полный набор, stock duel mesh/skins и generic cloak channels |
| Slytherin | Draco, Crabbe | PASS | Полный набор и male cloak roots 78/109 |
| Slytherin | Goyle, Prefect, Tom Riddle | NEEDS EXTRA CHANNEL | Тело/cast/death/wand работают; отдельная мантия не подтверждена |
| Slytherin | Generic student M/F | PASS | Полный набор, stock duel mesh/skins и generic cloak channels |
| Adults | Snape, Lockhart, Dumbledore, McGonagall, Lucius | NEEDS EXTRA CHANNEL | Основной humanoid rig, wand и полный body set проходят; robe channel отсутствует |
| Adults | Hagrid | NEEDS VISUAL FIX | Полный body set, wand bone 55, stock DrawScale 1.25 и общая capsule; нужен ручной camera/floor/wand кадр |
| Fun | Dobby | NEEDS VISUAL FIX | Полный body set, wand bone 74 и общая capsule; нужен ручной кадр малого mesh |
| Fun | Moaning Myrtle, Nearly Headless Nick | NEEDS VISUAL FIX | Полный body set, wand и обычная PvP collision; прозрачность косметическая, нужен remote-render кадр |
| Fun | Bloody Baron | BLOCKED | В mesh нет стандартной humanoid-ветки: не найдены hand, forearm, finger, spine или их проверенные варианты; выбор отключён |

`NEEDS EXTRA CHANNEL` профили остаются выбираемыми: движение, бой и смерть у них доказаны, ограничение относится только к независимому движению части мантии/одежды. `NEEDS VISUAL FIX` также оставлены в меню для теста, но не объявлены визуально законченными.

### Меню и persistence

Меню выбора теперь двухступенчатое: `Гриффиндор / Слизерин / Взрослые / Особые` → character. Одинаковые профили не запрещены. Bloody Baron виден как `BLOCKED`, но его кнопка отключена. Profile Id передаётся в join URL, проверяется сервером, реплицируется в PRI и уже используется F3 scoreboard.

`Show-MenuTest.ps1 -SelfTest` проходит навигацию, расширенный выбор Snape и проверяет, что Bloody Baron нельзя нажать. Два новых mechanics checks подтвердили сохранение Id и mesh после death/respawn и нового матча.

### Финальная автоматическая проверка этапа

Сборка `20260924-232803-901`: `Success - 0 error(s), 276 warnings`. Финальный dedicated-прогон `versus-host-20260924-232841-094-b4e464` использовал два настоящих `Game.exe` (`PersistHagrid` и `PersistDobby`) и завершился без `FAIL`:

- 16/16 combat/pickup/death/respawn/match/profile-persistence checks;
- 7/7 Alohomora/Flipendo/Spongify world checks; Spongify endpoint delta `0.031860`;
- 27/27 profile records: 10 `PASS`, 12 `NEEDS EXTRA CHANNEL`, 4 `NEEDS VISUAL FIX`, 1 `BLOCKED`.

Отдельный шестиклиентный запуск `versus-host-20260924-231612-680-5dbbda` подтвердил реальные подключения Snape, Hagrid, Dobby и Moaning Myrtle наряду с двумя контрольными клиентами; у каждого сервер увидел правильный mesh, полный набор animations, wand bone и capsule `15x42`.

Инструмент Windows Computer Use дважды вернул пустой список приложений, хотя четыре `Game.exe` отвечали и имели ненулевые window handles. Поэтому я не выдаю структурный server audit за визуальное подтверждение. Ручной визуальный checklist остаётся для Hagrid/Dobby/ghosts и для одежных каналов со статусом `NEEDS`; это конкретное ограничение текущего прогона, а не скрытый PASS.

Экспортирован приватный бинарный payload `hp2-test-build-20260924-233148-815-6b52f8cc.zip`, SHA-256 `be345065756e157085a5322dc71692a9197ea3d2d5320a44fa50fcbec5862b13`. Он содержит только собранные `HGame.u`, `M212Share.u`, manifest и compile log; публичный Git по-прежнему не распространяет игровые assets. `Setup-VersusTestKit.ps1` обновлён на этот точный hash.
