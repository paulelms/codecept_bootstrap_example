#!/usr/bin/env bash

### Переходим в директорию скрипта (где лежит codeception.yml)
#cd "$(dirname "$0")" || exit 1 # не работает в bash for windows
cd "${0%/*}" || exit 1 # работает в bash for windows
#cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" || exit 1 # symlink-safe версия (если сам скрипт лежит в директории проекта)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if [ ! -f "./codeception.yml" ] || [ ! -f "./yiic" ]; then
  echo -e "${RED}В директории нет файла yiic или codeception.yml:${NC} codeception не настроен в проекте или запуск не через симлинк run_tests на run_tests.sh из protected директории проекта, например:"
  echo "ln -s ~/tools/codeception/run_tests.sh ~/src/yii-project/protected/run_tests"
  echo "Запускать через симлинк"
  exit 1
fi

PROJECT="$(basename "$(dirname "$(dirname "$0")")")"

### kill background webdriver on exit
trap "exit" INT TERM # trap "exit" INT TERM ERR
trap "kill 0" EXIT

### Команда запуска webdriver для acceptance тестов
[[ ! -v CODECEPT_BOOTSTRAP_WEBDRIVER ]] && WEBDRIVER="chromedriver --url-base=/wd/hub" || WEBDRIVER="${CODECEPT_BOOTSTRAP_WEBDRIVER}"

### Автоматические бэкапы тестовой базы для acceptance тестов
[[ ! -v CODECEPT_BOOTSTRAP_DB_BACKUP ]] && DB_BACKUP="./yiic ${PROJECT}testing backup" || DB_BACKUP="${CODECEPT_BOOTSTRAP_DB_BACKUP}"
[[ ! -v CODECEPT_BOOTSTRAP_DB_RESTORE ]] && DB_RESTORE="./yiic ${PROJECT}testing restore" || DB_RESTORE="${CODECEPT_BOOTSTRAP_DB_RESTORE}"

### Обрабатываем переданные опциональные параметры
[[ ! -z $1 ]] && namespace="$1" || namespace=""
[[ ! -z $2 ]] && test="$2" || test=""

function run_webdriver() {
  if [[ ! -z $WEBDRIVER ]]; then
    if command -v $WEBDRIVER 2>/dev/null; then
        $WEBDRIVER &
    else
        webdriver_install_instructions
        exit 1
    fi
  fi
}

function webdriver_install_instructions() {
  echo -e "${RED}Необходимо установить webdriver, ${NC}рекомендуемый: chromedriver"
  echo "http://chromedriver.chromium.org"
  echo ""

  if [[ "$OSTYPE" == "linux-gnu" ]]; then
          echo "Ubuntu/Debian/etc.: apt-get install chromium-chromedriver"
          echo "ArchLinux/Manjaro/etc.: pacman -S chromium"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
          echo "MacOS: brew install chromedriver"
  elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
          echo "Windows: choco install chromedriver"
  elif [[ "$OSTYPE" == "freebsd"* ]]; then
          echo "FreeBSD: нет примера установки для этой ОС"
  else
          echo "Не получилось определить вашу ОС, ищите инструкцию по установке на сайте chromedriver"
  fi

  echo ""
  echo -e "${RED}Внимание: ${NC}чтобы запустить ${GREEN}acceptance${NC} тесты без установки webdriver, используйте пустой webdriver: CODECEPT_BOOTSTRAP_WEBDRIVER='' ./run_tests.sh"
  echo "Так же вы можете указать свою команду запуска webdriver в переменной среды CODECEPT_BOOTSTRAP_WEBDRIVER (можно сохранить в конфиг или для сеанса)"
  echo -e "Для запуска ${GREEN}unit-тестов${NC} это не требуется"
}

function composer_install_instructions() {
  if [[ "$OSTYPE" == "linux-gnu" ]]; then
          echo "Ubuntu/Debian: apt-get install composer"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
          echo "MacOS: brew install composer"
  elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
          echo "Windows: choco install composer"
  else
          echo "https://getcomposer.org/download/"
  fi
}

function run_test() {
  [[ $1 == "acceptance" ]] && check_local_params_file
  [[ $1 == "acceptance" ]] && run_webdriver # запускаем webdriver для acceptance тестов
  if [[ $1 == "acceptance" ]] && [[ ! -v CODECEPT_BOOTSTRAP_DISABLE_BACKUP ]]; then $DB_BACKUP || backup_error; fi

  $CODECEPT run --steps "${1}" "${2}"

  if [[ $1 == "acceptance" ]] && [[ ! -v CODECEPT_BOOTSTRAP_DISABLE_BACKUP ]]; then $DB_RESTORE || backup_error; fi
}

function backup_error() {
  echo -e "${RED}Тестовая БД не настроена, необходима её инициализация или ошибка бэкапа БД${NC}"
  echo "Можно выполнять команду бэкапов вручную, отключить её автоматический запуск переменной среды: CODECEPT_BOOTSTRAP_DISABLE_BACKUP=1"
  exit 1
}

function install_codecept_via_phar() {
  # В phar версии нет модуля, который мы используем в acceptance тестах: justblackbird/codeception-config-module
  # TODO: посмотреть другие модули для локальных параметров в последней версии codeception

  [[ -f "./codecept.phar" ]] && return

  if command -v wget 2>/dev/null; then
      wget https://codeception.com/codecept.phar -O codecept.phar
    elif command -v curl 2>/dev/null; then
      curl https://codeception.com/codecept.phar --output codecept.phar
    else
      echo "Не получилось загрузить codecept, скачайте codecept.phar вручную, или переопределите команду запуска в переменной среды: CODECEPT_BOOTSTRAP_PATH='./vendor/bin/codecept'"
      exit 1
    fi
    chmod +x ./codecept.phar
}

function install_codecept_via_composer() {
  if command -v composer 2>/dev/null; then
    composer global require codeception/codeception
    composer global require justblackbird/codeception-config-module
  else
    echo "composer не установлен глобально"
    composer_install_instructions
  fi
}

function check_local_params_file() {
  if [ ! -f "./tests/params.local.php" ]; then
    echo -e "${RED}Нет локального файла параметров: ${PROJECT}/protected/tests/params.local.php${NC}"
    echo "Подробнее:"
    echo "https://wiki.example.com/projects/projname/wiki/Codeception#Настройка-локальный-конфиг"
    echo "https://tracker.example.com/issue/4861"
    exit 1
  fi
}

if [[ -z "${CODECEPT_BOOTSTRAP_PATH}" ]]; then
  # install_codecept_via_composer && CODECEPT="${HOME}/.composer/vendor/bin/codecept"
  install_codecept_via_phar && CODECEPT="./codecept.phar"
else
  CODECEPT="${CODECEPT_BOOTSTRAP_PATH}"
fi

if [[ -z $namespace ]]; then # набор тестов по умолчанию
  run_test acceptance
#  run_test unit
else # запуска заданного namespace [и теста]
  run_test ${namespace} ${test}
fi
