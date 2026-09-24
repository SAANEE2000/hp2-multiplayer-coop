# HP2 Versus FFA: аудит spell selector, HUD и ручного стенда

Дата: 2026-09-25. База: known-good Versus FFA после принятого Alt Free Look,
commit `24259b4`.

## Что проверено до реализации

- В `Core.Object.EInputKey` существуют реальные enum-имена `IK_NumPad1` …
  `IK_NumPad6`; в INI/bind-механизме движка им соответствуют `NumPad1` …
  `NumPad6`.
- Основной цифровой ряд сохраняет stock duel bindings и не используется новым
  selector.
- Серверная таблица уже сопоставляет слоты 0–5 классам Rictusempra,
  Mimblewimble, Expelliarmus, Flipendo, Alohomora и Spongify.
- Палочка повторно проверяет все шесть классов whitelist до authoritative
  projectile spawn.
- Alohomora и Spongify возвращают `False` из player-hit ветки и передают
  world-hit штатным `HandleSpellAlohomora`/`HandleSpellSpongify`; искусственный
  PvP damage им не добавлялся.
- Flipendo сохраняет две ветки: player damage/push и stock
  `HandleSpellFlipendo` для world actor.

## Реализация

`Launch-Multiplayer.ps1` добавляет только шесть временных bind’ов цифрового
блока. `HPVersusHarry.VersusSelectSpell` немедленно обновляет локальный слот и
visual spell палочки, затем отправляет выбор серверу. Сервер по-прежнему
проверяет диапазон, получает class из собственной таблицы и не доверяет
клиентскому class.

Существующий `HPVersusHUD` расширен без замены HUD-класса. Он использует родные
HP2 duel icons для первых трёх заклинаний и stock spell-shape textures для
Flipendo/Alohomora/Spongify. Добавлены health bar, `67 / 100`, выбранное
заклинание, точный cooldown до сотых и компактные mute/disarm/speed состояния.
F3 scoreboard оставлен прежним. Загрузка текстур выполняется один раз на HUD;
отсутствующий optional asset не провоцирует повторный DynamicLoad каждый кадр.

Стенд находится в `Maps\HPV_Interactions.unr`. Это byte-for-byte копия
принятого `startup.unr`; бинарная рабочая карта не редактировалась. Только для
этого map name authority создаёт stock-derived Padlock, отдельные Alohomora и
Flipendo spellTrigger, BronzeCauldron, SpongifyPad/SpongifyTarget и
существующие Versus pickups.

## Исправления после ручного прогона

Первый ручной прогон обнаружил два дефекта, которые не покрывал прежний
структурный audit персонажей.

1. Подключение второго игрока переводило матч из `Countdown` в `InProgress`.
   `BeginVersusMatch()` делал обязательный перенос игроков на старт, а затем
   `ClientVersusRespawn()` вызывал жёсткий `ForceStandardCam()`. Из-за этого
   камера сбрасывалась к yaw/pitch `PlayerStart`, хотя удалённый pawn сам камеру
   не перехватывал. Теперь сервер сохраняет `Rotation`, `DesiredRotation` и
   `ViewRotation` живого игрока на переходе `Countdown -> InProgress`, а клиент
   сохраняет уже работающую орбиту через `ApplyStandardCam()`. Обычный respawn
   после смерти и новый раунд после `MatchOver` сохраняют полный reset.
2. Новые косметические меши были связаны с `skHarryAnims`, но stock
   `GetCurrIdleAnimName()` случайно выбирал `idle_1`/fidget. Последовательность
   формально существовала, однако на части связанного ростера визуально давала
   reference/T-pose. Для всех профилей с `ANIM_LINK_HARRY` idle и fidget теперь
   используют совместимую общую последовательность `Idle`; бег, strafe,
   прыжок, каст и cloak channels не менялись.

Runtime-журнал после исправления подтверждает сохранение фактического viewport:
до старта матча `Cam.Rotation=494,14453,0`, после переноса на spawn и setup —
те же `494,14453,0`; `Cam.PlayerHarry`, `ViewTarget` и локальный pawn не
сменились. У удалённого `skhp2_genmale1Mesh` опубликован `AnimSequence=Idle` с
растущим `AnimFrame`, тогда как дефектный прогон публиковал `idle_1`.

## Проверки

- UnrealScript build `20260925-014441-810`: 0 errors, 276 warnings.
- `HGame.u` SHA-256:
  `3F87CFA156730C7F28EEAFC92C9C1D2F2832607A15D59CDCD06F3767CAE31233`.
- `M212Share.u` SHA-256:
  `2A366B19803F7B2E5762B8BBB2A9B1A839ABFD4F1E2B05E40A8A0DE5C969758E`.
- Полный репозиторный набор: 54 PASS, 1 SKIP. SKIP относится только к
  невозможности создать тестовый symlink без Windows privilege;
  функциональный тест не падал.
- Runtime: dedicated server и несколько клиентских подключений; переход
  countdown, перенос на spawn, стабильная камера и remote `Idle` подтверждены
  по клиентскому и серверному журналам.
- Два сгенерированных клиентских `User.ini` содержали точные bind’ы
  `NumPad1=VersusSpell1` … `NumPad6=VersusSpell6`.
- Отдельная карта `HPV_Interactions.unr` подготовлена из принятого
  `startup.unr`; рабочий `startup.unr` не изменён.

## Статус приёмки

Сборка, статические контракты и runtime-проверка camera/idle готовы. Полный
визуальный spell-by-spell прогон, внешний вид HUD, projectile/FX/result и
финальная визуальная проверка отсутствия T-позы остаются
`PENDING USER MANUAL TEST`, как и требовалось в задаче.
