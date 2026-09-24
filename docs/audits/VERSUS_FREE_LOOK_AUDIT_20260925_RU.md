# HP2 Versus FFA: аудит Alt Free Look

Дата проверки: 25 сентября 2026 года.

## Итоговое поведение

- Удержание левого `Alt` фиксирует yaw локального персонажа.
- Штатная `BaseCam.StateStandardCam` продолжает принимать мышь и рассчитывать позицию вокруг прикреплённого к персонажу `CamTarget`. Отдельной free-fly камеры и второго расчёта позиции нет.
- Pitch остаётся в штатных пределах `BaseCam.ApplyMouseYToDestPitch`.
- Движение, прыжок, физика и Native movement не перенастраиваются при нажатии `Alt`.
- Направление сетевого pawn и направление заклинания фиксируются на значениях момента входа в Free Look. Камерный yaw не отправляется как новый игровой aim.
- При отпускании `Alt` камера ставится за прежний yaw персонажа, после чего восстанавливается обычная связь камеры и тела. Персонаж не разворачивается к временному углу обзора.
- Состояние сбрасывается при смерти и `SetupVersusPlayer`, поэтому оно не переносится в respawn или новый матч.

## Изменённые файлы

- `patches/versus-v16-free-look.json`
  - добавляет виртуальный guard `ShouldCouplePawnRotationToCamera()` в `harry.uc`;
  - добавляет локальное состояние Free Look в `HPVersusHarry.uc`;
  - перехватывает `IK_Alt`/`IK_LAlt` в `Internal/HPConsole.uc` только при наличии локального `HPVersusHarry`.
- `scripts/Launch-Multiplayer.ps1`
  - не записывает нестабильный alias `Alt` в runtime `User.ini`; M212 удалял такой alias при старте;
  - Alt обрабатывается напрямую игровым console key event.
- `tests/test_versus_freelook_contract.py`
  - проверяет локальность состояния, фиксацию pawn/aim, использование штатной орбиты, выход, death/setup reset и Alt key path.
- `tests/test_patch_recipes.py`
  - корректно загружает вложенные исходники v16, включая `Classes/Internal/HPConsole.uc`.

`HPVersusCamera.uc` в итоговый патч не входит: ручной `UpdateFreeLookOrbit` удалён. Это исключает двойное применение mouse delta и оставляет одну систему позиционирования камеры.

## Локальность и authority

`bVersusFreeLook`, зафиксированные rotator и флаг активности не входят в replication block. Новых RPC нет. На клиенте guard запрещает `harry.PlayerTick` и `PlayerWalking` копировать временный camera yaw в `ViewRotation`/`DesiredRotation`. Перед native `ReplicateMove` локальные `Rotation`, `DesiredRotation` и `ViewRotation` остаются зафиксированными, поэтому сервер не получает временное вращение обзорной камеры как поворот pawn.

`GetVersusAimRotation()` во время удержания возвращает сохранённый aim rotator. `GetVersusMoveRotation()` для direct fallback возвращает сохранённый pawn rotator. Основной Native movement и значения `bScreenRelativeMovement` не переключаются.

## Сборка и автоматические проверки

- Полный `python -m unittest discover -s tests -p 'test_*.py' -v`: 44 теста успешно, 1 platform-dependent symlink test пропущен Windows без права создания symlink.
- `Build.ps1 -VersusV16`: `Success - 0 error(s), 276 warnings`.
- Build log: `.local/builds/20260925-000612-171/ucc-output.log`.
- Собранный `HGame.u`: SHA-256 `FC64F249F489D84D30D54692E1DD0E33AFDAA18E1B3EA1F5E223F7EE36772817`.

## Runtime smoke

Запущены dedicated server и два настоящих `Game.exe` клиента Harry/Ron на порту 7794. Сервер увидел обе сетевые pawn (`TcpipConnection0` и `TcpipConnection1`), процессы клиентов оставались responsive.

Дополнительно меню запустило host/join сессию `20260925-000722`. Клиентский журнал:

`C:\Users\user\Documents\HP2-Multiplayer-Development\HP2MP-versus-join-20260925-000722-894-93cbcd.log`

зафиксировал три полных цикла `HPV FREELOOK ENTER` / `HPV FREELOOK EXIT`. В первом интервале `Cam.Rotation.Yaw` менялся, включая переход через границу 65535, а `Rotation.Yaw`, `DesiredRotation.Yaw` и `ViewRotation.Yaw` персонажа оставались `0`. В следующем интервале pawn оставался на yaw `430`, пока камера меняла pitch/yaw. Это подтверждает отделение штатной орбитальной камеры от pawn rotation. После выхода обычная связь восстанавливалась.

В этом клиентском журнале: 0 `Critical`, 0 `Error`, 0 `ScriptWarning`, 0 `Accessed None`.

## Ограничение проверки

Лог подтверждает key path, изменение camera rotator и неизменность pawn/aim rotator. Субъективную плавность орбиты и композицию кадра нужно оценивать глазами в игровом окне; они не выводятся движком в журнал как готовый критерий.
