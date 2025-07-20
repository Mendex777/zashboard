<template>
  <div class="flex h-screen flex-col gap-2 p-2">
    <div class="card flex-1 flex flex-col">
      <div class="card-title px-4 pt-4">
        {{ $t('configEditor') }}
      </div>
      <div class="card-body" style="display: flex; flex-direction: column; flex: 1; overflow: auto;">
        <div id="apiStatus" class="api-status offline">
          <div class="status-indicator offline"></div>
          <span>Проверка соединения с API...</span>
        </div>

        <div id="fileButtons" class="file-buttons"></div>
        <textarea id="content" style="width: 100%; flex-grow: 1; min-height: 200px;"></textarea>
        <div class="button-container">
          <button class="save-button" @click="saveFile">Сохранить</button>
          <button class="download-button" @click="downloadCurrentConfig">Скачать текущий конфиг</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { activeBackend } from '@/store/setup'
import { computed } from 'vue'

// Глобальная переменная для хранения текущего файла
let currentFile = ''

// Динамический URL API с портом 8000
const apiBaseUrl = computed(() => {
  return `http://${activeBackend.value?.host}:8000`
})

// Функция для проверки доступности API
async function checkApiStatus() {
  const statusElement = document.getElementById('apiStatus')
  const statusIndicator = statusElement?.querySelector('.status-indicator')
  const statusText = statusElement?.querySelector('span')
  
  try {
    // Создаем контроллер для отмены запроса
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 5000)
    
    const url = `${apiBaseUrl.value}/list?path=`
    const res = await fetch(url, { 
      method: 'GET',
      signal: controller.signal
    })
    
    // Очищаем таймаут, если запрос успешно выполнен
    clearTimeout(timeoutId)
    
    if (res.ok) {
      // API доступен
      statusElement?.classList.remove('offline')
      statusElement?.classList.add('online')
      statusIndicator?.classList.remove('offline')
      statusIndicator?.classList.add('online')
      if (statusText) statusText.textContent = `API доступен (${apiBaseUrl.value})`
    } else {
      // API вернул ошибку
      statusElement?.classList.remove('online')
      statusElement?.classList.add('offline')
      statusIndicator?.classList.remove('online')
      statusIndicator?.classList.add('offline')
      if (statusText) statusText.textContent = `API недоступен (${apiBaseUrl.value}): ` + (await res.text())
    }
  } catch (error: Error | unknown) {
    // Ошибка соединения
    statusElement?.classList.remove('online')
    statusElement?.classList.add('offline')
    statusIndicator?.classList.remove('online')
    statusIndicator?.classList.add('offline')
    const errorMessage = error instanceof Error ? error.message : 'Ошибка соединения'
    if (statusText) statusText.textContent = `API недоступен (${apiBaseUrl.value}): ` + errorMessage
  }
}

// Функция для создания кнопок для предопределенных файлов
function createFileButtons() {
  const predefinedFiles = [
    'config.json',
    'manual.conf',
    'mode.conf',
    'rules/custom_list.json'
  ]
  
  const fileButtonsContainer = document.getElementById('fileButtons')
  if (fileButtonsContainer) fileButtonsContainer.innerHTML = ''
  
  // Создаем кнопки для предопределенных файлов
  predefinedFiles.forEach(filePath => {
    const fileButton = document.createElement('button')
    fileButton.className = 'file-button'
    
    // Получаем имя файла из пути
    const fileName = filePath.split('/').pop()
    fileButton.innerHTML = `📄 ${fileName}`
    
    fileButton.onclick = () => loadFile(filePath)
    fileButtonsContainer?.appendChild(fileButton)
  })
}

// Функция для загрузки содержимого файла
async function loadFile(path: string) {
  try {
    currentFile = path
    const res = await fetch(`${apiBaseUrl.value}/file?path=${encodeURIComponent(path)}`)
    const data = await res.json()
    
    if (res.ok) {
      const contentElement = document.getElementById('content') as HTMLTextAreaElement
      if (contentElement) contentElement.value = data.content
      
      // Выделяем активную кнопку
      const buttons = document.querySelectorAll('.file-button')
      buttons.forEach(button => {
        const htmlButton = button as HTMLElement
        htmlButton.style.backgroundColor = ''
        htmlButton.style.fontWeight = 'normal'
      })
      
      // Находим кнопку для текущего файла и выделяем её
      const fileName = path.split('/').pop()
      const activeButton = Array.from(buttons).find(button => button.textContent?.includes(fileName || ''))
      if (activeButton) {
        // Используем тот же цвет, что и у download-button
        const htmlActiveButton = activeButton as HTMLElement
        htmlActiveButton.style.backgroundColor = '#2c3e50'
        htmlActiveButton.style.fontWeight = 'bold'
        htmlActiveButton.style.color = 'white'
        htmlActiveButton.style.borderColor = '#34495e'
      }
    } else {
      alert(`Ошибка: ${data.error || 'Не удалось загрузить файл'}`)
    }
  } catch (error: Error | unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Не удалось подключиться к серверу'
    alert(`Ошибка: ${errorMessage}`)
  }
}

// Функция для сохранения файла
async function saveFile() {
  if (!currentFile) {
    alert('Сначала выберите файл для сохранения!')
    return
  }
  
  const contentElement = document.getElementById('content') as HTMLTextAreaElement
  const content = contentElement?.value || ''
  
  try {
    const res = await fetch(`${apiBaseUrl.value}/file?path=${encodeURIComponent(currentFile)}`, {
      method: "POST",
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({content})
    })
    
    if (res.ok) {
      alert("Файл сохранён!")
    } else {
      const data = await res.json()
      alert(`Ошибка: ${data.error || 'Не удалось сохранить файл'}`)
    }
  } catch (error: Error | unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Не удалось подключиться к серверу'
    alert(`Ошибка: ${errorMessage}`)
  }
}

