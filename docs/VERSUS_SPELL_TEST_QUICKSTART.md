# Versus FFA: ручной тест шести заклинаний

Эта проверка выполняется на отдельной карте `HPV_Interactions`. Рабочий
`startup.unr` не изменяется: `Prepare-VersusInteractionArena.ps1` создаёт его
побайтовую копию, а сервер добавляет test fixture только при загрузке карты с
именем `HPV_Interactions`.

## Выбор заклинания

| Клавиша | Заклинание | Ожидаемое действие |
| --- | --- | --- |
| Numpad 1 | Rictusempra | PvP damage |
| Numpad 2 | Mimblewimble | PvP damage и временный mute |
| Numpad 3 | Expelliarmus | Прерывание зарядки и короткий disarm |
| Numpad 4 | Flipendo | Damage/push игрока или штатное world interaction |
| Numpad 5 | Alohomora | Padlock/spellTrigger/дверь без PvP damage |
| Numpad 6 | Spongify | Активация pad, затем штатный bounce к target |

Это именно клавиши цифрового блока. Строка `1`–`6` основной клавиатуры не
переназначается. Левая кнопка мыши заряжает и выпускает выбранное заклинание.
Клиент сразу меняет название, иконку и визуальный spell type; сервер повторно
проверяет номер слота, сопоставляет его разрешённому классу и проверяет
whitelist палочки до создания projectile.

## HUD

В левом нижнем углу постоянно показаны HP с полосой и точным значением из 100,
родная иконка и имя выбранного заклинания, а также `READY`, точный
`COOLDOWN x.xx`, `MUTED x.xx` или `DISARMED x.xx`. Активное ускорение выводится
короткой строкой `SPEED`. F3 и прежняя таблица результатов сохранены.

## Подготовка и запуск

Из PowerShell в корне репозитория:

```powershell
.\Build.ps1 -VersusV16
.\scripts\Prepare-VersusInteractionArena.ps1
```

Dedicated server:

```powershell
.\HostVersus.cmd -WorkRoot .\.local\versus-v16-game -Map HPV_Interactions -Port 7796 -MaxPlayers 2 -ScoreLimit 99
```

Первый клиент:

```powershell
.\JoinVersus.cmd -WorkRoot .\.local\versus-v16-game -Server 127.0.0.1 -Port 7796 -PlayerName SpellA -Character Harry -WindowX 20 -WindowY 40 -WindowWidth 800 -WindowHeight 600
```

Второй клиент:

```powershell
.\JoinVersus.cmd -WorkRoot .\.local\versus-v16-game -Server 127.0.0.1 -Port 7796 -PlayerName SpellB -Character Ron -WindowX 840 -WindowY 40 -WindowWidth 800 -WindowHeight 600
```

На втором физическом ПК замените `127.0.0.1` на IPv4 хоста. Карта находится в
`.local\versus-v16-game\Maps\HPV_Interactions.unr`.

## Что находится на стенде

Fixture строится вокруг центра арены. На нём есть штатные пути Alohomora
`Padlock -> event -> barrier` и `spellTrigger -> event -> barrier` с
health/speed pickup за ними, stock-derived cauldron и отдельный `spellTrigger`
для Flipendo, а также связанная пара
`SpongifyPad + SpongifyTarget`. Второй игрок является обычным сетевым игроком.

## Ручной checklist

- Numpad 1: имя/иконка переключились; Rictusempra снижает HP второго игрока.
- Numpad 2: Mimblewimble наносит урон и временно блокирует каст второго игрока.
- Numpad 3: Expelliarmus прерывает зарядку/даёт disarm и не становится обычным damage bolt.
- Numpad 4: Flipendo наносит игроку damage и push.
- Numpad 4: Flipendo отдельно активирует cauldron и spellTrigger/barrier.
- Numpad 5: Alohomora отдельно открывает lock/door и spellTrigger/barrier, не нанося PvP damage.
- Numpad 6: Spongify включает pad; наступивший игрок долетает до target, приземляется и снова двигается.
- Для каждого каста второй клиент видит projectile, FX и итог взаимодействия.
- Health pickup лечит, не превышая 100; speed pickup включается и гарантированно заканчивается.
- Повторно проверить Native movement, прыжок, Alt Free Look, Harry/Ron/Hermione,
  cloak channels, death, respawn, HP, score, pickups и следующий раунд.
- До подключения второго игрока повернуть камеру/персонажа в заметный угол:
  после старта countdown игрок переносится на свой spawn, но yaw/pitch камеры не
  должны сбрасываться к повороту `PlayerStart`.
- Для новых профилей (например, `GryffindorStudentM` и
  `SlytherinStudentF`) постоять без движения на обоих клиентах: локальный и
  удалённый персонажи должны проигрывать `Idle`, без T-позы.

Автоматические probe-тесты подтверждают серверные state transitions, но не
заменяют этот визуальный и игровой прогон двумя клиентами.
