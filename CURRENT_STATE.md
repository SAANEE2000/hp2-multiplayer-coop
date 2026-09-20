# Текущее состояние — 20 сентября 2026

**Campaign co-op не закончен. Milestone 1 ещё не пройден. Работа идёт в `coop`.**

- Установленные 874 HGame `.uc` совпадают с v18. Это последний предоставленный
  кандидат, а не подтверждённый релиз. Поставленный HGame.u содержит расширения
  spectator/HideSeek, отсутствующие в этих исходниках; исходный бинарник сохранён.
- Git содержит `main`, `coop`, `versus`, `research/friend-v18` и исходный тег
  `baseline-online-codex-handoff-20260920`. `main` фиксирует происхождение baseline;
  проверенной игровой сборкой его пока называть нельзя. GitHub remote ещё не создан:
  GitHub connector авторизован, но create-repository tool и git push credentials
  в проверенной конфигурации не доступны.
- Оригинальная игра/архивы сохранены. Все сборки и запуски идут из `.local/game`.
  Retail assets, бинарники и полный decompile не добавлены в Git.
- Чистый UCC rebuild baseline: 0 ошибок / 279 warnings. Последняя co-op сборка
  `20260920-154831-033`: **0 ошибок / 268 warnings**. Три дублирующих объявления
  классов исправлены; два ресурса проверены в скомпилированных defaults.
  Остальные warnings требуют адресного разбора; это не warning-free build.
- Отдельные HPCoopGame/Harry/PRI/GRI: два слота, StoryLeader, owner-local
  camera/HUD/cursor/wand, штатный opt-in ReplicateMove, ожидание готовности обоих.
  Исходные Harry death/damage/timer и Director восстановлены узкими рецептами;
  сетевые opt-in hooks и старые режимы сохранены.
- На одном ПК сервер `Ch1Rictusempra` принял **два настоящих клиента**, разные
  HPCoopHarry и HPCoopWand, оба readiness RPC, затем запустил мир. При потере
  первого игрока реестр передал StoryLeader второму; после последнего выхода
  сервер вернулся к ожиданию. Это сетевой smoke test, не доказательство управления,
  видимости, ledge, заклинаний или прохождения.
- Сборка содержит серверный запрос оригинальных projectiles с проверкой caster,
  состояния, cooldown, spellbook, цели, диапазона, offset, направления и LOS.
  Клиентский визуал отделён от server collision. Касты в игре пока не приняты.

## Текущие блокеры первого уровня

1. Shared cutscene camera/input/subtitles и очистка при disconnect: intro исполняется
   на сервере, но legacy код обращается к отсутствующим HUD/Console. Отключение
   StoryLeader посреди intro привело к ошибке release; исправление ещё требуется.
2. Снимок выученных заклинаний при запуске середины кампании: Rictusempra выдаётся
   предшествующим уроком. Lumos требует owner-aware света и shared reveal policy.
3. AI для обоих игроков, health/status replication, death/respawn/checkpoint,
   authoritative pickup/trigger visibility и multiplayer travel ещё не завершены.
4. Mounting/MountFinish/root motion исследованы, но сетевое подтягивание не доказано.
5. Автоматизация UI не смогла захватить игровые окна из-за ошибки идентификации
   владельца окна. Визуальные и ручные игровые проверки не отмечаются PASS.
6. Native M212 использует общий development UserFolder до чтения сессионного INI;
   изоляция исходного профиля есть, разделение save-профилей клиентов не доказано.

Второй физический ПК у пользователя есть; тест на нём пользователь проведёт сам.
Протокол: `docs/LOCAL_TEST_PROTOCOL.md`. Аудиты: `docs/audits/`.
Глубокая доработка Versus отложена до завершения co-op. Full campaign, save/load,
специальные механики и двух-PC acceptance **не подтверждены**.
