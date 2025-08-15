-- Файл создания базы данных для системы электронной очереди
-- База данных: qs
-- Логин/пароль: admin/admin

-- Создание базы данных
CREATE DATABASE qs
    WITH 
    OWNER = admin
    ENCODING = 'UTF8'
    LC_COLLATE = 'ru_RU.UTF-8'
    LC_CTYPE = 'ru_RU.UTF-8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

-- Подключение к базе данных
\c qs;

-- Создание пользователя (если не существует)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'admin') THEN
        CREATE ROLE admin LOGIN PASSWORD 'admin';
    END IF;
END
$$;

-- Предоставление прав
GRANT ALL PRIVILEGES ON DATABASE qs TO admin;
ALTER USER admin CREATEDB;

-- Таблица отделений
CREATE TABLE IF NOT EXISTS departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    working_hours JSONB, -- {"monday": {"start": "09:00", "end": "18:00"}, ...}
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица услуг
CREATE TABLE IF NOT EXISTS services (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    estimated_time INTEGER DEFAULT 15, -- время в минутах
    department_id INTEGER REFERENCES departments(id),
    is_active BOOLEAN DEFAULT true,
    service_code VARCHAR(10) UNIQUE, -- A, B, C для типов услуг
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица операторов
CREATE TABLE IF NOT EXISTS operators (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    department_id INTEGER REFERENCES departments(id),
    window_number INTEGER,
    is_active BOOLEAN DEFAULT true,
    role VARCHAR(50) DEFAULT 'operator', -- operator, admin, supervisor
    password_hash VARCHAR(255), -- для аутентификации
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица предварительных записей
CREATE TABLE IF NOT EXISTS appointments (
    id SERIAL PRIMARY KEY,
    service_id INTEGER REFERENCES services(id),
    department_id INTEGER REFERENCES departments(id),
    client_name VARCHAR(255) NOT NULL,
    client_phone VARCHAR(20),
    client_email VARCHAR(255),
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    pin_code VARCHAR(10) UNIQUE NOT NULL, -- PIN для поиска записи
    status VARCHAR(20) DEFAULT 'scheduled', -- scheduled, confirmed, completed, cancelled, no_show
    additional_info TEXT,
    notify_sms BOOLEAN DEFAULT false,
    notify_email BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица талонов (выданных в терминале и по записи)
CREATE TABLE IF NOT EXISTS tickets (
    id SERIAL PRIMARY KEY,
    ticket_number VARCHAR(10) NOT NULL, -- A-15, B-08, etc.
    service_id INTEGER REFERENCES services(id),
    department_id INTEGER REFERENCES departments(id),
    appointment_id INTEGER REFERENCES appointments(id), -- NULL если талон без записи
    status VARCHAR(20) DEFAULT 'waiting', -- waiting, called, serving, completed, missed
    priority INTEGER DEFAULT 0, -- 0-обычный, 1-льготный
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    called_at TIMESTAMP,
    served_at TIMESTAMP,
    completed_at TIMESTAMP,
    operator_id INTEGER REFERENCES operators(id),
    estimated_wait_time INTEGER, -- в минутах
    actual_wait_time INTEGER -- в минутах
);

-- Таблица истории вызовов
CREATE TABLE IF NOT EXISTS call_history (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER REFERENCES tickets(id),
    operator_id INTEGER REFERENCES operators(id),
    called_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    call_type VARCHAR(20) DEFAULT 'first_call', -- first_call, repeat_call
    response VARCHAR(20) -- came, no_response
);

-- Таблица оценок обслуживания
CREATE TABLE IF NOT EXISTS service_ratings (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER REFERENCES tickets(id),
    operator_id INTEGER REFERENCES operators(id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица настроек системы
CREATE TABLE IF NOT EXISTS system_settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица для логирования ИИ-запросов
CREATE TABLE IF NOT EXISTS ai_chat_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER, -- ID пользователя (оператора/админа)
    user_type VARCHAR(20), -- operator, admin
    query TEXT NOT NULL,
    response TEXT NOT NULL,
    model_used VARCHAR(50), -- llama3, mistral, etc.
    processing_time INTEGER, -- время обработки в мс
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица пользователей (для совместимости)
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL
);

-- Индексы для оптимизации
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_service ON tickets(service_id);
CREATE INDEX IF NOT EXISTS idx_tickets_date ON tickets(issued_at);
CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(appointment_date);
CREATE INDEX IF NOT EXISTS idx_appointments_pin ON appointments(pin_code);
CREATE INDEX IF NOT EXISTS idx_operators_department ON operators(department_id);

-- Функция для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Триггеры для автоматического обновления updated_at
CREATE TRIGGER update_departments_updated_at BEFORE UPDATE ON departments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_services_updated_at BEFORE UPDATE ON services
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_operators_updated_at BEFORE UPDATE ON operators
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_appointments_updated_at BEFORE UPDATE ON appointments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Функция генерации PIN-кода
CREATE OR REPLACE FUNCTION generate_pin_code()
RETURNS VARCHAR(10) AS $$
DECLARE
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    result TEXT := '';
    i INTEGER;
BEGIN
    -- Генерируем формат AB-1234
    result := substr(chars, (random() * 25)::int + 1, 1) || 
              substr(chars, (random() * 25)::int + 1, 1) || '-';
    
    FOR i IN 1..4 LOOP
        result := result || substr('0123456789', (random() * 9)::int + 1, 1);
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Функция генерации номера талона
CREATE OR REPLACE FUNCTION generate_ticket_number(service_code VARCHAR(10))
RETURNS VARCHAR(10) AS $$
DECLARE
    next_number INTEGER;
    result VARCHAR(10);
BEGIN
    -- Получаем следующий номер для данного типа услуги на сегодня
    SELECT COALESCE(MAX(CAST(SUBSTRING(ticket_number FROM '[0-9]+') AS INTEGER)), 0) + 1
    INTO next_number
    FROM tickets 
    WHERE ticket_number LIKE service_code || '-%'
    AND DATE(issued_at) = CURRENT_DATE;
    
    result := service_code || '-' || LPAD(next_number::TEXT, 2, '0');
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Вставка начальных данных

-- Отделения
INSERT INTO departments (name, address, phone, working_hours) VALUES
('Центральное отделение', 'ул. Главная, 1', '+7 (999) 123-45-67', 
 '{"monday": {"start": "09:00", "end": "18:00"}, "tuesday": {"start": "09:00", "end": "18:00"}, "wednesday": {"start": "09:00", "end": "18:00"}, "thursday": {"start": "09:00", "end": "18:00"}, "friday": {"start": "09:00", "end": "18:00"}, "saturday": {"start": "10:00", "end": "16:00"}, "sunday": {"closed": true}}'),
('Филиал №1', 'ул. Ленина, 50', '+7 (999) 123-45-68', 
 '{"monday": {"start": "09:00", "end": "17:00"}, "tuesday": {"start": "09:00", "end": "17:00"}, "wednesday": {"start": "09:00", "end": "17:00"}, "thursday": {"start": "09:00", "end": "17:00"}, "friday": {"start": "09:00", "end": "17:00"}, "saturday": {"closed": true}, "sunday": {"closed": true}}'),
('Филиал №2', 'ул. Советская, 25', '+7 (999) 123-45-69', 
 '{"monday": {"start": "10:00", "end": "18:00"}, "tuesday": {"start": "10:00", "end": "18:00"}, "wednesday": {"start": "10:00", "end": "18:00"}, "thursday": {"start": "10:00", "end": "18:00"}, "friday": {"start": "10:00", "end": "18:00"}, "saturday": {"start": "10:00", "end": "15:00"}, "sunday": {"closed": true}}');

-- Услуги
INSERT INTO services (name, description, estimated_time, department_id, service_code) VALUES
('Получение справки', 'Выдача различных справок', 15, 1, 'A'),
('Подача документов', 'Подача документов на рассмотрение', 25, 1, 'B'),
('Консультация', 'Консультация по вопросам', 10, 1, 'C'),
('Выдача готовых документов', 'Получение готовых документов', 5, 1, 'D'),
('Получение справки', 'Выдача различных справок', 15, 2, 'A'),
('Консультация', 'Консультация по вопросам', 10, 2, 'C');

-- Операторы
INSERT INTO operators (first_name, last_name, email, phone, department_id, window_number, role, password_hash) VALUES
('Анна', 'Иванова', 'anna@example.com', '+7 (999) 111-11-11', 1, 1, 'operator', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeVMpv4qV8VQRRoC6'), -- пароль: password123
('Иван', 'Петров', 'ivan@example.com', '+7 (999) 111-11-12', 1, 2, 'operator', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeVMpv4qV8VQRRoC6'),
('Мария', 'Сидорова', 'maria@example.com', '+7 (999) 111-11-13', 1, 3, 'operator', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeVMpv4qV8VQRRoC6'),
('Администратор', 'Системы', 'admin@example.com', '+7 (999) 000-00-00', 1, NULL, 'admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeVMpv4qV8VQRRoC6');

-- Настройки системы
INSERT INTO system_settings (key, value, description) VALUES
('max_daily_appointments', '50', 'Максимальное количество записей в день'),
('default_appointment_duration', '15', 'Стандартная продолжительность приема в минутах'),
('notification_enabled', 'true', 'Включить уведомления'),
('voice_announcement', 'true', 'Включить голосовые объявления'),
('ai_model', 'llama3', 'Используемая модель ИИ'),
('ai_temperature', '0.7', 'Температура для ИИ модели'),
('working_hours_start', '09:00', 'Начало рабочего дня'),
('working_hours_end', '18:00', 'Конец рабочего дня');

-- Тестовые данные для демонстрации

-- Предварительные записи
INSERT INTO appointments (service_id, department_id, client_name, client_phone, client_email, appointment_date, appointment_time, pin_code, notify_sms, notify_email) VALUES
(1, 1, 'Иванов Иван Иванович', '+7 (999) 555-55-55', 'ivanov@email.com', CURRENT_DATE, '10:00', 'AB-1234', true, true),
(2, 1, 'Петров Петр Петрович', '+7 (999) 555-55-56', 'petrov@email.com', CURRENT_DATE, '11:00', 'CD-5678', true, false),
(1, 1, 'Сидорова Мария Александровна', '+7 (999) 555-55-57', 'sidorova@email.com', CURRENT_DATE + 1, '09:30', 'EF-9012', false, true);

-- Талоны (текущие)
INSERT INTO tickets (ticket_number, service_id, department_id, appointment_id, status, operator_id, issued_at) VALUES
('A-15', 1, 1, NULL, 'serving', 1, CURRENT_TIMESTAMP - INTERVAL '5 minutes'),
('B-08', 2, 1, NULL, 'called', 2, CURRENT_TIMESTAMP - INTERVAL '15 minutes'),
('C-12', 3, 1, NULL, 'waiting', NULL, CURRENT_TIMESTAMP - INTERVAL '3 minutes'),
('A-16', 1, 1, 1, 'waiting', NULL, CURRENT_TIMESTAMP - INTERVAL '1 minute');

-- Оценки обслуживания
INSERT INTO service_ratings (ticket_id, operator_id, rating, comment) VALUES
(1, 1, 5, 'Отличное обслуживание, быстро и качественно'),
(2, 2, 4, 'Хорошо, но немного долго ждал');

-- История вызовов
INSERT INTO call_history (ticket_id, operator_id, called_at, call_type, response) VALUES
(1, 1, CURRENT_TIMESTAMP - INTERVAL '5 minutes', 'first_call', 'came'),
(2, 2, CURRENT_TIMESTAMP - INTERVAL '10 minutes', 'first_call', 'came');

-- Логи ИИ чата
INSERT INTO ai_chat_logs (user_id, user_type, query, response, model_used, processing_time) VALUES
(4, 'admin', 'Покажи статистику за сегодня', 'Статистика за 15.01.2024: Обслужено: 156 клиентов, Среднее время ожидания: 12 мин, Самая популярная услуга: Получение справок (45%), Пиковое время: 10:00-12:00. Рекомендация: Добавить дополнительного оператора с 9:30 до 12:30', 'llama3', 1250),
(1, 'operator', 'Какие документы нужны для справки?', 'Для получения справки обычно требуются: паспорт, заявление установленного образца. В зависимости от типа справки могут потребоваться дополнительные документы.', 'llama3', 800);

-- Предоставление всех прав пользователю admin
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO admin;

-- Комментарии к таблицам для документации
COMMENT ON TABLE departments IS 'Отделения/филиалы организации';
COMMENT ON TABLE services IS 'Услуги, предоставляемые в отделениях';
COMMENT ON TABLE operators IS 'Операторы системы (сотрудники)';
COMMENT ON TABLE appointments IS 'Предварительные записи через веб-интерфейс';
COMMENT ON TABLE tickets IS 'Талоны, выданные в терминале или по записи';
COMMENT ON TABLE call_history IS 'История вызовов клиентов';
COMMENT ON TABLE service_ratings IS 'Оценки качества обслуживания';
COMMENT ON TABLE system_settings IS 'Настройки системы';
COMMENT ON TABLE ai_chat_logs IS 'Логи взаимодействия с ИИ-помощником';

-- Вывод информации о созданной базе
SELECT 'База данных "qs" успешно создана и настроена!' as status;
SELECT 'Пользователь: admin, Пароль: admin' as credentials;
SELECT 'Запуск: psql -h localhost -U admin -d qs' as connection_string;
