#!/bin/bash

set -e

# Установка Node.js и npm
apt update
apt install nodejs npm -y

# Путь до директории приложения
APP_DIR="/opt/sing-box-ui/file-api"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Инициализация Node.js-проекта и установка зависимостей
npm init -y
npm install express cors

# Создание index.js
cat << 'EOF' > index.js
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const port = 8000;

const BASE_DIR = "/etc/sing-box";

app.use(cors());
app.use(express.json());

function resolveSafePath(inputPath) {
    const fullPath = path.resolve(BASE_DIR, inputPath);
    if (!fullPath.startsWith(BASE_DIR)) {
        throw new Error("Access denied");
    }
    return fullPath;
}

app.get('/file', (req, res) => {
    try {
        const relative = req.query.path || '';
        const filePath = resolveSafePath(relative);

        if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
            return res.status(404).json({ error: 'File not found' });
        }

        const content = fs.readFileSync(filePath, 'utf-8');
        res.json({ content });
    } catch (e) {
        res.status(403).json({ error: e.message });
    }
});

app.post('/file', (req, res) => {
    try {
        const relative = req.query.path || '';
        const filePath = resolveSafePath(relative);

        if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
            return res.status(404).json({ error: 'File not found' });
        }

        fs.writeFileSync(filePath, req.body.content);
        res.json({ status: 'ok' });
    } catch (e) {
        res.status(403).json({ error: e.message });
    }
});

app.get('/list', (req, res) => {
    try {
        const relative = req.query.path || '';
        const targetPath = resolveSafePath(relative);

        if (!fs.existsSync(targetPath) || !fs.statSync(targetPath).isDirectory()) {
            return res.status(404).json({ error: 'Directory not found' });
        }

        const entries = fs.readdirSync(targetPath).map(name => {
            const fullPath = path.join(targetPath, name);
            const stat = fs.statSync(fullPath);
            return {
                name: name,
                type: stat.isDirectory() ? 'directory' : 'file'
            };
        });

        res.json({ files: entries });
    } catch (e) {
        res.status(403).json({ error: e.message });
    }
});

app.listen(port, () => {
    console.log(`API running at http://0.0.0.0:${port}`);
});
EOF

# Создание systemd-сервиса, запускаемого от root
cat << EOF > /etc/systemd/system/singbox-file-api.service
[Unit]
Description=Sing-box File API
After=network.target

[Service]
ExecStart=/usr/bin/node $APP_DIR/index.js
Restart=always
Environment=NODE_ENV=production
WorkingDirectory=$APP_DIR

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd и запуск сервиса
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable singbox-file-api.service
systemctl start singbox-file-api.service

echo "✅ API установлен и работает от root на http://0.0.0.0:8000"
