# Versus FFA: перенос пригодных механик из v18

Дата: 2026-09-24. Целевая линия: текущая Versus-ветка на базе v16,
2–8 игроков, `startup.unr`, Native movement, Harry/Ron/Hermione,
server-authoritative damage, death/respawn и HUD.

Полный donor-аудит находится в
`docs/audits/V18_VERSUS_DONOR_AUDIT_20260924_RU.md`. v18 использовался
только как источник идей, классов частиц и исходных чисел. Его GameInfo,
Harry, wand и связанные HideSeek/Hagrid-эксперименты целиком не
переносились.

## Итоговый объём

### Боевые заклинания

В FFA доступны четыре фиксированных server-side слота:

| Клавиша | Заклинание | Урон при заряде 0–100% | Cooldown | Дополнительный эффект |
|---|---|---:|---:|---|
| 1 | Rictusempra | 5–15 | 0.35 с | нет |
| 2 | Mimblewimble | 3–8 | 0.70 с | запрет каста на 0.75–1.50 с |
| 3 | Expelliarmus | 8–20 | 1.00 с | нет; shield-эксперимент v18 исключён |
| 4 | Flipendo | 2–8 | 0.60 с | server-side push, сила 600, подъём 210 |

`HPVersusHarry` и `HPVersusWand` используют один и тот же фиксированный
whitelist. Клиент выбирает только номер слота и запрашивает выстрел; сервер
повторно проверяет слот, mute, cooldown, направление и создаёт снаряд. Урон и
импульс применяются только сервером. Эффект заряда берётся из выбранного
класса заклинания. Alohomora и Spongify явно оставлены недоступными для FFA:
в donor они не имеют готового воздействия на игроков.

Максимальное здоровье не менялось: `Health=100`. Баланс атак задан только
уроном и cooldown.

### Пикапы

`HPVersusGame` создаёт вокруг центра восьми `HPVersusStart` два лечебных
пикапа и один speed pickup. Для текущего `startup.unr` вычисленный центр:
`(0.25, 0, 115.875)`. Лечение расположено по X `-120/+120`, ускорение — по
Y `+150` относительно центра.

`HPVersusHealthPickup`:

- лечит на 25;
- использует `Min(100, Health + 25)`;
- не срабатывает при полном HP, смерти или вне активного матча;
- после подбора скрывается, отключает collision и возвращается через 30 с;
- actor не уничтожается, поэтому устранена ошибка donor-кода, где respawn
  после `Destroy()` был невозможен.

`HPVersusSpeedPickup`:

- множитель 1.5 на 10 с;
- выдаётся и завершается сервером;
- при фактическом подборе сохраняет текущие `GroundSpeed`, `GroundRunSpeed`
  и резервную direct-movement скорость, применяет множитель и затем
  восстанавливает ровно сохранённые значения;
- сбрасывается по гарантированному `HPVersusGame.Timer`, а также при смерти,
  respawn и начале нового матча;
- состояние и момент окончания синхронизируются владельцу для HUD;
- сам pickup возвращается через 30 с.

### HUD и сброс состояния

HUD показывает `HP current/100`, выбранное заклинание, `READY/COOLDOWN`,
остаток Mimblewimble mute и множитель/остаток speed buff. Временное состояние
обнуляется единым методом при первичной настройке игрока, смерти, respawn и
новом раунде. Это исключает перенос ускорения, mute или cooldown между
жизнями и матчами.

### Совместимость с текущей веткой

Сохранены текущие 2–8 FFA, character select, Native movement, анимационные
каналы Harry/Ron/Hermione, плащи, камера, resizable window, score/death/
respawn. После обнаруженной регрессии `HPVersusHarry` повторно собран строго
от результата закоммиченного `versus-v16-player-animations` с SHA-256
`4340c8185a4d01fdb8321cd463afe22f2245bbfb48b7704b15da1d756a2baf1e`.
Функции `SetupVersusPlayer`, `Tick`, `PlayerInput`, Native/direct movement,
выбора анимаций, прыжка и cloak channels совпадают с этой Git-версией
побайтно. Обычный spawn/setup больше не вызывает reset скорости и не меняет
параметры движения.

