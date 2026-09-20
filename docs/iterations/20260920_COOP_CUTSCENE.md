# Общая камера и возврат управления в entry-сценах Ch1

Commit: commit, содержащий этот файл; parent `aa00e26`.
Branch: `coop`.

## Изменения и причины

- `HPCoopServerHUD` обеспечивает authority-only callbacks оригинальных
  `harry.CutCommand` и `Actor.CutCommand_M212Say`. Не создаёт серверные UI widgets.
  Native speech cues и оригинальный script interpreter сохранены.
- `HPCoopGame` распространяет capture/release и субтитры на двух зарегистрированных
  игроков. Мир меняет единственный серверный CutScript, canonical Harry — StoryLeader.
- `HPCoopCutsceneView` передаёт позицию, поворот и FOV оригинальной серверной BaseCam.
  Клиент принимает только snapshot с валидным источником; snapshot не исполняет сюжет.
- `HPCoopHarry` блокирует input и новые/повторные ServerMove во время сцены,
  очищает pending prediction при входе/выходе, восстанавливает свои BaseCam/HUD/FOV
  и авторитетную конечную позицию. Это переход сцены, не замена обычного ReplicateMove.
- Четыре fire-флага native ServerMove замаскированы: оригинальный AltFire означает
  клиентское прицеливание, а серверный cast уже имеет отдельный проверяемый RPC.
  Movement, jump и параметры старого move сохранены. StartAiming/makeTarget имеют
  owner guard; отключение отсутствующего dedicated SpellCursor безопасно.
- `HPCoopCutScriptDisk` меняет только logging для двух рассмотренных entry-сцен:
  `Ch1RictuIntro` и `02080Ch1FireCrabIntro`. Не обращается к отсутствующей Console.

## Проверки

Build: PASS, `20260920-160817-611`, UCC **0 errors / 268 warnings**.
SHA256 HGame.u: `0DF232CB4F4871604E4C80BCBD07DD055A3E6B3B73FC78696B2A479EC8ACAE29`.
SHA256 M212Share.u: `CC0472470A491D92D4DF4E074252248DEA93F51FA965569A9BB0E62B6BD31D95`.
Полный log/source manifest сохранён локально в `.local/builds/20260920-160817-611`.

Предыдущая сборка `155833-295` и loopback:

- server `coop-host-20260920-155920-582-abb9eb`;
- client A `coop-join-20260920-155920-827-ad619f`;
- client B `coop-join-20260920-160128-334-be225a`.

Сервер принял два pawn/wand и оба context-ready. Intro дошло до единственного
`Trigger EntryBars`, `BeginChallenge`, полного release и ForceFinish. Следующая
сцена огненного краба тоже дала capture/release. В **обоих собранных клиентских
логах** две пары `local-capture=True/False`; восстановлены owner BaseCam1/ViewTarget.
Одинаковые имена BaseCam1 и HPCoopHarry0 в разных клиентских мирах не означают
один объект на сервере: слоты и server pawn различаются.

Обнаруженные в первом прогоне Console/SpellCursor warnings привели к owner guards
и второму opt-in CutScriptDisk. Одновременный запуск второго процесса первоначально
не дошёл до соединения; его отдельный повторный запуск подключился. Причина
startup-задержки пока не доказана. Старая незавершённая connection timeout300s
не была отключением успешно присоединённого второго клиента.

Повторный прогон **сборки 160817-611**:

- server `coop-host-20260920-160943-716-76c788`;
- client A `coop-join-20260920-160944-007-061be4`;
- client B `coop-join-20260920-161029-901-13b4e8`.

Оба подключились при последовательном запуске. Intro закончилось, оба клиента
записали `shared-view scene=1` из своего `PlayerCalcView` (snapshot62/31), затем
`local-capture=False` с собственной камерой. В обоих клиентских логах нет
`Accessed None`/`InvalidState`/`Critical`. На сервере нет None Console/SpellCursor
и MP_CUT_ERROR; старые warnings Snail.EndTrail и map harry.PreBeginPlay остаются.
Повторного старта FireCrab scene в этом прогоне не было; его после logging-guard
не считать повторно проверенным.

