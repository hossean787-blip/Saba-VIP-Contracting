# سه اسکیل اختصاصی پیمانکاری صبا VIP

این اسکیل‌ها فقط برای مخزن Saba-VIP-Contracting ساخته شده‌اند؛ هیچ فایل یا تصمیمی از سایر پروژه‌ها وارد نشده است.

| نوع | فایل | کاربرد |
| --- | --- | --- |
| معماری و امور مالی Flutter | .agents/skills/saba-flutter-architecture/SKILL.md | SQLite، قرارداد، هزینه و پرداخت |
| طراحی Claude برای Flutter | .agents/skills/saba-flutter-visual-design/SKILL.md | رابط فارسی RTL و تم موجود |
| کنترل کیفیت اندروید Google | .agents/skills/saba-android-release-qa/SKILL.md | تست، APK، امضا و عملکرد |

منابع مفهومی، بدون کپی اسکیل‌های بومی و وب:
- Android & KMP skills — MIT — https://github.com/rcosteira79/android-skills
- Anthropic frontend-design — https://github.com/anthropics/skills/tree/main/skills/frontend-design
- Google Android skills — Apache-2.0 — https://github.com/android/skills

این‌ها سه اسکیل مستقل و **سازگارشده با Flutter** هستند و نصب مستقیم تمام مجموعه‌های اصلی یا ابزار Android CLI در سیستم/حساب ChatGPT محسوب نمی‌شوند.

## استفاده با Codex
از ریشه همین مخزن یک جلسه Codex باز کنید. دستور نمونه:

طبق AGENTS.md و سه اسکیل زیر، فقط در پروژه Saba-VIP-Contracting کار کن:
1) .agents/skills/saba-flutter-architecture/SKILL.md
2) .agents/skills/saba-flutter-visual-design/SKILL.md
3) .agents/skills/saba-android-release-qa/SKILL.md
قابلیت موردنظر را از لایه منطق تا دیتابیس، UI، گزارش و تست تکمیل کن.
شناسایی هزینه را از پرداخت اختیاری آن مستقل نگه دار؛ بدون انتخاب یعنی پرداخت نشده، کامل یعنی کل هزینه، جزئی یعنی مبلغ معتبر کمتر از کل. نتیجه واقعی Flutter analyze/test/build و موانع را گزارش کن.

اگر عامل از کشف خودکار project skills در .agents/skills پشتیبانی کند، این اسکیل‌ها در همین مخزن در دسترس‌اند؛ در غیر این صورت مسیرهای بالا را صریح بدهید.

## وضعیت
- فقط دستورالعمل‌ها و راهنمای توسعه اضافه شده‌اند؛ اپ و دیتابیس تغییر نکرده‌اند.
- خواندن اسکیل‌ها هزینه یا SDK نیاز ندارد. تست Flutter به Flutter SDK و ساخت APK به Android SDK وابسته است.
- انتشار خودکار، ساخت پرهزینه در GitHub Actions، و تغییر امضای اپ فعال نشده‌اند.
