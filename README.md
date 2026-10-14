# ДЗ 1. Фундамент DevOps-инфраструктуры

В этом задании использую локальный Docker, как указано в дополнении к ДЗ. Сначала Ansible настраивает Ubuntu, затем Terraform создаёт nginx, отдельную сеть и том. После этого запускается приложение через Compose.

Исходники подготовлены и проверены на уровне синтаксиса и конфигурации. Полный запуск пока не выполнен: на этой Windows-машине недоступны Docker Engine и WSL. Настоящих результатов `terraform apply`, второго запуска Ansible и HTTP-запросов пока нет. Подробности в [CHECKS.md](CHECKS.md).

## Что находится в проекте

- `terraform/` — nginx, сеть и именованный том.
- `ansible/` — настройка Ubuntu и развёртывание приложения.
- `compose/` — nginx-прокси и app со страницей Hello World.
- `scripts/monitor.sh` — проверка сервиса и ошибок в syslog.
- `evidence/` — результаты выполненных проверок; сюда же сохраняются результаты запуска.

| Окружение | Контейнеры | Сеть | Адрес на хосте Docker |
| --- | --- | --- | --- |
| Terraform | hw1_terraform_nginx | hw1_terraform_network | http://127.0.0.1:8081 |
| Compose | nginx, app | hw1_app_network | http://127.0.0.1:8080 |

Том `hw1_nginx_data` подключён к `/usr/share/nginx/html` в Terraform-контейнере. При первом подключении пустого тома Docker копирует в него стандартную страницу nginx. Том подключён только для чтения. Оба сервиса Compose работают в другой сети; app наружу порт не публикует.

## 1. Подготовить Ubuntu

Нужен Linux с systemd. Для обычного варианта подходит Ubuntu 22.04 в VirtualBox. Можно использовать Ubuntu в WSL, если там включён systemd. Установка Docker из этого playbook рассчитана на отдельный Docker Engine внутри Ubuntu: для этой Ubuntu нужно отключить интеграцию Docker Desktop.

Все команды ниже выполняются из корня `hw1_devops` в Linux. Папка на Windows находится в `C:\Users\nataa\Downloads\hw1_devops`; в WSL это `/mnt/c/Users/nataa/Downloads/hw1_devops`.

Проверить systemd и поставить инструменты для Ansible:

```bash
ps -p 1 -o comm=
sudo apt update
sudo apt install -y python3 python3-venv python3-pip openssh-client
python3 -m venv .venv
source .venv/bin/activate
python -m pip install 'ansible-core==2.17.14'
ansible-galaxy collection install -r ansible/requirements.yml -p work/collections
export ANSIBLE_COLLECTIONS_PATH="$PWD/work/collections"
mkdir -p ansible/keys evidence
ssh-keygen -t ed25519 -f ansible/keys/id_ed25519 -N ''
```

Версия Ansible выбрана для Python 3.10 из Ubuntu 22.04. Закрытый ключ, виртуальное окружение и временные файлы исключены из Git.

Для локального запуска используется `ansible/inventory_local.ini`. Для отдельной VM используется `ansible/inventory.ini`: в нём нужно указать её настоящий адрес, SSH-порт и начального пользователя с sudo. Сейчас там пример NAT-подключения `127.0.0.1:2222`, а не адрес созданной VM. Публичный ключ `ansible/keys/id_ed25519.pub` нужно добавить начальному пользователю VM. У SSH должны быть выключены вход по паролю и вход под root. В VirtualBox можно пробросить только SSH: адрес хоста 127.0.0.1, порт хоста 2222, порт гостя 22.

## 2. Сначала Ansible

Простой локальный запуск в Ubuntu:

```bash
set -o pipefail
ansible-playbook -i ansible/inventory_local.ini -K ansible/setup_host.yml | tee evidence/ansible-first.txt
ansible-playbook -i ansible/inventory_local.ini -K ansible/setup_host.yml | tee evidence/ansible-second.txt
```

Playbook создаёт пользователя deployer, добавляет ему sudo без пароля и доступ к Docker, устанавливает Docker Engine, Compose, gawk и rsyslog, включает автозапуск Docker и rsyslog. Публичный SSH-ключ копируется deployer; его пароль заблокирован.

