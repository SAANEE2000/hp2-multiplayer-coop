# Versus: сетевое вскарабкивание и установка Arena test kit

## Вскарабкивание

`HPVersusHarry.ApplyVersusInput` и резервный `ServerVersusMoveInput` прерывали
штатные `Mounting`/`MountFinish` переходом в `PlayerWalking`. Теперь ввод на
время подъёма удерживается. На dedicated-сервере штатная root-motion анимация
продвигается при временном `RemoteRole=ROLE_SimulatedProxy`; после окончания
подъёма роль возвращается, клиент получает итоговые положение/коллизию и
подтверждает возобновление Native movement. Пакет собирается через три новые
hash-checked recipes `versus-v16-*mount*.json`.

Проверено: UCC 0 ошибок, полный набор 69 unit tests (1 skip); dedicated и два
клиента проходят `Mounting -> MountFinish -> PlayerWalking`, `climb32`, возврат
капсулы и подтверждение owner. Отдельный двухклиентский smoke прошёл 21
существующую Versus mechanics probe. Точный SHA-256 финального `HGame.u`
фиксируется в build record и манифесте тестового архива.

Ограничение: диагностический прогон вызывает штатный `Mount(Delta)` явно.
Попытка получить native auto-mount от динамического цилиндра на плоском
`startup.unr` не вызвала событие. Подъём на реальный BSP-уступ, видимый клиенту
и наблюдателю, пока требует ручной проверки на подходящей карте; это не
визуальный PASS. При такой проверке в серверном логе должны появиться
`HPVersusMount phase=Begin`, `RoleRestored`, `ReleaseSent`, `ServerResumed`;
после подъёма проверить движение, камеру и повторный прыжок.

## Невидимые банки в архиве товарища

`Setup-VersusTestKit.ps1` ранее импортировал старый
`private-test/hp2-versus-v16-test-build.zip` (HGame `8BD27E8B…`, commit
`5d2544d`), даже если запускался из полного Arena-архива (манифест ожидает
HGame `8D5E8E2F…`, commit `eb79d1d`). Именно это соответствует двум
предупреждениям `Installed HGame.u/M212Share.u differs from this test kit` на
скриншоте. Старый скрипт в полном Arena-архиве теперь вызывает
`Setup-ArenaGroundsTestKit.ps1`, а тот проверяет artifact и оба пакета по
`KIT_MANIFEST.json` до импорта. В обычном legacy test kit старый путь сохранён.

Число подключённых игроков не управляет появлением банок. На
`Arena_Grounds_hub` сервер обнаруживает 6 health и 5 speed pickup на карте
уже в `PostBeginPlay`; mechanics probe подтверждает их подбор. Внешний вид
банок на ПК товарища после установки согласованного набора ещё не проверен.
