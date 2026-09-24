# HP2 Versus FFA: аудит Alt Free Look

Дата повторной проверки: 25 сентября 2026 года.

## Статус прежней проверки

Runtime-проверка сборки `985f094` была недостаточной. Она фиксировала изменение `Cam.Rotation`, но не проверяла `Cam.Location` и фактические выходные параметры `PlayerCalcView`. Визуальная проверка пользователем показала, что ожидаемой орбиты вокруг персонажа нет. Поэтому прежний вывод о работоспособной орбите отозван.

## Фактический render path

В штатном `BaseCam.StateStandardCam.Tick()` камера проходит цепочку:

1. `ApplyMouseXToDestYaw()` / `ApplyMouseYToDestPitch()` меняют `rDestRotation`.
2. `UpdateRotation()` сглаживает значение в `rCurrRotation` и вызывает `SetFinalRotation()`.
3. `UpdatePosition()` вычисляет `Cam.Location` из `CamTarget.Location`, дистанции и `rCurrRotation`.
4. `harry.PlayerCalcView()` отдаёт viewport значения `ViewTarget.Location` и `ViewTarget.Rotation`. В Versus `ViewTarget` должен быть тем же объектом, что и `Cam`.

Ручного `UpdateFreeLookOrbit()` в реализации нет: положение камеры по окружности рассчитывает только штатный `StateStandardCam`.

## Причина визуального сбоя

`harry.PlayerTick()` после обработки камеры записывал:

`BaseCam(ViewTarget).rExtraRotation = ViewRotation - BaseCam(ViewTarget).rCurrRotation`.

Во время Alt `ViewRotation` намеренно оставался направлением персонажа/прицеливания. Затем `BaseCam.SetFinalRotation()` прибавлял этот `rExtraRotation` к `rCurrRotation`. Поэтому штатные `rDestRotation` и `rCurrRotation` могли меняться, но итоговая видимая `Cam.Rotation` каждый кадр возвращалась к замороженному направлению персонажа. Это и давало странное перемещение вместо нормальной орбиты.

Исправление: когда локальный Versus pawn находится в Free Look, `harry.PlayerTick()` записывает нулевой `rExtraRotation`. В обычном режиме исходное поведение HP2 сохранено.

## Реализация

- Alt фиксирует `Rotation`, `DesiredRotation` и отдельное направление прицеливания локального pawn.
- Штатный `StateStandardCam` продолжает принимать mouse delta и выполнять `rDestRotation -> rCurrRotation -> UpdatePosition()`.
- `bSyncPositionWithTarget=True`, `bSyncRotationWithTarget=False`; камера остаётся привязана позицией к `CamTarget`, но её yaw не берётся из pawn.
- `ApplyStandardCam()` не вызывается в кадрах, где Alt удерживается или ещё завершается. Значит его `InitTarget()`/стабилизация не вмешиваются в орбиту.
- `ForceStandardCam()` остаётся только в одноразовом `SetupVersusPlayer()` и в явно вызываемой диагностической команде `VersusFixView`.
- `InitPositionAndRotation(True)` во Free Look вызывается один раз при отпускании Alt: сначала восстанавливается сохранённый yaw pawn, затем штатная камера ставится за него. Сам pawn не разворачивается к временному yaw камеры.
- При `bScreenRelativeMovement=True` движение во время Alt использует сохранённый yaw pawn через `GetScreenRelativeMovementRotation()`, а не временный `Cam.Rotation`. Native movement и его replication pipeline не заменены.
- Состояние Free Look локальное, не входит в replication block и сбрасывается при смерти/setup.

## Временная диагностика viewport

Пока Alt активен, `HPVersusHarry.PlayerCalcView()` раз в 0,20 секунды после вызова `Super.PlayerCalcView()` пишет:

- `ViewTarget`, `Cam`, `ViewTargetEqualsCam`, `CamState`;
- `PlayerCalcView.CameraLocation`, `PlayerCalcView.CameraRotation`, расстояние между выходной `CameraLocation` и `Cam.Location`;
- `Cam.Location`, её изменение с предыдущего замера, `Cam.Rotation`, `rDestRotation`, `rCurrRotation`;
- `CamTarget`, его `Location`/`Rotation`, расстояние от камеры до target;
- `bSyncPositionWithTarget`, pawn `Rotation`, `DesiredRotation`, `ViewRotation`, `bScreenRelativeMovement`.

Эта диагностика позволяет считать runtime PASS только если неподвижный pawn сохраняет yaw, `CamTarget.Location` остаётся постоянным, `Cam.Location` меняется по окружности с примерно постоянным радиусом, а `PlayerCalcView.CameraLocation` совпадает с `Cam.Location`.

## Сборка и автоматические проверки

- Полный `python -m unittest discover -s tests -p 'test_*.py' -v`: 45 тестов успешно, 1 platform-dependent symlink test пропущен.
- `Build.ps1 -VersusV16`: `Success - 0 error(s), 276 warnings`.
- Build log: `.local/builds/20260925-002559-034/ucc-output.log`.
- Собранный `HGame.u`: SHA-256 `451BDB6F6F3EB6368BCC37B2131B6BF2999387060C5E68F90929A2285E06E7D6`.
- `harry.uc`: SHA-256 `97246040BA9E7A7B9A6679DD52617E4466294E6C3BD9CA17192AAF04E1695F4D`.
- `HPVersusHarry.uc`: SHA-256 `26F79B46D92F3DF240D3105E931887773EAFE782BABFB256EDACFC293215467D`.

## Runtime acceptance: PASS

Проверена сессия `versus-join-20260925-002649-244-982e33` на настоящем `Game.exe` клиенте с dedicated server.

- Пользователь визуально подтвердил ожидаемую орбиту вокруг неподвижного персонажа и корректный возврат камеры после отпускания Alt.
- `ViewTargetEqualsCam=True`, `CamState=StateStandardCam`.
- `PlayerCalcView.CameraLocation` во всех приведённых замерах совпадает с `Cam.Location`: `CameraLocationMinusCam=0.000000`.
- При постоянном `CamTarget.Location=7.956156,515.098755,179.600006` камера прошла, например, через `102.948318,600.830444,176.348312`, `135.156097,528.514038,174.680206`, `26.874943,396.577087,135.117462` и `-92.475517,449.925110,134.324463`.
- Расстояние `Cam.Location` до `CamTarget.Location` во всех этих точках остаётся примерно `128.0`, то есть это реальная орбита, рассчитанная `UpdatePosition()`, а не изменение одного rotator.
- Yaw `Rotation`, `DesiredRotation` и `ViewRotation` pawn во время прохода оставался `43729`, тогда как `Cam.rCurrRotation.Yaw` изменялся от `43729` до `6004` и обратно.
- После отпускания `HPV FREELOOK EXIT` зафиксировал возврат камеры в `71.548332,626.184448,179.600006`, соответствующий сохранённому yaw pawn.
- В клиентском журнале: 0 `Critical`, 0 `Error`, 0 `ScriptWarning`, 0 `Accessed None`.

Acceptance выполнен по двум независимым признакам: координатам фактического viewport и визуальной проверке пользователя.