Второй запуск нужно выполнить сразу после первого. В конце ожидается `changed=0`, `failed=0`. Это нужно проверить по настоящему выводу, а не считать результат заранее известным.

Для удалённой VM команды те же, но вместо `inventory_local.ini` используется `inventory.ini` и параметр `-K` заменяется на `-b` или `-K` в зависимости от настроек sudo начального пользователя. После настройки можно проверить SSH под deployer:

```bash
ssh -i ansible/keys/id_ed25519 -o UserKnownHostsFile=ansible/keys/known_hosts -p 2222 deployer@127.0.0.1
```

При другом адресе VM нужно заменить адрес и порт в этой команде.

## 3. Затем Terraform

Версия CLI должна быть не ниже 1.5; версия провайдера в проекте закреплена на 4.6.0. Terraform и Compose должны работать с тем Docker Engine, который настроил Ansible. Установка CLI из официального Linux-архива в папку проекта:

```bash
mkdir -p work/bin
curl -fL https://releases.hashicorp.com/terraform/1.13.5/terraform_1.13.5_linux_amd64.zip -o work/terraform.zip
python3 -m zipfile -e work/terraform.zip work/bin
chmod +x work/bin/terraform
work/bin/terraform version
```

Ниже локальный вариант внутри Ubuntu. `sudo` нужен для обращения к Docker socket из учётной записи, которая пока не входит в группу docker. У deployer доступ к Docker уже есть.

```bash
sudo work/bin/terraform -chdir=terraform init
sudo work/bin/terraform -chdir=terraform fmt -check
sudo work/bin/terraform -chdir=terraform validate
sudo work/bin/terraform -chdir=terraform plan -out=hw1.tfplan | tee evidence/terraform-plan.txt
sudo work/bin/terraform -chdir=terraform apply hw1.tfplan | tee evidence/terraform-apply.txt
sudo work/bin/terraform -chdir=terraform state list | tee evidence/terraform-state.txt
curl -i http://127.0.0.1:8081 | tee evidence/terraform-curl.txt
```

Успешный запрос должен показать `HTTP/1.1 200 OK`, заголовок `Server: nginx` и стандартную страницу nginx. Ожидаемые ресурсы в state:

```text
docker_container.nginx
docker_image.nginx
docker_network.nginx
docker_volume.nginx
```

`terraform.tfstate` хранится локально в `terraform/` и не отправляется в Git. После `init` файл `.terraform.lock.hcl` следует добавить в Git, чтобы сохранить выбранные версии и контрольные суммы. Не нужно удалять state: Terraform потеряет связь с созданными ресурсами.

Для Windows Docker Desktop значение `docker_host` можно поменять на `npipe:////./pipe/dockerDesktopLinuxEngine`, но это будет другой Docker Engine. Для этого варианта тоже нужно сначала выполнить часть Ansible на Linux; он не заменяет установку Docker Engine на Ubuntu.

## 4. Compose

Ansible копирует `compose/` в `/opt/app` и запускает два сервиса:

```bash
ansible-playbook -i ansible/inventory_local.ini -K ansible/deploy_app.yml
sudo docker compose -p hw1 -f /opt/app/docker-compose.yml ps | tee evidence/compose-ps.txt
curl -i http://127.0.0.1:8080 | tee evidence/compose-curl.txt
```

Ожидается `200 OK` и страница с текстом Hello World. nginx-прокси передаёт запрос в `app:80`; app находится по имени через Docker DNS. Удалённый вариант использует `inventory.ini`, а `ps` и `curl` нужно выполнить на VM.

Проверить разделение сетей и подключение тома:

```bash
sudo docker network inspect hw1_terraform_network hw1_app_network | tee evidence/networks.txt
sudo docker inspect hw1_terraform_nginx --format '{{json .Mounts}}' | tee evidence/volume.txt
```

В первой сети должен быть только Terraform-nginx, во второй — два контейнера Compose.

## 5. Мониторинг

```bash
chmod +x scripts/monitor.sh
sudo ./scripts/monitor.sh docker | tee evidence/monitor-local.txt
sudo ./scripts/monitor.sh service-that-does-not-exist
```

