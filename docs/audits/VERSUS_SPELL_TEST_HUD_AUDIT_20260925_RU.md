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
этого map name authority создаёт stock-derived Padlock, BronzeCauldron,
spellTrigger, SpongifyPad/SpongifyTarget и существующие Versus pickups.

## Проверки

- UnrealScript build `20260925-010921-199`: 0 errors, 276 warnings.
- `HGame.u` SHA-256:
  `CD580BF519BE337D1591F759873BCE2E8F51445E4BF73C6BBDC6CF086E7A5A1F`.
- `M212Share.u` SHA-256:
  `2432AC09F89554B64940CD140153B903E7580523ED3361F7812254EAD3D1A57C`.
- Контрактный набор selector/HUD/free-look/patch recipes: 31 PASS, 1 SKIP.
  SKIP относится только к невозможности создать тестовый symlink без Windows
  privilege; функциональный тест не падал.
- Полный репозиторный набор: 50 PASS, тот же 1 SKIP.
- Два сгенерированных клиентских `User.ini` содержали точные bind’ы
  `NumPad1=VersusSpell1` … `NumPad6=VersusSpell6`.
- В текущем окружении новый engine log становился доступен только после
  штатного закрытия окна; Computer Use не вернул список native apps, поэтому
  этот прогон не используется как визуальный PASS. Ранее принятые server probes
  interaction arena остаются зелёными, но ручной spell-by-spell тест обязателен.

## Статус приёмки

Сборка и статические/серверные контракты готовы. Визуальное отображение нового
HUD, ввод Numpad и видимость projectile/FX/result на втором клиенте имеют статус
`PENDING USER MANUAL TEST`, как и требовалось в задаче.
