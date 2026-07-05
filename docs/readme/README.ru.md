> Этот перевод создан с помощью AI. Если заметите ошибку, откройте PR.

<div align="center">

# Filmidi Pro

**Видеоредактор, созданный для AI.**

<a href="https://github.com/filmidi-io/filmidi-pro/releases/latest/download/FilmidiPro.dmg">
  <img src="../../assets/macos-badge.png" alt="Скачать Filmidi Pro для macOS" width="180" />
</a>

<sub><i>Требуется macOS 26 (Tahoe) на Apple Silicon</i></sub>

<a href="https://x.com/Filmidi_io"><img src="https://img.shields.io/badge/Follow-%40Filmidi__io-000000?style=flat&logo=x&logoColor=white" alt="Подписаться в X" /></a>
<a href="https://discord.com/invite/SMVW6pKYmg"><img src="https://img.shields.io/badge/Join-Discord-5865F2?style=flat&logo=discord&logoColor=white" alt="Присоединиться к Discord" /></a>
<a href="https://www.ycombinator.com/companies/filmidi"><img src="https://img.shields.io/badge/Y%20Combinator-S24-orange" alt="Y Combinator S24" /></a>

<p>
  <a href="../../README.md">English</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.zh-CN.md">简体中文</a> ·
  <a href="README.zh-TW.md">繁體中文</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.vi.md">Tiếng Việt</a> ·
  <a href="README.hi.md">हिन्दी</a> ·
  <a href="README.bn.md">বাংলা</a> ·
  <a href="README.ar.md">العربية</a> ·
  <a href="README.it.md">Italiano</a> ·
  <a href="README.pt-BR.md">Português (Brasil)</a> ·
  <a href="README.fr.md">Français</a> ·
  <strong>Русский</strong> ·
  <a href="README.tr.md">Türkçe</a>
</p>

</div>

<img src="../../assets/filmidi-ui.png" alt="Интерфейс Filmidi Pro" width="900" />

---

Filmidi Pro — open source видеоредактор для Mac. Вы и ваш agent можете вместе генерировать и редактировать видео прямо на таймлайне.

### Видеоредактор, нативный для Swift

Мы построили Filmidi Pro с нуля на Swift. Ориентир — Premiere Pro, но с нашим подходом к интеграции AI в рабочий процесс.

### Встроенный generative AI

Генерируйте видео и изображения с помощью передовых моделей, таких как Seedance, Kling и Nano Banana Pro, прямо в редакторе таймлайна.

### Интеграция с вашими agent

Подключайте Claude, Codex или Cursor через MCP либо используйте встроенного agent в приложении, чтобы работать вместе над одним проектом.

## MCP server

Когда приложение открыто, оно предоставляет MCP server по адресу `http://127.0.0.1:19789/mcp` через HTTP. Для подключения:

**Claude Code**
```bash
claude mcp add --transport http filmidi-pro http://127.0.0.1:19789/mcp
```

**Codex**
```bash
codex mcp add filmidi-pro --url http://127.0.0.1:19789/mcp
```

**Cursor**

Самый простой способ — открыть в приложении `Help` -> `MCP Instructions` -> `Install in Cursor`. Также можно установить вручную, добавив это в `~/.cursor/mcp.json`:

```
{
  "mcpServers": {
    "filmidi-pro": {
      "type": "http",
      "url": "http://127.0.0.1:19789/mcp"
    }
  }
}
```

**Claude Desktop**

Мы поставляем [mcpb](https://github.com/modelcontextprotocol/mcpb) вместе с приложением, чтобы Desktop Extension для Claude Desktop можно было установить в один клик. Откройте `Help` -> `MCP Instructions` -> `Install in Claude Desktop`.

## FAQ

**Filmidi Pro полностью open source?**

Видеоредактор, без функций generative AI, полностью open source. MCP server и agent chat тоже open source. Закрытой остается только обработка generative AI.

**Это бесплатно?**

Редактор бесплатный. Его можно скачать без входа в аккаунт и использовать как видеоредактор, например CapCut или Adobe Premiere. MCP server тоже можно использовать бесплатно и начать экспериментировать с Claude Code, Claude Desktop или Cursor для взаимодействия с редактором таймлайна.

Функции generative AI требуют входа в аккаунт и подписки.

**Какие платформы поддерживаются?**

Только macOS 26 (Tahoe) на Apple Silicon.

Подробнее см. [FAQ.md](../../FAQ.md).

## Разработка

См. [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Сообщество и поддержка

- **Discord:** Присоединяйтесь к сообществу в **[Discord](https://discord.com/invite/SMVW6pKYmg)**.
- **Twitter / X:** Подписывайтесь на **[@Filmidi_io](https://x.com/Filmidi_io)**, чтобы получать обновления и анонсы.
- **Instagram:** Подписывайтесь на [@filmidi.io](https://www.instagram.com/filmidi.io).
- **Feedback и поддержка:** Создайте [GitHub Issue](https://github.com/filmidi-io/filmidi-pro/issues) или напишите нам на founders@filmidi.io.

## Star History

<a href="https://www.star-history.com/?type=date&repos=filmidi-io%2Ffilmidi-pro">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=filmidi-io/filmidi-pro&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=filmidi-io/filmidi-pro&type=date&legend=top-left" />
   <img alt="График Star History" src="https://api.star-history.com/chart?repos=filmidi-io/filmidi-pro&type=date&legend=top-left" />
 </picture>
</a>

## Лицензия

Copyright (C) 2026 Filmidi, Inc.

Filmidi Pro распространяется как open source по лицензии [GPLv3](../../LICENSE).
