# Система Управления Электронной Очередью
## Инструкция по Установке и Развертыванию

### 📋 Требования к системе

#### Минимальные требования:
- **ОС**: Ubuntu 22.04/24.04 LTS или Debian 11/12
- **Процессор**: 2 ядра
- **Память**: 4 GB RAM
- **Диск**: 20 GB свободного места
- **Сеть**: Стабильное интернет-соединение

#### Рекомендуемые требования:
- **ОС**: Ubuntu 24.04 LTS
- **Процессор**: 4+ ядер
- **Память**: 8+ GB RAM
- **Диск**: 50+ GB SSD
- **Сеть**: Выделенный IP-адрес

### 🚀 Быстрая установка

#### 1. Загрузка системы
```bash
# Клонирование репозитория
git clone https://github.com/your-repo/electronic-queue.git
cd electronic-queue

# Или загрузка архива
wget https://your-server.com/electronic-queue.zip
unzip electronic-queue.zip
cd electronic-queue
```

#### 2. Запуск автоматической установки
```bash
# Дайте права на выполнение
chmod +x deployment/complete-install.sh

# Запустите установщик
sudo deployment/complete-install.sh
```

Установщик запросит:
- Домен (оставьте пустым для локальной установки)
- Email для SSL сертификата (если указан домен)
- Пароль для базы данных
- Установку Ollama AI (опционально)
- Установку RHVoice (рекомендуется)
- Поддержку электронных табло (опционально)

### 📦 Компоненты системы

#### Основные модули:
1. **Веб-бронирование** - `/` - Онлайн запись на прием
2. **Терминал** - `/terminal` - Выдача талонов
3. **Оператор** - `/operator` - Рабочее место оператора
4. **Табло** - `/display` - Информационное табло
5. **Администратор** - `/admin` - Панель управления

#### Технологический стек:
- **Frontend**: React 18, TypeScript, TailwindCSS
- **Backend**: Node.js 20, Express.js
- **База данных**: PostgreSQL 16
- **Real-time**: WebSocket
- **Голос**: RHVoice (русские голоса)
- **AI**: Ollama (опционально)

### 🔧 Ручная установка

#### 1. Обновление системы
```bash
sudo apt update && sudo apt upgrade -y
```

#### 2. Установка PostgreSQL
```bash
# Добавление репозитория
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt update

# Установка
sudo apt install -y postgresql-16 postgresql-client-16

# Создание БД
sudo -u postgres psql
CREATE USER queue_user WITH PASSWORD 'your_password';
CREATE DATABASE queue_db OWNER queue_user;
\q
```

#### 3. Установка Node.js
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

#### 4. Установка приложения
```bash
# Создание директории
sudo mkdir -p /opt/electronic-queue
sudo chown $USER:$USER /opt/electronic-queue

# Копирование файлов
cp -r * /opt/electronic-queue/
cd /opt/electronic-queue

# Установка зависимостей
npm install

# Создание .env файла
cat > .env <<EOF
DATABASE_URL=postgresql://queue_user:your_password@localhost:5432/queue_db
PGHOST=localhost
PGPORT=5432
PGUSER=queue_user
PGPASSWORD=your_password
PGDATABASE=queue_db
NODE_ENV=production
PORT=5000
SESSION_SECRET=$(openssl rand -base64 32)
EOF

# Сборка приложения
npm run build

# Применение миграций
npm run db:push
```

#### 5. Настройка Nginx
```bash
sudo apt install -y nginx

# Создание конфигурации
sudo nano /etc/nginx/sites-available/electronic-queue
```

Содержимое конфигурации:
```nginx
upstream app_backend {
    server 127.0.0.1:5000;
}

server {
    listen 80;
    server_name your-domain.com;
    
    client_max_body_size 50M;
    
    location /ws {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

```bash
# Активация
sudo ln -s /etc/nginx/sites-available/electronic-queue /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

