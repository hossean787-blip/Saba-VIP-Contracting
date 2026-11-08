# وابستگی‌ها و مجوزها — v0.2

- Flutter SDK و Android SDK: فقط برای build (رایگان؛ نیاز به نصب و اینترنت هنگام آماده‌سازی).
- SQLite از طریق sqflite: ذخیره اطلاعات کاملاً روی گوشی.
- `pdf` نسخه 3.x: کتابخانه تولید PDF، مجوز MIT؛ https://pub.dev/packages/pdf
- `excel` نسخه 4.0.6: ساخت فایل XLSX واقعی، مجوز MIT؛ https://pub.dev/packages/excel
- `share_plus` نسخه 11.1.0: اشتراک از مسیر برنامه‌های نصب‌شده، مجوز BSD-3-Clause؛ https://pub.dev/packages/share_plus
- `cross_file`: بسته رابط فایل برای ارسال `XFile` به Share Sheet؛ از API سازگار 0.3 استفاده می‌شود و نسخه 0.4 با تغییرات ناسازگار برای این نسخه انتخاب نشده است.
- فونت PDF: Noto Naskh Arabic، پروژه Google Fonts با مجوز SIL OFL 1.1؛ https://github.com/google/fonts/tree/main/ofl/notonaskharabic — دریافت در build به‌صورت موقت با `tool/prepare_fonts.sh`. این فونت در سورس تحویلی موجود نیست.

تمام ابزارهای بالا برای اجرای بخش اصلی آفلاین نیاز به سرور ندارند. اعتبارسنجی کامل وابستگی‌ها با `flutter pub get` و Android build هنوز باز است.
