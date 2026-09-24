# Versus: FFA, выбор карт и Hide & Seek

Эта версия использует общее multiplayer-ядро `HPVersusGame` и `HPVersusHarry`.
Режим Hide & Seek добавлен производным `HPHideSeekGame`; отдельной копии движения,
камеры, профилей персонажей или spell transport нет.

## Меню

Запустите `Play-Menu-Test.cmd` и выберите:

1. `Сетевая игра`.
2. `Версус`.
3. `Каждый за себя` или `Прятки`.
4. Персонажа, затем `Создать сервер` или `Подключиться`.

Host выбирает карту и параметры режима. Join указывает только адрес, порт, имя и
персонажа; карту и режим он получает от сервера.

## Зарегистрированные карты

Каталог находится в `config/versus-maps.json`.

| Название | Package | FFA | Hide & Seek | Игроки |
| --- | --- | --- | --- | --- |
| Startup Arena | `startup` | да | нет | 2–8 |
| Interactions Test | `HPV_Interactions` | да | нет | 2–8 |
| Hide & Seek Lab | `HPV_HideSeek` | нет | да | 2–8 |

`HPV_HideSeek.unr` создаётся как отдельная копия принятой арены. При запуске
`HPHideSeekGame` добавляет на неё функциональный стенд: Wait/Seek, восемь Hider
точек, укрытия и шесть примеров предметов. `startup.unr` не изменяется.

## Прямой запуск

Из PowerShell в корне репозитория:

```powershell
.\HostHideSeek.cmd -WorkRoot .local\versus-v16-game -Map HPV_HideSeek -Port 7777 -MaxPlayers 3 -HideTime 60 -HuntTime 180
.\JoinHideSeek.cmd -WorkRoot .local\versus-v16-game -Server 127.0.0.1 -Port 7777 -PlayerName Harry -Character Harry -WindowX 20 -WindowY 40
.\JoinHideSeek.cmd -WorkRoot .local\versus-v16-game -Server 127.0.0.1 -Port 7777 -PlayerName Ron -Character Ron -WindowX 840 -WindowY 40
.\JoinHideSeek.cmd -WorkRoot .local\versus-v16-game -Server 127.0.0.1 -Port 7777 -PlayerName Hermione -Character Hermione -WindowX 430 -WindowY 680
```

FFA с выбором карты:

```powershell
.\HostVersus.cmd -WorkRoot .local\versus-v16-game -Map HPV_Interactions -Port 7777 -MaxPlayers 2 -ScoreLimit 3
.\JoinVersus.cmd -WorkRoot .local\versus-v16-game -Server 127.0.0.1 -Port 7777 -PlayerName Harry -Character Harry
.\JoinVersus.cmd -WorkRoot .local\versus-v16-game -Server 127.0.0.1 -Port 7777 -PlayerName Ron -Character Ron -WindowX 840
```

Во время Hide & Seek `Numpad 0` циклически меняет маскировку Hider. Hunter во
время Hunt Phase может применять только Rictusempra.

## Ручная проверка

- До подключения второго игрока HUD остаётся в `WAITING FOR PLAYERS`.
- Каждый клиент управляет отдельным персонажем, никто не получает placed `Harry0`.
- В Hide Phase Hunter находится в Wait zone и не двигается/не колдует; Hiders
  двигаются и меняют маскировку через `Numpad 0`.
- На всех клиентах видны одинаковые роли, таймер, число оставшихся Hiders и
  выбранные предметы.
- Через 60 секунд Hunter переносится в Seek zone и получает управление.
- Rictusempra Hunter помечает Hider как `CAUGHT` без FFA death/frag/respawn.
- Последний найденный Hider завершает раунд; при следующем раунде Hunter
  меняется, если доступен другой игрок, а выбранные персонажи сохраняются.
- Если 180 секунд истекли и Hider остался, побеждают Hiders.
- `F3` показывает роли `HUNTER`, `HIDER`, `CAUGHT`.
- Проверить Native movement, прыжок, анимации/плащ, обычную камеру и Alt Free
  Look у Harry, Ron и Hermione.
- После Hide & Seek запустить FFA и вручную проверить countdown, HUD,
  заклинания, death/respawn, score и next match.

Автоматические probe-тесты подтверждают серверную логику, но не заменяют
визуальное принятие маскировок, HUD, расположения укрытий и камеры пользователем.
