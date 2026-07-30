# Перегенерирует packages.config и requirements.txt из реального состояния машины.
# Запускать вручную, когда хочешь зафиксировать текущий набор пакетов в репозитории.
choco export (Join-Path $PSScriptRoot "home\packages.config") --include-version-numbers
py -m pip list --not-required --format=freeze | Out-File -FilePath (Join-Path $PSScriptRoot "home\requirements.txt") -Encoding utf8
Write-Host "Обновлено: home/packages.config и home/requirements.txt"