Для завершения каста добавлено одно локальное Versus-переопределение
`StopAiming`. В исходном порядке `cHarryAnimChannel.stateIdle` немедленно
вызывал `PlayIdle` ещё при старом `HarryAnimType=AT_Combine`, а
`AT_Replace` назначался после входа в state. Из-за этого верхний слой мог
сохранять последнюю позу руки до следующей locomotion-анимации. Теперь
`AT_Replace` задаётся до перехода канала в `stateIdle`; movement-функции и
скелетные каналы при этом не изменены.

`HPVersusDirector.OnTakeDamage` отключает только одиночный callback,
который обращался к отсутствующему `Director.PlayerHarry`; серверный damage
FFA продолжает проходить через `HPVersusHarry.TakeDamage`.

Из v18 не перенесены HideSeek, Hagrid-player, shield-only Expelliarmus,
случайный Mimblewimble, Alohomora/Spongify для одиночных объектов и
увеличение max HP.

## Воспроизводимость

Новые самостоятельные классы находятся в
`mod/versus-v16/HGame/Classes`. Узкие изменения существующих v16-классов
описаны хешированной цепочкой
`patches/versus-v16-v18-donor-mechanics.json`. `HPVersusHUD` является
репозиторным overlay-файлом и не зависит от наличия этого класса в donor ZIP.

В `scripts/Launch-Multiplayer.ps1` добавлен закрытый диагностический флаг
`-VersusMechanicsProbe`. Он разрешён только для Versus Host и по умолчанию
выключен. Этот сценарий намеренно наносит урон, применяет импульс, убивает,
респавнит игроков и начинает новый матч, поэтому его нельзя использовать как
обычный ручной матч.

## Проверки

- UCC build: `Success - 0 error(s), 273 warnings`; build log
  `.local/builds/20260924-015301-531/ucc-output.log`.
- Хешированные patch recipes: чистое применение, частичное применение,
  повторное применение и защита от повреждения входов проходят.
- Два реальных `Game.exe` клиента `CertHarry` и `CertHermione` подключены к
  dedicated `UCC.exe` серверу, порт 7798. Итоговый журнал:
  `.local/runs/versus-host-20260924-015726-535-8bbb41/server-stdout.log`.
- Чистый матч без probe: `CleanHarry` и `CleanRon`, успешный join, Native
  movement на сервере, probe отключён.
- Автоматический двухклиентный сценарий проверяет whitelist, отдельные
  cooldown, лечение, pickup respawn, ускорение, expiry, Mimblewimble mute,
  Expelliarmus damage, Flipendo damage/push, death reset, clean respawn и
  new-match reset. Все 12 проверок завершились `PASS`, затем
  `HPVersusMechanicsProbe COMPLETE`; `FAIL`, `Critical`, `ScriptWarning`,
  `HPVersusSpellSpawn FAILED` и `HPVersusCastReject` отсутствуют.

Передаваемый бинарный комплект:
`.local/distribution/hp2-test-build-20260924-015907-116-017c9c11.zip`,
SHA-256
`1bc31a61a200c6943ee282413faab8f5b68bf30d071b0f057021e868cea9e998`.
Внутри `HGame.u`, `M212Share.u`, compile log и manifest; оригинальные файлы
игры и карта в комплект не входят.

Готовый комплект для установки другу:
`.local/distribution/hp2-versus-v18-mechanics-FULL-TEST-11d11e2.zip`,
SHA-256
`9a208342412a5930e01724e8a48e00fe4b8917525c6be9bf75309a8ca513c5f4`.
Он содержит исходники коммита `11d11e2`, donor v16, проверенный бинарный
комплект и `startup.unr`. Внутренний binary ZIP дополнительно прошёл
`Import-TestBuild.ps1 -ValidateOnly`.

Известные шесть `Accessed None` при создании legacy `harry`/
`HPVersusHarry` происходят в исходном `harry.PreBeginPlay` до привязки
сетевого Player. Flipendo probe дополнительно воспроизводит три прежних
предупреждения исходного `harry`: один `PlayLandedSound` с пустым
`HearHarryRecipient` и два `StopSpongifyEffects` с пустыми элементами FX.
Исправление этих глобальных animation/landing-функций намеренно не включено,
чтобы сохранить закоммиченную рабочую ветку управления и скелета без новых
изменений. Предупреждения не мешают завершению probe или respawn.
