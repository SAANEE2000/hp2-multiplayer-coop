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
