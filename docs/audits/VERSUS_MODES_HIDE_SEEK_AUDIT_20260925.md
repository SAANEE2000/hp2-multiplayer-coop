# Аудит Versus modes / Hide & Seek — 2026-09-25

## Donor v18

Проверены `v18/v18/HGame/Classes/HPHideSeek/*` и Hide & Seek-вставки в
`v18/v18/HGame/Classes/HPVersusHarry.uc`.

Пригодными как ориентир оказались специальные Wait/Hunt/Hider markers,
репликация роли/состояния раунда, отдельный `bCaught` и идея визуальной замены
mesh без замены PlayerPawn.

Donor нельзя было переносить целиком:

- `HPHideSeekGame` наследовал общий `GameInfo`, дублировал Versus lifecycle и
  запускал раунд прямо из `PostLogin` после второго игрока;
- hunt не имел полноценного лимита времени и перехода в следующий раунд;
- Hunter мог повторяться, late join и disconnect не были оформлены;
- caught превращал pawn в скрытый flying ghost, отключал collision и смешивал
  режим с `bVersusDead`;
- disguise принимал произвольный traced mesh и scale из мира без whitelist;
- donor-заклинания и старые spawn/login решения не соответствовали принятому
  v16 movement/camera/character pipeline.

## Реализация

- `HPHideSeekGame extends HPVersusGame` переиспользует текущие login, слоты,
  `HPVersusHarry`, character profiles, Native movement, камеру/Alt Free Look,
  анимации, cloak channels и spell transport.
- State machine: `WaitingForPlayers -> SelectHunter -> HidePhase -> HuntPhase ->
  RoundOver -> NextRound`.
- Hunter выбирается на сервере случайно; предыдущий slot исключается при наличии
  альтернативы. Wait/Seek используются после обычного подключения и создания
  штатного pawn.
- Hide/Hunt по умолчанию 60/180 секунд, доступны в host menu и URL options.
- Hunter в Hunt Phase может запросить только Rictusempra. Попадание вызывает
  `NotifyHiderCaught`; HP, frag, death и FFA respawn не затрагиваются.
- Hider остаётся `HPVersusHarry`. Сервер разрешает только шесть профилей:
  Barrel, Wooden Chest, Bronze Cauldron, Vase, Chair, Box. Player capsule не
  меняется. Состояние и визуальный профиль реплицируются.
- `HPHideSeekGRI extends HPVersusGRI` реплицирует phase, timer, Hunter и
  `HidersLeft`. Общий `HPVersusHUD` рисует компактный mode overlay и роли в F3.
- Общий pawn получил только role/caught/disguise/lock state и четыре виртуальных
  policy bridge в GameInfo. Прямых проверок класса `HPHideSeekGame` в pawn нет.
- Карты и поддерживаемые режимы задаются одним `config/versus-maps.json`.
- `HPV_HideSeek.unr` — отдельная копия арены. Runtime fixture создаётся только
  на этой карте; `startup.unr` не менялся.

## Автоматическая проверка

UCC build: `Success - 0 error(s)`.

Hide & Seek dedicated + 3 clients (`Harry`, `Ron`, `Hermione`):

- отдельные `HPVersusHarry0/1/2`, slots 0/1/2;
- placed `HPV_HideSeek.Harry0` удалён до входа игроков;
- подтверждены все шесть фаз, Wait/Seek markers и три роли;
- server-authoritative disguise применён;
- Hunter получил только Rictusempra после Seek unlock;
- первый и последний Hider помечены caught без FFA death;
- RoundOver и NextRound выполнены, Hunter сменился;
- character profiles сохранились.

FFA dedicated + 2 clients на `HPV_Interactions`:

- `HPVersusMechanicsProbe COMPLETE`: whitelist/cooldowns, health/speed pickups,
  Mimblewimble, Expelliarmus, Flipendo, Spongify, death/respawn, очистка buffs,
  сохранение character profile и новый матч;
- `HPVersusWorldProbe COMPLETE`: Alohomora lock/trigger, Flipendo world actor,
  Spongify pad/endpoint и возврат к Native movement;
- character audit прошёл для всего ростера.

Python contract suite и menu self-test проходят. Точные package SHA-256 и commit
указаны в итоговом сообщении и `.local/last-build-v16.json`.

## PENDING USER VISUAL TEST

- внешний вид и масштаб шести disguise props на всех клиентах;
- HUD/таймер/роли и F3 при реальном окне игры;
- расположение Wait/Seek/Hider зон и достаточность укрытий;
- визуальный момент попадания и caught presentation;
- движение, прыжок, spell animation, cloak channels и Alt Free Look у всех трёх
  основных персонажей;
- полный 60/180-секундный раунд без ускоряющего probe;
- ручной FFA regression после выхода из Hide & Seek.

Режим не считается визуально принятым до этой ручной проверки.
