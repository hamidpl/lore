---
sidebar_position: 6
title: نسخه‌بندی و انتشار
description: چطور Lore نسخه‌بندی می‌شود — نسخه‌بندیِ معنایی، وضعیتِ پیش از ۱.۰، و چطور یک نسخه‌ی پایدار را ثابت کنید.
tags: [versioning, releases]
---

# نسخه‌بندی و انتشار

‏Lore از [نسخه‌بندیِ معنایی](https://semver.org) پیروی می‌کند. نسخه‌ی جاری در manifestِ پلاگین ثبت می‌شود، و تغییرها در [Changelog](https://github.com/hamidpl/lore/blob/main/CHANGELOG.md) فهرست می‌شوند.

## پیش از ۱.۰

‏Lore **پیش از نسخه‌ی ۱.۰** است. به‌صورت سرتاسری کار می‌کند، اما نسخه‌های minor ممکن است تا `1.0.0` تغییراتِ شکننده داشته باشند. اگر به پایداری نیاز دارید، روی یک نسخه‌ی ثابت قفل کنید.

## ثابت‌کردنِ یک نسخه

مارکت‌پلیس را روی یک تگِ گیتِ ثابت اضافه کنید:

```text
/plugin marketplace add hamidpl/lore#v0.1.0
```

ثابت‌کردن یعنی تا زمانی که قفل را آگاهانه جابه‌جا نکنید، تغییرها — از جمله اصلاح‌ها — را نمی‌گیرید.

## به‌روز ماندن

وقتی آخرین نسخه را دنبال می‌کنید:

```text
/plugin marketplace update lore-marketplace
claude plugin update lore@lore-marketplace
```

برای جریانِ کاملِ به‌روزرسانی، [نصب و فعال‌سازی](./getting-started/install.md) را ببینید. هر انتشار تگ و منتشر می‌شود؛ [Changelog](https://github.com/hamidpl/lore/blob/main/CHANGELOG.md) منبعِ حقیقت برای آنچه تغییر کرده است.
