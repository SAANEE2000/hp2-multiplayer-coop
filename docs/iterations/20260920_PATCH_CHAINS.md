# Последовательные source patches и nullable presentation callbacks

Commit: commit, содержащий этот файл. Branch: `coop`.

Changed files: apply_patches.py, Build.ps1, test_patch_recipes.py,
coop-presentation-guards.json.

Why: второй рецепт меняет harry.uc после восстановления оригинального gameplay.
Последовательные отдельные запуски старого applier переставали быть идемпотентными:
итоговый hash второго рецепта не был известен первому. Build теперь передаёт полный
batch; цепь source→result определяется хешами, независимо от имён JSON.

Все targets/chains/backups проверяются до первой записи. Признаются чистое,
промежуточное и конечное состояния; fork/gap/merge/cycle и незнакомый hash вызывают
отказ. Для каждого реально применённого шага сохраняется отдельный predecessor
backup. Replacement атомарен для одного файла; whole-batch rollback при отказе
файловой системы не заявляется. Сборка прерывается при ошибке applier.

Guard recipe сохраняет landing damage/noise/pad behavior: optional
HearHarryRecipient и SpongifyFX проверяются на None, два cursor range updates
выполняются только для owning viewport. Это не полная адаптация движения.

Build: PASS совместной сборки `20260920-162258-321`, 0 errors/268 warnings.
Automated/local tests:19 cases,18 PASS/1 SKIP (Windows symlink privilege),
включая реальные рецепты, hash order, partial resume, unchanged final, tampering,
escaping paths/backup names и позднюю ошибку без записи предыдущих targets.
PowerShell5/7 parser проверки Build прошли. В development применены hash-checked
изменения, исходная installation не изменена.

2-PC tests required: обычные landing/Spongify/footstep/Basilisk listener регрессии.
Unconfirmed: сетевые special states, весь single-player gameplay и collision.
Next step: authoritative falling bookkeeping и special-movement context.
