Бэкап скрипта для бутстрапа и запуска acceptance тестов для одного специфичного демо codeception.

Можно изменить поведение через переменные:

```bash
CODECEPT_BOOTSTRAP_WEBDRIVER='' отключение запуска webdriver или замена его на другой
CODECEPT_BOOTSTRAP_PATH='./vendor/bin/codecept' другой способ запуска codecept, например из composer
CODECEPT_BOOTSTRAP_DISABLE_BACKUP=1 отключение бэкапов в базу (если выполняются вручную или на другом сервере)
CODECEPT_BOOTSTRAP_DB_BACKUP="docker-compose exec php /path/to/yiic projnameTesting backup"
CODECEPT_BOOTSTRAP_DB_RESTORE="docker-compose -f ~/docker-compose.yml exec php yiic projnameTesting restore"
```

Запускать можно через симлинк в директории проекта (добавить в .gitignore):

    ln -s ~/tools/codeception/run_tests.sh ~/src/yii-project/protected/run_tests
