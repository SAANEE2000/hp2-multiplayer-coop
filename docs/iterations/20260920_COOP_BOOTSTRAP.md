# Co-op bootstrap, оригинальные заклинания и локальный запуск

Commit: commit, содержащий этот отчёт; исходная точка `b4632d0`.
Branch: `coop`.

## Changed files / Why

- `HPCoopGame.uc`: ожидание двух готовых контекстов; Pause не обходит lobby;
  legacy health для alive selection; передача канонических ссылок при logout.
- `HPCoopHarry.uc`, новые `HPCoopWand.uc`/`HPCoopSpellVisual.uc`: отдельный
  inventory, native startup state, local-only ввод/HUD, authority spell boundary.
  Сохранена оригинальная классификация анимации ProcessMove. Пока нет принятого
  runtime spell/animation test.
- `coop-spell-caster.json`: Flipendo shove HChar использует caster в co-op,
  не заменяя постоянную AI-ссылку PlayerHarry. Последующая логика firecrab ещё
  использует canonical Harry.
- Четыре cmd launcher и `Launch-Multiplayer.ps1`: явный host:port, безопасная Entry
  staging map, стандартные co-op bindings, native `-NewWindow`, manifests/logs.
- `Build.ps1`: отдельный baseline WorkRoot, development profile и отказ менять
  пакеты запущенной тестовой игры. Byte-checked patch tests и texture cleanup.

## Build

PASS: `.local/builds/20260920-154831-033/ucc-output.log`, 0 errors / 268 warnings.
HGame и M212Share пересобраны после сохранения предыдущих пакетов.
Предыдущая тестировавшаяся runtime сборка: `20260920-153659-290`.
Последующие уточнения startup/paused prediction/cast validation/HChar ещё
нуждаются в повторном runtime тесте на последнем бинарнике.

## Automated / local tests

- 6 тестов patch recipes: PASS; отдельный HChar recipe fixture: hashes,
  idempotence, inverse byte identity, изменённый source rejection — PASS.
- Четыре launcher PrepareOnly и cmd через Windows PowerShell 5 — PASS.
- Build при работающем development Game — корректный отказ до замены пакетов.
- Texture/class cleanup: независимая проверка бинарных defaults — PASS;
  подробности в `20260920_COMPILE_CLEANUP.md`.
- Native loopback server/client startup — PASS в ограниченном смысле ниже.

## Confirmed working (только наблюдавшееся)

Сервер: `coop-host-20260920-153818-965-300695`, порт 7787, Ch1Rictusempra.
Клиенты: `coop-join-20260920-153819-213-ba943a` и
`coop-join-20260920-154435-091-cfefdf`. Серверный stdout содержит:

- две `Join succeeded`, два разных HPCoopHarry/HPCoopWand, slots 0/1;
- два `context-ready`, затем `session-ready players=2 ready=2`;
- один старт Ch1RictuIntro;
- logout slot 0 с leader=HPCoopHarry1;
- последний logout с leader=None и `waiting-for-players reason=empty-session`.

Первый клиентский журнал подтверждает свой BaseCam1 и readiness без повторения
`invalid state` или local Accessed None. Второй журнал потерял буфер при остановке;
его readiness подтверждён сервером, но отдельный визуальный PASS не выводится.

## Unconfirmed / known regressions

- Управление, remote visibility/animation, ledge, касты и gameplay не проверены
  визуально: UI capture tool возвращает ошибку владельца окна.
- Серверная intro работает, но HUD/Console отсутствуют у legacy команд. Companion
  ещё не получает общую cutscene presentation/input lock. Потеря leader в середине
  сцены оставляет captured reference и вызывает release error/force finish.
- orangesnail.EndTrail обращается к отсутствующим particle actors на dedicated.
- Прямой вход в Ch1 ещё не импортирует выученную Rictusempra; Lumos не реализован.
- Native shared development SavePath не является отдельным save каждого клиента.
- В supplied бинарнике есть spectator extensions, отсутствующие в supplied source;
  source rebuild не объявляется эквивалентом всех binary-only функций HideSeek.

## 2-PC tests required / next step

Пользователь подтвердил наличие второго ПК и самостоятельный запуск теста.
Нужен единый комплект пакетов: UCC генерирует новые GUID при rebuild. Проверки C01–C16
из `LOCAL_TEST_PROTOCOL.md` остаются pending. До них Milestone 1 не завершён.
Следующий кодовый blocker — единственная серверная intro с presentation и
блокировкой/возвратом ввода обоим, затем spellbook snapshot и interactions.
