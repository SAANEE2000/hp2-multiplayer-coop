# Versus v16: проверка исходников и миграционной цепочки

Accepted HUD и масштаб взрослых персонажей: `9dbd9c4`. В этой работе
`HPVersusHUD.uc` и таблица масштабов не менялись.

Проверенный архив `HPVersus_v16_remote_bottom_align_20260905.zip`:
`A2B13B924BF9BBA9F81C6A70E38024657C71F6F1F861FA49BF3F812C86EFB9BF`.
После `Prepare-VersusV16.ps1` в отдельном новом WorkRoot получены точно эти
чистые хеши, а полный batch и UCC завершились успешно.

`HGame/Classes/Internal/HPConsole.uc`:

| Состояние | SHA-256 |
| --- | --- |
| clean v16 | `73ab38bbc4b63d7f319cce57989cdc2f6e640497a3de177b128d0e91f3e4ccd2` |
| `versus-v16-free-look` / current final | `4e62bf7663b67c64be68ed6409935309acb854f33805c9859155584926cdc75b` |

`HGame/Classes/harry.uc`:

| Состояние | SHA-256 |
| --- | --- |
| clean v16 | `c4dfe134fdc5da24d691296cc65f60999cb5b8fa60e1e6dacefa485fef09f6c3` |
| `versus-v16-free-look` (исторический `985f094`) | `562ff90c7567a3b80ef6b29a74240c4508241644456b802086dca979b6b5472c` |
| `versus-v16-free-look-render-migration` / current final | `97246040ba9e7a7b9a6679dd52617e4466294e6c3bd9ca17192aaf04e1695f4d` |

`HGame/Classes/HPVersusHarry.uc`:

| Recipe / состояние после него | SHA-256 |
| --- | --- |
| clean v16 | `d59aee7b9718d296b70bac246b8c8df0d6eda39d434aef604dd206f381505146` |
| `versus-v16-death-respawn` | `1514e93442d38c1bc3535455a9d681c983101dfe0b6f070d8cdf802ce55f9186` |
| `versus-v16-match-flow` | `163141384590298efde73997733f856b9f90639ee85b38143e641a55ae6dadb9` |
| `versus-v16-eight-slots` | `430eb4db34c20ae62393413997117641efc79f1d5aa19e9efe5233cf2fd5705c` |
| `versus-v16-native-default` | `b93c6e5173fab5b25c93a5c0cca62df1041eb8af5f8b5a69185e37925a8e5636` |
| `versus-v16-character-choice` | `975ce5a2d98e5c1b8fc84439dd462dad378d46669f2480a73259a4accb7845fa` |
| `versus-v16-hud-respawn` | `7a9a2249a7b1844d645c405ee50604f784c4400062a9cdbdb411bac8c9943c73` |
| `versus-v16-score-key` | `b2261a6faeabc80e20832ae16aeb3db2ff701120196811c3147b3fd96df97711` |
| `versus-v16-character-motion` | `28017b318705f97bf33784599e1de0ec1670bb053cfd1ca1ac2a9e6c10267076` |
| `versus-v16-player-animations` | `4340c8185a4d01fdb8321cd463afe22f2245bbfb48b7704b15da1d756a2baf1e` |
| `versus-v16-v18-donor-mechanics` | `247e79126b364c3c3d97cb9b2068e1c79ec10d9e4ea47fee3ccef0be709a9532` |
| `versus-v16-world-interactions` | `aeac8ba53442dc2238f4b8669d238a766c29ab51b0ad702e67960e9f326d5e99` |
| `versus-v16-spongify-network` | `f618fa5de4c2e6ef3de37ec73aae5da61df6cf9e88fc930e9452eb01d72b320d` |
| `versus-v16-character-profiles` | `621e813baba61c56cbd90fccbfdf5152eea7f62017303f749195d44fb328173c` |
| `versus-v16-free-look` (исторический `985f094`) | `340dbf03b69d93d999e8a84be423706e8e31ad8139acd842f4d10c75fad61a98` |
| `versus-v16-free-look-render-migration` | `26f79b46d92f3df240d3105e931887773eafe782babfb256edacfc293215467d` |
| `versus-v16-spell-test-hud` | `d6b953152f9cca019020b724dca1a2dccbecf54627eae5b3d036011d862f846f` |
| `versus-v16-join-camera-idle-fix` | `445e027e5d3d23891921d69c72abb6447f7536d8afdbc3e20ab8ad6b62a35651` |
| `versus-v16-hide-seek` / current final | `6b4ecdc56e3105726c5ccfc448ef15e5ccdfa898e3e5205a1bfa72acfbbae8cf` |

В `24259b4` два результата Free Look (`harry.uc`, `HPVersusHarry.uc`)
были изменены внутри старого recipe. Это отрезало подготовленные на
`985f094` WorkRoot. Теперь старый шаг восстановлен, а текущая логика
применяется отдельным миграционным recipe. `HPConsole.uc` в этих двух версиях
recipe имел одинаковые source/result hash: его ошибка на втором ПК не вызвана
переписанной Free Look ступенью. При подтверждённо чистой подготовке её не
удалось воспроизвести; без фактического SHA-256 файла со второго ПК нельзя
установить, был ли использован другой WorkRoot или файл изменился после
подготовки. Теперь patcher печатает фактический hash и все допустимые состояния
до отказа, сохраняя WorkRoot и последний рабочий пакет.
