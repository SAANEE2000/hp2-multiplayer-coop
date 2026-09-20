# Явный старт Ch1 и owner-aware Lumos

Commit: commit, содержащий этот отчёт; исходный HEAD сборки `baf8fb1`, working tree dirty.
Branch: `coop`.

Changed files: HPCoopCampaignState, Game/Harry initial snapshot, Wand/SpellVisual,
coop-spell-caster recipe, Launch-Multiplayer, STORY_STATE/CH1 spell audits.

Why: прямой запуск Ch1 не проходит предшествующий урок и не даёт Rictusempra.
Теперь `-TestStage RictusempraLessonComplete` явно задаёт GSTATE030/index30 и
Flipendo/Lumos/Alohomora/Rictusempra. Snapshot проверяется и применяется обоим
владельцам до readiness. По умолчанию fixture выключена; это не сохранение.
Исходный map Harry сохраняет bIsPlayer до native screening и отдаёт роль позже.

Lumos сохраняет оригинальные projectile/gargoyle/таймер LumosLight и события
LumosTrigger. Каждый свет принадлежит своему wand/caster; один выключенный свет
не гасит активный свет другого. Нативное раскрытие поверхностей остаётся личным
для владельца, shared doors проверяют оба источника. Это реализация, не runtime PASS.

Build: PASS `20260920-162258-321`, **0 errors / 268 warnings**.
HGame SHA256 `6E58C844651788C73E9B38D1600DE99A4C9501D42B2764E9D9CD41A9999AE755`.
M212Share SHA256 `13D40C3E43884714179EC39E10530314619ACEB031E84DD0E68B007EB8FA8F0D`.
Source manifest/UCC log: `.local/builds/20260920-162258-321`.

Automated/local tests:

- Patch suite19: **18 PASS / 1 SKIP**. Windows не разрешила создание symlink для
  соответствующего теста; настройки безопасности не менялись. Проверены все
  текущие recipes, fresh/partial/final hash chains и отказ при повреждённых входах.
- Launcher PrepareOnly сформировал fixture URL и отклонил fixture на Join/иной карте.
- Server `coop-host-20260920-162408-049-10e8ba`: seed GSTATE030 в InitGame перед
  harry.PreBeginPlay, два зарегистрированных игрока, readiness и завершённое intro.
- ClientA `coop-join-20260920-162408-304-a157a7`, ClientB
  `coop-join-20260920-162439-197-0229a7`: оба записали
  `local-initial-state=GSTATE030 spells=4 test-stage=True`, затем context-ready,
  shared camera snapshot и release к личной BaseCam. В клиентских логах нет
  `Accessed None` или `Critical`.

2-PC tests required: пользователь выполнит физическую проверку. Проверять оба
caster у gargoyle, исходный hit, source2-only secret door, два активных источника,
истечение одного без выключения другого, повторный cast, 30s expiry, cleanup.

Confirmed working: UCC, целостность patch chain, явный server seed, репликация
начального набора четырёх spells двум loopback владельцам, прежний intro smoke.

Unconfirmed: настоящие casts/hits/Lumos reveal/FX/doors, health/death/respawn,
ledge, checkpoint/save/travel. Client native screening пишет «Can't find a valid
player» ДО позднего snapshot: net startup удаляет исходного Harry. Одного URL
GameState недостаточно. В Ch1 не найдены явные GSTATE selectors, но для кампании
этот native lifecycle blocker остаётся; нельзя считать его решённым ApplyTo.

Known regressions/limitations: legacy map harry.PreBeginPlay обращается к None
Player; orangesnail.EndTrail перебирает ещё не созданные trail actors. UI automation
не позволяет проверить изображение/нажатия. Stage snapshot не содержит
награды урока, inventory или факт прохождения hub и не должен так называться.

Next step: проверка Lumos в реальном runtime, authority health/death и общий
contract специальных movement states; native client screening до campaign travel.
