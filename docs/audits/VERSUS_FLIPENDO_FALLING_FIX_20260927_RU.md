# Versus: runaway после Flipendo и `ProcessFalling`

База: `codex/versus-8-spawn-map` после `069a561`. Это исправление ограничено физическим результатом попадания Flipendo, совместимостью state-local функции падения и сбором диагностики. Native movement, HUD, камера, карта и fire cooldown не менялись.

## Причина и доказательства

В предоставленном `1 игрок runs.zip` сервер сам записал `HPVersusImpulse` после Flipendo и затем `PHYS_Falling` со скоростью по XY около 595. Максимальная измеренная горизонтальная скорость в четырёх dedicated server логах архива — **600.701**. Старый `HPVersusHarry.ApplyVersusImpulse` выполнял `Velocity += Impulse` без границы. При заряде Flipendo 0/0.5/1 raw push составляет 300/600/900, поэтому серия попаданий могла разгонять authority. Отдельный owner RPC снова делал `Velocity += Impulse` поверх локально предсказанного состояния. Это двойное *вычисление* импульса в двух копиях pawn; величину фактического расхождения server/client из присланных архивов измерить нельзя — во втором архиве нет runtime engine log клиента.

Исправление: сервер ограничивает прежнюю XY скорость значением `min(GroundSpeed, AirSpeed)`, raw XY push значением `AirSpeed`, составляет `push + 0.25 * prior` и ограничивает результат `AirSpeed` (stock 400). Z берётся как `max(oldZ, pushZ)` с ограничением `±JumpZ` (stock 245); повторный удар не суммирует вертикальную скорость. Сервер присваивает итоговый `Velocity`, а owner RPC **присваивает тот же итог**, не прибавляет push повторно. Урон и частота каста не ограничиваются этой формулой. Короткая трасса вокруг удара пишет pre/raw/result, слот, роли, время, положение, physics/state и native correction phase.

`harry.PlayerWalking.PlayerTick` вызывает state-local `ProcessFalling`. В одном клиентском crash сообщено, что runtime не нашёл эту функцию на `HPVersusHarry`. В родительском `harry.PlayerWalking` функция есть; в прежнем подклассе собственной state-local записи не было. Добавлен узкий bridge `HPVersusHarry.PlayerWalking.ProcessFalling` с тем же stock учётом высоты и времени падения, звука и `PlayInAir`. Причина, почему поиск в конкретном клиентском бинарнике не прошёл, полностью не доказана без его `HGame.u` и клиентского engine log. Старая/другая версия пакета остаётся возможным дополнительным фактором. На выходе за world bounds server вызывает стандартную смерть/respawn Versus через `FellOutOfWorld`.

## Проверки и границы результата

- `Build.ps1 -VersusV16`: UCC Success, 0 errors; patch chain применён и проверен.
- `python -m unittest discover -s tests -q`: 69 tests, 1 skipped.
- Arena Grounds dedicated + 2 настоящих `Game.exe`: все этапы `VersusMechanicsProbe` PASS, в том числе повторный каст без кулдауна, Flipendo damage/impulse, первый и повторный bounded hit, Spongify, pickup, death/respawn, новый матч. Максимум XY в коротких authority knockback traces — **400.103** (погрешность native physics около границы 400). Процессы не упали за время этого теста.
- `startup.unr` через `Start-MenuTest.ps1`: dedicated + два отдельных клиента вошли; серверные состояния обоих остались нормальными. Этот idle smoke не заменяет ручной тест движения и прыжков.
- `launch.json` теперь записывает хеши HGame/M212Share и карт, commit, корректный session ID прямого меню; `CollectSession` перечисляет сохранённые stdout/stderr и копирует найденные engine logs. Полный ZIP содержит ожидаемые хеши пакетов и предупреждает о локальном несовпадении.

На этом ПК в новых клиентах Game.exe **не появился engine log** ни для скрытого, ни для видимого запуска; `CollectSession` честно сообщает `engineLogLocationVerified=false`. Трассу owner RPC/native correction и идентичность пакетов на втором физическом ПК пока нельзя подтвердить. Нужен ручной двухПК тест: движение/прыжок/падение, Flipendo на земле и в воздухе с несколькими зарядами, стены/край карты, проверка камеры/HUD/Alt и сравнение package hashes обоих session manifests. Visual/gameplay acceptance остаётся открытым.
