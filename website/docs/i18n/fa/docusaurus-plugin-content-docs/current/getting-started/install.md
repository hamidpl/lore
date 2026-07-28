---
sidebar_position: 1
title: نصب و فعال‌سازی
description: مارکت‌پلیس Lore را اضافه کنید، پلاگین را نصب کنید، آن را برای پروژه‌تان فعال کنید و به‌روز نگه دارید.
tags: [getting-started, install]
---

# نصب و فعال‌سازی

‏Lore یک پلاگین Claude Code است که از طریق مارکت‌پلیس خودش توزیع می‌شود. نصب در دو دستور انجام می‌شود، که **درون Claude Code** اجرا می‌شوند (هر دو idempotent هستند).

## ۱. نصب

```text
/plugin marketplace add hamidpl/lore       # افزودن کاتالوگ
/plugin install lore@lore-marketplace      # نصب پلاگین
```

برای یک مخزن تیمی یا CI، در **سطح پروژه** نصب کنید تا یک کلون خودبسنده باشد:

```text
/plugin install lore@lore-marketplace --scope project
```

## ۲. فعال‌سازی

**نصب‌شدن با فعال‌بودن یکی نیست.** نصب، پلاگین را روی دستگاه شما کش می‌کند؛ *فعال‌سازی* آن را برای یک پروژه روشن می‌کند.

اگر Lore از قبل نصب است، دوباره `install` را اجرا نکنید — آن را از منوی `/plugin` فعال کنید (**Installed** ← `lore` ← Enable)، یا به `.claude/settings.json` پروژه‌تان اضافه کنید:

```json
{ "enabledPlugins": { "lore@lore-marketplace": true } }
```

## به‌روز نگه‌داشتن

وقتی نسخه‌ی جدیدی منتشر می‌شود:

```text
/plugin marketplace update lore-marketplace     # تازه‌سازی کاتالوگ
claude plugin update lore@lore-marketplace      # به‌روزرسانی پلاگین
```

از آن‌جا که Lore هوک‌هایی دارد که اسکریپت‌های شل را در مخزن شما اجرا می‌کنند، به‌روزرسانی‌های پلاگین را مثل هر ارتقای وابستگیِ دیگری بازبینی کنید.

**نصبِ Lore رفتارِ پروژه‌های دیگر را تغییر نمی‌دهد.** پلاگین به‌ازای هر کاربر نصب می‌شود، پس هوک‌هایش در هر مخزنی که در آن کار می‌کنید اجرا می‌شوند — و هر کدام اول بررسی می‌کند که این یک پروژه‌ی مستندسازیِ Lore باشد و در غیر این‌صورت بلافاصله خارج می‌شود. پروژه‌ای که صرفاً Markdown یا تصویری در پوشه‌ای به نامِ `docs` نگه می‌دارد دست‌نخورده می‌ماند: قواعدِ اینجا تعریفِ تحویلِ Lore است، نه حقیقتی جهان‌شمول.

## پیش‌نیازها

- **[Claude Code](https://code.claude.com/docs/en/overview).** ‏Lore یک پلاگین Claude Code است.
- **یک مرورگر، فقط برای [`lore:site-to-doc`](../guides/from-a-live-site.md).** این اسکیل یک مرورگر واقعی را از طریق سرور [Playwright MCP](https://github.com/microsoft/playwright-mcp) هدایت می‌کند. یک‌بار اضافه‌اش کنید (اگر نباشد، اسکیل از شما می‌خواهد):

  ```text
  claude mcp add playwright -- npx @playwright/mcp@latest
  ```

## بعدی

اولین پروژه‌تان را با [شروع سریع](../getting-started/quick-start.md) اسکفولد کنید.
