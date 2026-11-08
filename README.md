# پیمانکاری صبا VIP | Saba VIP Contracting

اپ آفلاین مدیریت پیمانکاری برای مدیر شرکت؛ Flutter + SQLite.

## امکانات فعلی آزمایشی
- اطلاعات شرکت، قراردادها، عملیات و مراحل پروژه
- هزینه، پرداخت، دریافت و صورت‌وضعیت
- گزارش مالی، نمودار پروژه، خروجی PDF و Excel، تاریخ شمسی
- ذخیره اطلاعات به‌صورت آفلاین روی دستگاه

## امضای دائمی برای به‌روزرسانی بدون حذف
Workflow: Android Release (permanent signature)

راهنمای فارسی: [docs/PERSISTENT_SIGNING_FA.md](docs/PERSISTENT_SIGNING_FA.md)

پس از افزودن دو GitHub Secret، نسخه Release با کلید ثابت و versionCode افزایشی تولید می‌شود. این مخزن عمومی است؛ کلید خصوصی و رمز هرگز داخل سورس ذخیره نمی‌شوند.

**توجه:** APK نسخه 0.2.0 از کلید موقت متفاوت استفاده کرده بود. مهاجرت اولیه به کلید دائمی ممکن است نیازمند یک نصب مجدد باشد. پیش از پاک‌کردن هر نسخه دارای اطلاعات، بکاپ امن تهیه کنید.

## توسعه
پس از نصب Flutter، Java و Android SDK:

- bash tool/bootstrap_android.sh
- flutter analyze
- flutter test
- python3 -m unittest discover -s tests_python -p 'test_*.py' -v

برای Release استفاده از keystore دائمی لازم است؛ اجرای flutter build apk --release بدون پیکربندی امضای ثابت مورد تأیید نیست.

این نسخه آزمایشی است؛ قبل از ثبت اطلاعات واقعی باید قابلیت پشتیبان/بازیابی، آزمون نصب و صحت مالی تأیید شوند.
