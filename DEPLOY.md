# Деплой на GitHub Pages

## Автоматический деплой

Проект настроен на автоматический деплой на GitHub Pages при пуше в ветку `main`. Процесс деплоя настроен в файле `.github/workflows/deploy.yml`.

## Ручной деплой

Если вы хотите вручную задеплоить проект на GitHub Pages, выполните следующие шаги:

1. Соберите проект:

```bash
pnpm build
```

2. Создайте файл CNAME в директории dist:

```bash
echo 'board.zash.run.place' > ./dist/CNAME
```

3. Создайте файл .nojekyll в директории dist:

```bash
touch ./dist/.nojekyll
```

4. Создайте архив dist.zip для распространения:

```bash
Compress-Archive -Path "dist\*" -DestinationPath "dist.zip" -Force
```

5. Задеплойте содержимое директории dist на GitHub Pages:

```bash
# Используя gh-pages
npx gh-pages -d dist

# Или вручную
git checkout --orphan gh-pages
git rm -rf .
git add dist/* dist/.nojekyll
git commit -m "Deploy to GitHub Pages"
git push origin gh-pages --force
git checkout main
```

## Проверка деплоя

После деплоя ваш сайт будет доступен по адресу, указанному в файле CNAME, или по стандартному адресу GitHub Pages: `https://<username>.github.io/<repository>/`.