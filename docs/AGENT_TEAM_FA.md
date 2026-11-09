# تیم ۹ ایجنت پیمانکاری صبا VIP

این تعریف‌ها صرفاً به همین مخزن تعلق دارند و در پروژه‌های دیگر فعال نمی‌شوند.

## ایجنت‌های پروژه

| Codex agent | وظیفه | نوع فعالیت |
| --- | --- | --- |
| `app_developer` | Flutter implementation | اجرا در محدوده واگذارشده |
| `ui_designer` | Flutter visual/UX design | اجرا در محدوده واگذارشده |
| `android_release` | Android build and release QA | اجرا در محدوده واگذارشده |
| `database_agent` | SQLite integrity and migration | اجرا در محدوده واگذارشده |
| `accounting_agent` | Contracting accounting controls | پیش‌فرض بررسی / بدون تغییر کد |
| `debugger_agent` | Root cause debugging | اجرا در محدوده واگذارشده |
| `testing_agent` | Regression and acceptance testing | اجرا در محدوده واگذارشده |
| `security_agent` | Offline security and privacy | پیش‌فرض بررسی / بدون تغییر کد |
| `performance_agent` | Flutter and SQLite performance | پیش‌فرض بررسی / بدون تغییر کد |

## فایل‌ها و میزبان
- **Codex:** نه فایل `.codex/agents/*.toml` و تنظیمات `.codex/config.toml`، مطابق [مستندات رسمی](https://developers.openai.com/codex/multi-agent). برای استفاده Codex را از ریشه این مخزن باز کنید و از ایجنت‌های نام‌برده درخواست مشخص کنید.
- **Claude Code:** نه فایل `.claude/agents/*.md` مطابق [مستندات رسمی](https://code.claude.com/docs/en/sub-agents). صرف وجود فایل به معنی نصب یا اجرای دائمی Claude Code نیست.
- سه اسکیل موجود در `.agents/skills` حفظ شده‌اند و ایجنت‌ها در صورت نیاز از آن‌ها راهنمایی می‌گیرند.

## راه‌اندازی و استفاده
در جلسه Codex داخل همین مخزن بنویسید:

> فقط در Saba-VIP-Contracting کار کن. طبق AGENTS.md، ابتدا database_agent و accounting_agent را برای بررسی ثبت هزینه/پرداخت جزئی، و ui_designer را برای بررسی مستقل فرم به کار بگیر. حداکثر سه ایجنت همزمان. پس از جمع‌بندی، app_developer به‌صورت واحد تغییرات را اعمال کند؛ سپس testing_agent، security_agent، performance_agent بررسی کنند و فقط پس از تست، android_release وضعیت ساخت APK را اعلام کند. نتایج واقعی را به فارسی گزارش بده.

**تقسیم کار:** معماری و منطق مالی وابستگی دارند؛ همزمان روی یک فایل مشترک نوشته نشود. بررسی‌های مستقل (UI/امنیت/سرعت) را می‌توان موازی انجام داد؛ نوشتن کد و ادغام باید ترتیبی و با مالک مشخص انجام شود.

## مرزهای عملیاتی
- این‌ها تعریف‌های قابل شناسایی برای Codex و Claude Code هستند، نه ۹ پردازش فعال شبانه‌روزی. استفاده واقعی نیازمند اجرا شدن همان میزبان و دسترسی به پروژه است.
- تنظیمات ایجنت **مجوز مستقل/دسترسی محدود سیستمی ایجاد نمی‌کند**؛ سیاست sandbox از جلسه والد به ارث می‌رسد.
- `max_concurrent_threads_per_session = 3` سقف هم‌زمانی است، نه دستور اجباری برای ایجاد سه ایجنت.
- تیم برای اپ Flutter آفلاین، SQLite، تقویم شمسی و گزارش‌های PDF/XLSX و پرداخت اختیاری هزینه طراحی شده است.
- تغییر فایل‌های این PR فقط در ابزار ایجنت‌ها و مستندات است؛ هیچ ویژگی اپ و ساخت APK با اضافه شدن آن‌ها خودبه‌خود تغییر نمی‌کند.

## آزمون پذیرش
پیکربندی TOML و فایل‌های YAML frontmatter باید parse شوند؛ نام ۹ نقش یکتا، توضیح و دستور اجرایی غیرخالی و پوشش ۳ اسکیل موجود بررسی شود. اجرای واقعی spawning/Flutter build فقط وقتی میزبان و SDK در دسترس باشد قابل تأیید است.
