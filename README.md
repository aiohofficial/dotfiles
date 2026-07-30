# dotfiles

Личная конфигурация машин (Windows + Linux/WSL), управляется через [chezmoi](https://www.chezmoi.io/).
Репозиторий: https://github.com/aiohofficial/dotfiles

## Структура

- `.chezmoiroot` - реальное состояние лежит в `home/`, а не в корне репозитория.
  Всё снаружи `home/` (этот README, `update-packages.ps1`, `update-brewfile.sh`) chezmoi не трогает.
- `home/packages.config` - нативный экспорт Chocolatey (`choco export`), Windows.
- `home/requirements.txt` - нативный формат pip (`pip list --not-required --format=freeze`), Windows.
- `home/Brewfile` - нативный формат Homebrew (`brew bundle dump`), Linux.
  Все три - прямое отражение того, что реально стоит на машине, не куратируется вручную.
- `home/.chezmoiignore` - все три файла выше исключены из применения как обычные таргеты
  (иначе chezmoi попытался бы создать их копии в домашней папке). Там же условия по ОС:
  `.chezmoiscripts/windows/**` игнорируется не на Windows, `.chezmoiscripts/linux/**` -
  не на Linux, чтобы один репозиторий корректно работал на обеих платформах.
- `home/.chezmoiscripts/windows/` - run_onchange_-скрипты, ставящие пакеты через
  `choco install packages.config -y` и `pip install -r requirements.txt`.
- `home/.chezmoiscripts/linux/` - четыре скрипта. `before_`/`after_` - это реальные фазы
  выполнения chezmoi (before - до применения файлов, after - после), а не просто текст;
  сортировка по номеру идёт внутри каждой фазы отдельно:
  - `run_once_before_00-update-system.sh.tmpl` - `apt update && apt upgrade` (только один раз)
  - `run_once_before_01-install-homebrew.sh.tmpl` - ставит сам Homebrew, если его нет
  - `run_onchange_after_01-install-packages.sh.tmpl` - `brew bundle` по `Brewfile`
  - `run_once_after_02-setup-zsh.sh.tmpl` - ставит zsh, делает его шеллом по умолчанию,
    убирает Oh My Zsh если стоял раньше (используем zplug вместо него, см. `dot_zshrc`)
- `home/dot_zshrc` - только на Linux (исключён из `.chezmoiignore` не-Linux). Минимальный,
  собранный вручную набор: zplug как менеджер плагинов, тема powerlevel10k, несколько
  библиотечных кусков oh-my-zsh (`from:oh-my-zsh`, без всего фреймворка) и точечные
  плагины (autosuggestions, fast-syntax-highlighting, completions, history-substring-search,
  you-should-use). Сознательно не чужой готовый `.zshrc` целиком - там было много
  специфичного под другой дистрибутив/десктоп (ALT Linux, GUI-алиасы, чужой юзернейм).
- `update-packages.ps1` / `update-brewfile.sh` (корень репозитория) - перегенерируют
  соответствующие файлы из текущего реального состояния машины. Экспорт (эта машина -> файл)
  и применение (файл -> любая машина через `chezmoi apply`) - два независимых по времени действия.
- `~/.config/chezmoi/chezmoi.toml` - **машинный** конфиг для Windows, не часть этого репозитория.
  Разрешает chezmoi запускать свои .ps1-скрипты (без него `apply` падает с "файл не
  имеет цифровой подписи" - Windows по умолчанию блокирует неподписанные скрипты).
  Нужно создавать заново на каждой новой Windows-машине, см. ниже.

## Как этим пользоваться

Поставил что-то новое и хочешь зафиксировать это в репозитории:

```powershell
# Windows
.\update-packages.ps1
git add home/packages.config home/requirements.txt
git commit -m "update packages"
```

```bash
# Linux
./update-brewfile.sh
git add home/Brewfile
git commit -m "update packages"
```

Ничего руками в этих файлах не редактируем - они всегда генерируются заново целиком
(choco export, pip freeze, brew bundle dump сами понимают свой формат, custom-парсинг не нужен).

## Основные команды

```bash
chezmoi diff    # показать, что изменится, ничего не применяя
chezmoi apply   # применить изменения по-настоящему
```

**Важно (Windows):** `choco install` обычно требует прав администратора. Запускай
`chezmoi apply` из PowerShell, открытого от имени администратора - иначе
установка пакетов может не пройти или зависнуть на UAC-запросе.

**Важно (Linux):** установка zsh и смена шелла (`run_once_after_02-setup-zsh.sh.tmpl`)
делаются через `sudo` - при первом `chezmoi apply` спросит пароль, это нормально.

## Установка на новой машине (Windows)

Все команды - в PowerShell от имени администратора.

1. Поставить сам Chocolatey (если его ещё нет на машине):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iwr https://community.chocolatey.org/install.ps1 -UseBasicParsing | iex
```

2. Поставить chezmoi:

```powershell
choco install chezmoi -y
```

3. Разрешить chezmoi запускать свои скрипты - без этого шага `apply` упадёт с
   "файл не имеет цифровой подписи" (Windows по умолчанию блокирует неподписанные
   .ps1). Это машинный конфиг, он не приходит вместе с репозиторием:

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\chezmoi" | Out-Null
$toml = @'
[interpreters.ps1]
    command = "powershell"
    args = ["-NoLogo", "-ExecutionPolicy", "Bypass", "-File"]
'@
[System.IO.File]::WriteAllText("$env:USERPROFILE\.config\chezmoi\chezmoi.toml", $toml, (New-Object System.Text.UTF8Encoding $false))
```

4. Применить дотфайлы:

```powershell
chezmoi init --apply https://github.com/aiohofficial/dotfiles.git
```

5. Доставить окружение для pre-commit/checkov (pip-инструменты из `requirements.txt`
   без этого либо не находятся по голому имени, либо падают на кириллице в .tf-файлах
   с `UnicodeDecodeError: 'charmap' codec` - русская локаль Windows по умолчанию читает
   файлы как cp1251, а не UTF-8):

```powershell
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$scriptsDir = "$env:USERPROFILE\AppData\Local\Programs\Python\Python312\Scripts"
if ($userPath -notlike "*$scriptsDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$userPath;$scriptsDir", "User")
}
[Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
```

(Шаги 3 и 5 требуют нового окна терминала, чтобы изменения подхватились.)

## Установка на новой машине (Linux/WSL)

```bash
sh -c "$(curl -fsLS get.chezmoi.io)"
~/bin/chezmoi init --apply https://github.com/aiohofficial/dotfiles.git
```

Всё остальное (Homebrew, инструменты из `Brewfile`, zsh) ставится автоматически
через `.chezmoiscripts/linux/` при первом `apply`. Попросит sudo-пароль один раз
(для установки zsh и смены шелла).