Скрипт проверяет сервис через systemctl. Если он неактивен, выводит последние десять записей journalctl. Затем grep отбирает строки с error из `/var/log/syslog`, а awk проверяет, попадают ли они в последний час. Считается количество строк, а не отдельных слов. Учитываются обычные даты syslog и ISO-даты. gawk нужен для функций времени; rsyslog создаёт файл syslog.

Для проверки на удалённой VM скопировать скрипт и запустить его через SSH под deployer. Например, для NAT-подключения:

```bash
scp -i ansible/keys/id_ed25519 -o UserKnownHostsFile=ansible/keys/known_hosts -P 2222 scripts/monitor.sh deployer@127.0.0.1:/home/deployer/monitor.sh
ssh -i ansible/keys/id_ed25519 -o UserKnownHostsFile=ansible/keys/known_hosts -p 2222 deployer@127.0.0.1 'sudo bash /home/deployer/monitor.sh docker' | tee evidence/monitor-remote.txt
```

Если сервис не найден или syslog недоступен, скрипт сообщает об этом и завершается с кодом 1. В пустом логе ошибок будет 0.

## 6. Git и сдача

Локальный репозиторий подготовлен с ветками `main` и `feature/infra-setup`. Выполнено само-ревью конфигураций и путей. Удалённый репозиторий и Pull Request ещё не созданы.

В GitHub/GitLab нужно создать пустой репозиторий, добавить его настоящий URL как origin и отправить обе ветки. Затем открыть Pull Request или Merge Request из feature/infra-setup в main. После проверки и мержа поставить тег:

```bash
git remote add origin URL_ВАШЕГО_РЕПОЗИТОРИЯ
git push -u origin main
git push -u origin feature/infra-setup
```

После мержа в GitHub/GitLab:

```bash
git switch main
git pull --ff-only
git tag -a v0.1.0 -m 'Homework 1'
git push origin v0.1.0
```

Перед сдачей сделать настоящие скриншоты `terraform state list`, второго запуска Ansible, monitor.sh, Compose ps и двух curl-запросов. Сохранить их в `evidence/` и вставить ссылки на изображения в README. Сейчас таких скриншотов нет, потому что развёртывание ещё не выполнено.

## Почему выбраны такие настройки

Docker-провайдер выбран по дополнению преподавателя. Поэтому Terraform не создаёт VPC, облачную VM, Security Group и IAM: эти объекты не входят в этот вариант задания. Linux для Ansible готовится отдельно.

Для nginx взят порт 8081, чтобы выполнить требование о нестандартном порте и не занимать 80. Порт 8080 используется для приложения. HTTP-порты доступны только на самом хосте Docker, поэтому для проверки с другого компьютера нужен SSH-туннель. Отдельные сети разделяют два окружения. Именованный том позволяет хранить файлы независимо от конкретного контейнера.

deployer нужен для развёртывания по SSH без входа под root. Sudo без пароля выдан по условию ДЗ; группа docker тоже даёт административные возможности. Это учебная учётная запись, а не аналог облачной IAM-роли с минимальными правами.

При проверке возникли ограничения Windows: WSL вернул E_ACCESSDENIED, Docker Engine не был доступен, а загрузка Terraform с releases.hashicorp.com вернула HTTP 404. Поэтому выполнены проверки файлов, но результаты развёртывания нужно получить на Linux.

## Короткие ответы для защиты

Ansible выполняет задачи по настройке системы, а Terraform описывает желаемые ресурсы и сравнивает их со state. State связывает код с настоящими ресурсами. Идемпотентность означает, что повторный запуск не меняет уже настроенную систему. Здесь она проверяется вторым запуском setup_host.yml. Для SSH используется ключ; HTTP-порты привязаны к loopback. Облачных Security Groups и IAM в Docker-варианте нет.

## Документация

- [Docker-провайдер Terraform](https://github.com/kreuzwerker/terraform-provider-docker)
- [Установка Docker на Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Тома Docker](https://docs.docker.com/engine/storage/volumes/)
- [Модуль Ansible для Compose](https://docs.ansible.com/projects/ansible/latest/collections/community/docker/docker_compose_v2_module.html)
- [Сети Compose](https://docs.docker.com/reference/compose-file/networks/)
