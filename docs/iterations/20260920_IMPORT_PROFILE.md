# Подготовка второго ПК без локальной сборки

Commit: commit с этим файлом. Branch: `coop`.
Changed files: Prepare-LocalGame, Export-TestBuild, тесты подготовки/переноса.

Why: до изменения только Build.ps1 менял ранний native UserFolder. Prepare→Import
на втором ПК мог оставить исходный профиль. Теперь Prepare изолирует Default.ini
и при новой копии, и при существующем marker; supplied backup сохраняется.
Исходная installation не меняется. Разделение двух одновременных development
клиентских save-профилей этим не решено.

Первый прогон Windows PowerShell5 выявил ещё старую ошибку: кириллический default
GameRoot в UTF8 без BOM разбирался как ANSI и ломал parser. Prepare сохранён UTF8
с BOM; реальные subprocess-тесты PowerShell5 теперь проходят.

Export сохраняет sourceDirty и SHA256 исходного source manifest. Build-time HEAD
при dirty inputs не называется точным source commit бинарника; binary identity
задаётся hash обоих пакетов. Re-export сохраняет provenance исходной сборки.

Build: последняя UCC162258-321 PASS/0errors/268warnings; игровой код здесь не менялся.
Automated/local tests: preparation3/3 PASS в PS7 и PS5; transfer9/9 PASS,
дополненный provenance roundtrip PASS. Проверены original bytes, backup,
идемпотентность, repair marker copy, отказ неоднозначного UserFolder до marker.
2-PC tests required: фактический Save Slot Path второго ПК после импорта.
Unconfirmed: изоляция каждого одновременно работающего клиента, настоящий save/load.
Next step: runtime fingerprints и компактная инструкция пользователю.