## Пределы результата

Это локальный сетевой тест двух процессов, **не двух физических ПК** и не пройденный
Milestone1. Не проверены визуальная плавность/субтитры/звук, нажатия во время capture,
возврат фактического управления, потери пакетов и задержка.

Known blockers: disconnect StoryLeader во время захвата, перенос controller/cue
ownership, malformed-script recovery, прочие cutscene types, player death,
checkpoint/save и campaign travel. Нельзя завершать каждый CutScript thread общим
release: intro передаёт capture через ReCapture следующему thread.

Next step: snapshot выученных spells
и authoritative gameplay первого уровня. Физическую проверку выполнит пользователь.

## Продолжение: встроенный сценарий первой двери

После боя с крабами карта естественно запускает `CutScene9` с триггером
`FirstDoor`. У сцены есть встроенный сценарий; исходный inline loader не
обрабатывал отдельную строку-заголовок `[Main]` так, как это делает loader
сценариев из файлов. Поэтому первый прогон после `AICombatDeath` выдал ошибку
разбора и предупреждения серверного `CutScript.CutLog/CutError` при обращении к
несуществующей локальной Console. `CutScene.Idle.Trigger` также разыменовывал
`harry(Other)` при событии от другого актора.

Рецепт `coop-inline-cutscene-header` в co-op превращает только отдельную
строку `[Main]` во внутренний комментарий перед запуском исходного CutScript.
Проверка смерти в `Trigger` теперь учитывает `Other`, который не является
Harry. Подкласс `HPCoopCutScript` меняет только вывод журнала inline-потоков
выделенного сервера; команды, cues, capture и release остаются исходными.

Сборка `20260920-221911-221`: UCC 0 ошибок / 268 предупреждений, HGame SHA256
`f7281f78ed3bf04b85b96df2f2667bb34e2de2c51b8aa348e819ce67a5188c78`,
M212Share SHA256
`2aa2e9fd91ac33c16ceda6e64fcded2888ce5e64e8f26dde52eb0c05`.
В loopback сессиях `coop-host-20260920-222001-356-9f27db`,
`coop-join-20260920-222001-724-409f03` и
`coop-join-20260920-222010-791-94ff44` вступление, fixture смены цели и
сцена огненного краба прошли снова. `CutScene9` началась ровно один раз,
выполнила исходные camera/capture/release команды, завершила поток и сняла
shared capture. Оба клиента записали третью `shared-view` сцену со snapshot
81/45 и последующее `local-capture=False` со своей BaseCam. Сервер: 0 Critical,
0 `MP_CUT_ERROR`, два прежних map-Harry `PreBeginPlay` Accessed None; оба
клиента: 0 Critical/Accessed None. Процессы остановлены, engine logs собраны.

Это подтверждает исполнение и наблюдаемые owner camera callbacks в локальном
тесте. Визуальный результат, фактический ввод после release, естественное
прохождение дальнейшего уровня и оба физических ПК ещё не проверены.

По read-only метаданным той же карты ещё девять inline-сцен содержат отдельный
`[Main]` header. Они соответствуют форме исправления, но их выполнение не
проверено. Окончательный исходник сузил назначение `HPCoopCutScriptDisk`
обратно до двух исследованных файловых сцен; остальные файловые сцены остались
на исходном классе. После этого сборка `20260920-222801-963` прошла UCC 0/268,
HGame SHA256 `555d668c6280b41a5f83ac7f05ad7e5162f76ee5da4dfd7c79c3e12e0567bddf`,
M212Share SHA256
`f093fe6cf3592936a5414c4efbee5da9082a660d6df4986b11d0d001c2bed0c9`.
На этом бинарнике host `coop-host-20260920-222849-412-920790` и два клиента
снова прошли вступление и `PASS_DEATH_RETARGET`; server 0 Critical/
`MP_CUT_ERROR` и два старых map-Harry Accessed None, клиенты 0 Critical/
Accessed None. В этом повторе карта сама не запустила ни сцену краба, ни
`CutScene9`, поэтому runtime-подтверждение её выполнения относится к
предыдущей сборке. Три процесса остановлены, журналы собраны.