#### 6. Создание systemd сервиса
```bash
sudo nano /etc/systemd/system/electronic-queue.service
```

Содержимое:
```ini
[Unit]
Description=Electronic Queue System
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/electronic-queue
ExecStart=/usr/bin/node server/index.js
Restart=always
Environment="NODE_ENV=production"

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable electronic-queue
sudo systemctl start electronic-queue
```

### 🎙️ Установка RHVoice (голосовые объявления)

```bash
# Установка зависимостей
sudo apt install -y build-essential cmake libpulse-dev espeak-ng

# Клонирование и сборка
cd /tmp
git clone https://github.com/RHVoice/RHVoice.git
cd RHVoice
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc)
sudo make install
sudo ldconfig

# Загрузка русских голосов
cd /usr/local/share/RHVoice/voices
sudo wget https://github.com/RHVoice/RHVoice/releases/download/1.8.0/elena.zip
sudo unzip elena.zip
```

### 🤖 Установка Ollama (AI ассистент)

```bash
# Установка
curl -fsSL https://ollama.ai/install.sh | sh

# Загрузка моделей
ollama pull llama3.2:3b
ollama pull qwen2.5:3b

# Запуск сервиса
sudo systemctl enable ollama
sudo systemctl start ollama
```

### 📟 Настройка электронных табло

#### Подключение через COM-порт:
1. Подключите USB-COM адаптер
2. Проверьте порт: `ls -la /dev/ttyUSB*`
3. Добавьте пользователя в группу: `sudo usermod -aG dialout $USER`
4. Настройте табло в админ-панели

#### Протокол табло:
- Скорость: 9600 бод
- Формат: 8N1
- Команды: $E0 протокол

### 🔐 Безопасность

#### Настройка файрвола:
```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

#### SSL сертификат:
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### 📊 Мониторинг и обслуживание

#### Просмотр логов:
```bash
# Логи приложения
sudo journalctl -u electronic-queue -f

# Логи Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Логи PostgreSQL
sudo tail -f /var/log/postgresql/postgresql-16-main.log
```

#### Резервное копирование:
```bash
# Создание резервной копии БД
pg_dump -U queue_user queue_db > backup_$(date +%Y%m%d).sql

# Восстановление из резервной копии
psql -U queue_user queue_db < backup_20250110.sql
```

#### Обновление системы:
```bash
cd /opt/electronic-queue
git pull origin main
npm install
npm run build
npm run db:push
sudo systemctl restart electronic-queue
```

### 🖥️ Доступ к системе

После успешной установки система доступна:

- **Локально**: http://localhost:5000
- **По домену**: http://your-domain.com

#### Модули системы:
- Бронирование: `/`
- Терминал: `/terminal`
- Оператор: `/operator`
- Табло: `/display`
- Администратор: `/admin`

### ❓ Решение проблем

#### Проблема: Не запускается приложение
```bash
# Проверка статуса
sudo systemctl status electronic-queue

# Проверка портов
sudo netstat -tlnp | grep 5000

# Перезапуск
sudo systemctl restart electronic-queue
```

#### Проблема: Ошибка подключения к БД
```bash
# Проверка PostgreSQL
sudo systemctl status postgresql

# Проверка подключения
psql -U queue_user -d queue_db -h localhost

# Проверка прав
sudo -u postgres psql
\du
\l
```

#### Проблема: Не работает голос
```bash
# Проверка RHVoice
RHVoice-test -l

# Проверка espeak
espeak-ng --version

# Тест голоса
echo "Тест голоса" | RHVoice-test -p elena
```

### 📞 Поддержка

При возникновении проблем:
1. Проверьте логи системы
2. Обратитесь к документации
3. Создайте issue на GitHub
4. Свяжитесь с технической поддержкой

### 📄 Лицензия

Система распространяется под лицензией MIT.

---

© 2025 Система Управления Электронной Очередью