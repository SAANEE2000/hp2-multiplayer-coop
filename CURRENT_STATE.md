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
  `20260920-220245-933`: **0 ошибок / 268 warnings**. Три дублирующих объявления
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
  Клиентский визуал отделён от server collision. Для Lumos подтверждены
  original server hits двух владельцев; ручные casts и визуал ещё не приняты.

## Текущие блокеры первого уровня

1. Shared camera/input/subtitles реализованы: intro завершилось в loopback,
   оба клиента получили валидный camera snapshot через PlayerCalcView и release
   к личной BaseCam. Подробности: `docs/iterations/20260920_COOP_CUTSCENE.md`.
   Отдельный opt-in captured-authority режим восстановил native ProcessState:
   оригинальный walk прошёл 462,4 units к CutMark0, выдал original cue, после
   release владелец восстановил Role3 и подтвердил resume. См.
   `docs/iterations/20260920_COOP_CAPTURED_AUTHORITY.md`. Режим выключен по умолчанию;
   новый opt-in FirstIntroPreflight дождался обеих camera ACK до original Play,
   провёл original walk/cue и вернул обоих владельцев через resume barriers.
   Непрерывные owner Role2 camera dispatches подтверждены логом, см.
   `docs/iterations/20260920_COOP_INTRO_PREFLIGHT.md`. Пропуск ACK каждого слота,
   повторные callbacks и смерть любого игрока во время оригинального MoveTo
   проверены узкими opt-in fixture; сессия останавливается без дальнейших
   сюжетных команд. Визуальный результат и checkpoint recovery не проверены;
   визуальная/физическая приёмка и непрерывность owner presentation не доказаны.
   Отключение StoryLeader посреди
   сцены, перенос captured actors/controllers и аварийная очистка ещё требуют решения.
   Два холодных локальных запуска MountRoot остановились в preflight: второй
   клиент держал нулевой camera snapshot весь 20-секундный срок; повторные
   запуски того же бинарника прошли. Пассивный owner-журнал теперь записывает
   сам shared-view актор и его scene/snapshot для поиска причины. Барьер не
   ослаблен и причина задержки репликации пока не установлена.
2. Явный тестовый старт `RictusempraLessonComplete` передал GSTATE030 и четыре
   spells обоим loopback клиентам до readiness. Lumos owner-aware реализация
   прошла fixture с двумя original hits по map gargoyles, двумя источниками,
   независимым выключением и штатным 30s expiry. См.
   `docs/iterations/20260920_COOP_LUMOS_HITS.md`. Reveal/door/визуал ещё не приняты. Клиентский
   native screening не находит map Harry до позднего snapshot: это отдельный
   нерешённый blocker общей кампании, подробнее `docs/audits/STORY_STATE_AUDIT.md`.
3. Authority health/status/potion и одиночное возрождение реализованы. Explicit
   loopback fixture прошла фазы 0–12: оба владельца независимо получают урон,
   умирают и возвращаются с 41 HP; owner HUD snapshots совпали с сервером.
   См. `docs/iterations/20260920_COOP_HEALTH.md`. Это не визуальная/двух-PC приёмка.
   При смерти обоих shared checkpoint ещё BLOCKED. Личные Ch1 frog/potion pickups
   прошли native Touch fixture для обоих владельцев; четыре контакта книг
   отказаны без изменения статуса/очереди save. См.
   `docs/iterations/20260920_COOP_PICKUPS.md`. Отдельный PickupNet fixture доказал
   существование и native удаление original frog/bottle на обоих клиентах;
   `docs/iterations/20260920_COOP_PICKUP_REPLICATION.md`. Естественный подбор
   размещённых предметов, native frontend, trigger visibility и travel ещё
   не подтверждены. Оба игрока прошли отдельный fixture с оригинальными
   Ch1 `firecrabSmall`: каждый краб выбрал своего владельца, вошёл в исходное
   состояние атаки и его `spellFireSmall` уменьшил здоровье именно этого
   владельца со 100 до 94. Это не проверка естественной навигации, остальных
   врагов или двух ПК. Отдельный `AISnail` fixture с двумя исходными
   `orangesnail` прошёл патрульный поиск, `RamHarry` и настоящий контактный
   урон 100→70 каждому владельцу; тестовым экземплярам понадобился явно
   заданный патрульный режим без маршрута. Размещённые враги и кислотный след
   не приняты; см. `docs/iterations/20260920_COOP_CH1_AI.md`.
   Save/load пока явно недоступен через проверенные script routes.
4. Опциональный Ch1 `MountRootB0/B1` fixture прошёл исходные
   `Mounting → MountFinish → PlayerWalking` после штатного intro и подтвердил
   одно сжатие/восстановление капсулы, Role2 и owner commit. Но позиция
   владельца до конечной коррекции отличается от сервера примерно на 60–61
   единицу в обоих вариантах. B1 удержал измеренный корень модели относительно
   актёра у второго клиента, тогда как B0 дал заметное смещение; опрос костей
   может менять кэш анимации. Это не доказательство естественного уступа,
   визуальной правильности или готовой сетевой механики. См.
   `docs/iterations/20260920_COOP_MOUNT_ROOT.md`.
5. Автоматизация UI не смогла захватить игровые окна из-за ошибки идентификации
   владельца окна. Визуальные и ручные игровые проверки не отмечаются PASS.
6. Native M212 использует общий development UserFolder до чтения сессионного INI;
   изоляция исходного профиля есть, разделение save-профилей клиентов не доказано.

Второй физический ПК у пользователя есть; тест на нём пользователь проведёт сам.
Протокол: `docs/LOCAL_TEST_PROTOCOL.md`. Аудиты: `docs/audits/`.
Глубокая доработка Versus отложена до завершения co-op. Full campaign, save/load,
специальные механики и двух-PC acceptance **не подтверждены**.
