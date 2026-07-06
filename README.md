<div align="center">

# Filmidi Pro

**The video editor built for AI.**

<a href="https://github.com/filmidi-io/filmidi-pro/releases/latest/download/FilmidiPro.dmg">
  <img src="./assets/macos-badge.png" alt="Download Filmidi Pro for macOS" width="180" />
</a>

<sub><i>Requires macOS 26 (Tahoe) on Apple Silicon</i></sub>

<a href="https://x.com/Filmidi_io"><img src="https://img.shields.io/badge/Follow-%40Filmidi__io-000000?style=flat&logo=x&logoColor=white" alt="Follow on X" /></a>
<a href="https://discord.com/invite/SMVW6pKYmg"><img src="https://img.shields.io/badge/Join-Discord-5865F2?style=flat&logo=discord&logoColor=white" alt="Join Discord" /></a>
<a href="https://www.ycombinator.com/companies/filmidi"><img src="https://img.shields.io/badge/Y%20Combinator-S24-orange" alt="Y Combinator S24" /></a>

<p>
  <strong>English</strong> ·
  <a href="docs/readme/README.es.md">Español</a> ·
  <a href="docs/readme/README.zh-CN.md">简体中文</a> ·
  <a href="docs/readme/README.zh-TW.md">繁體中文</a> ·
  <a href="docs/readme/README.ja.md">日本語</a> ·
  <a href="docs/readme/README.ko.md">한국어</a> ·
  <a href="docs/readme/README.vi.md">Tiếng Việt</a> ·
  <a href="docs/readme/README.hi.md">हिन्दी</a> ·
  <a href="docs/readme/README.bn.md">বাংলা</a> ·
  <a href="docs/readme/README.ar.md">العربية</a> ·
  <a href="docs/readme/README.it.md">Italiano</a> ·
  <a href="docs/readme/README.pt-BR.md">Português (Brasil)</a> ·
  <a href="docs/readme/README.fr.md">Français</a> ·
  <a href="docs/readme/README.ru.md">Русский</a> ·
  <a href="docs/readme/README.tr.md">Türkçe</a>
</p>

</div>

<img src="./assets/filmidi-ui.png" alt="Filmidi Pro UI" width="900" />

---

Filmidi Pro is an open source video editor for Mac. You and your agent can generate and edit videos together inside the timeline.

### Swift-native video editor

We built Filmidi Pro from scratch with Swift. The north star is Premiere Pro, with our take on integrating AI into the workflow.

### Built-in Generative AI

Generate videos and images with SOTA models like Seedance, Kling, Nano Banana Pro inside the timeline editor.

### Integrates with your agents

Connects your Claude/Codex/Cursor via MCP, or use the in-app agent to work on the same project together.

## MCP server

When the app is open, it exposes an MCP server at `http://127.0.0.1:19789/mcp` via HTTP. To connect:

**Claude Code**
```bash
claude mcp add --transport http filmidi-pro http://127.0.0.1:19789/mcp
```

**Codex**
```bash
codex mcp add filmidi-pro --url http://127.0.0.1:19789/mcp
```

**Cursor**

The easiest way is go inside the app `Help` -> `MCP Instructions` -> `Install in Cursor`, or install manually by adding this to `~/.cursor/mcp.json`:

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

We bundle a [mcpb](https://github.com/modelcontextprotocol/mcpb) with the app that allows a one click install Desktop Extension on Claude Desktop. Go to `Help` -> `MCP Instructions` -> `Install in Claude Desktop`

## FAQ

**Is Filmidi Pro fully open source?**

The video editor (without the generative AI features) is fully open source. The MCP server and the agent chat are also open source. The only thing that is closed source is the generative AI processing.

**Is it free?**

The editor is free. You can download it with no login required, and use it as a video editor like CapCut or Adobe Premiere. You can also use the MCP server for free, and start experimenting using Claude Code/Desktop or Cursor to interact with your timeline editor.

Generative AI features require login and subscription.

**What platforms does it support?**

macOS 26 (Tahoe) on Apple Silicon only.

See [FAQ.md](FAQ.md) for more.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md)

## Community &amp; Support

- **Discord:** Join the community on **[Discord](https://discord.com/invite/SMVW6pKYmg)**.
- **Twitter / X:** Follow **[@Filmidi_io](https://x.com/Filmidi_io)** for updates and announcements.
- **Instagram:** Follow [@filmidi.io](https://www.instagram.com/filmidi.io) 
- **Feedback &amp; Support:** Create a [Github Issue](https://github.com/filmidi-io/filmidi-pro/issues) or email us at founders@filmidi.io

## Star History

<a href="https://www.star-history.com/?type=date&repos=filmidi-io%2Ffilmidi-pro">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=filmidi-io/filmidi-pro&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=filmidi-io/filmidi-pro&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=filmidi-io/filmidi-pro&type=date&legend=top-left" />
 </picture>
</a>

## License

Copyright (C) 2026 Filmidi, Inc.

Filmidi Pro is open source under [GPLv3](LICENSE).