// Функция для скачивания текущего конфигурационного файла
async function downloadCurrentConfig() {
  if (!currentFile) {
    alert('Сначала выберите файл для скачивания!')
    return
  }
  
  try {
    // Показываем индикатор загрузки
    const downloadButton = document.querySelector('.download-button') as HTMLElement
    const originalText = downloadButton?.textContent || ''
    if (downloadButton) {
      downloadButton.textContent = 'Загрузка файла...'
      downloadButton.setAttribute('disabled', 'true')
    }
    
    // Создаем контроллер для отмены запроса
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 10000) // 10 секунд таймаут
    
    // Запрашиваем содержимое текущего файла
    const res = await fetch(`${apiBaseUrl.value}/file?path=${encodeURIComponent(currentFile)}`, {
      method: 'GET',
      signal: controller.signal
    })
    
    // Очищаем таймаут
    clearTimeout(timeoutId)
    
    // Восстанавливаем кнопку
    if (downloadButton) {
      downloadButton.textContent = originalText
      downloadButton.removeAttribute('disabled')
    }
    
    if (res.ok) {
      // Получаем содержимое файла
      const data = await res.json()
      
      // Создаем blob из содержимого
      const blob = new Blob([data.content], { type: 'text/plain' })
      
      // Получаем имя файла из пути
      const fileName = currentFile.split('/').pop()
      
      // Создаем ссылку для скачивания
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.style.display = 'none'
      a.href = url
      a.download = fileName || 'config.txt'
      
      // Добавляем ссылку в DOM, кликаем по ней и удаляем
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)
    } else {
      // Обрабатываем ошибку
      let errorMessage = 'Не удалось скачать файл'
      try {
        const errorData = await res.json()
        errorMessage = errorData.error || errorMessage
      } catch {
        // Если ответ не в формате JSON, используем текст ответа
        errorMessage = await res.text() || errorMessage
      }
      alert(`Ошибка: ${errorMessage}`)
    }
  } catch (error: Error | unknown) {
    // Восстанавливаем кнопку в случае ошибки
    const downloadButton = document.querySelector('.download-button') as HTMLElement
    if (downloadButton) {
      downloadButton.textContent = 'Скачать текущий конфиг'
      downloadButton.removeAttribute('disabled')
    }
    
    // Показываем сообщение об ошибке
    const errorMessage = error instanceof Error ? error.message : 'Не удалось подключиться к серверу'
    alert(`Ошибка: ${errorMessage}`)
  }
}

onMounted(() => {
  createFileButtons()
  checkApiStatus()
  
  // Периодическая проверка статуса API каждые 30 секунд
  setInterval(checkApiStatus, 30000)
})
</script>

<style scoped>
.api-status {
  margin-bottom: 15px;
  padding: 12px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  font-size: 14px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  transition: all 0.3s ease;
}
.api-status.online {
  background-color: #2c3e50;
  border: 1px solid #34495e;
  color: #ecf0f1;
}
.api-status.offline {
  background-color: #c0392b;
  border: 1px solid #e74c3c;
  color: #ecf0f1;
}
.status-indicator {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  margin-right: 12px;
  box-shadow: 0 0 5px rgba(0,0,0,0.3);
}
.status-indicator.online {
  background-color: #2ecc71;
}
.status-indicator.offline {
  background-color: #e74c3c;
}
.file-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  margin-bottom: 15px;
  width: 100%;
}
.file-button {
  padding: 8px 15px;
  background-color: #2c3e50;
  color: white;
  border: 1px solid #34495e;
  border-radius: 4px;
  cursor: pointer;
  margin-bottom: 10px;
  margin-right: 10px;
  display: inline-flex;
  align-items: center;
  font-size: 16px;
  transition: all 0.2s ease;
  box-shadow: 0 2px 4px rgba(0,0,0,0.2);
}
.file-button:hover {
  background-color: #34495e;
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0,0,0,0.25);
}
.file-button:active, .file-button[style*="font-weight: bold"] {
  background-color: #2c3e50;
  border-color: #34495e;
  color: white;
  font-weight: bold;
}
.directory-button {
  background-color: #3498db;
  border-color: #2980b9;
}
.directory-button:hover {
  background-color: #2980b9;
}
textarea {
  width: 100%;
  max-width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-family: monospace;
  resize: none;
}
.button-container {
  display: flex;
  flex-direction: row;
  gap: 10px;
  margin-top: 10px;
  flex-wrap: wrap;
  width: 100%;
}
.save-button, .download-button {
  padding: 8px 15px;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  flex: 1;
  min-width: 150px;
  max-width: 200px;
}
.save-button {
  background-color: #27ae60;
  font-weight: 500;
  box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  transition: all 0.2s ease;
}
.save-button:hover {
  background-color: #2ecc71;
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0,0,0,0.25);
}
.download-button {
  background-color: #2c3e50;
  font-weight: 500;
  box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  transition: all 0.2s ease;
}
.download-button:hover {
  background-color: #34495e;
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0,0,0,0.25);
}
/* Медиа-запросы для адаптивности */
@media (max-width: 768px) {
  
  .file-button {
    font-size: 14px;
    padding: 6px 12px;
  }
  
  .save-button, .download-button {
    min-width: 120px;
  }
}

@media (max-width: 480px) {
  
  .file-button {
    font-size: 12px;
    padding: 5px 10px;
    margin-bottom: 5px;
  }
  
  .api-status {
    font-size: 12px;
    padding: 8px;
  }
  
  .save-button, .download-button {
    min-width: 100px;
    padding: 6px 12px;
  }
}
</style>