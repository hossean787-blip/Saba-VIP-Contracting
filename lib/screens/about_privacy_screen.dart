import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// Honest offline data/privacy notice; not a substitute for publisher legal docs.
class AboutPrivacyScreen extends StatelessWidget {
  const AboutPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('درباره برنامه و حریم خصوصی')),
    body: ListView(padding: const EdgeInsets.all(18), children: const [
      VipCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: champagne, size: 36),
          SizedBox(height: 10),
          Text('پیمانکاری صبا VIP',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('نسخه ۱.۰.۰ — نامزد انتشار تجاری',
            style: TextStyle(color: champagne)),
          SizedBox(height: 12),
          Text('این برنامه برای ثبت قراردادها، متره، اسناد مالی و گزارش‌های '
            'آفلاین طراحی شده است. محاسبات مالی و کنترل داده‌ها باید پیش از '
            'استناد رسمی با اسناد همان قرارداد تطبیق داده شوند.',
            style: TextStyle(height: 1.7)),
        ],
      )),
      SizedBox(height: 16),
      SectionHeading('حریم خصوصی و محل داده‌ها'),
      SizedBox(height: 10),
      VipCard(child: Text(
        'اطلاعات قرارداد و مبالغ در پایگاه‌داده SQLite داخل حافظه اختصاصی '
        'این دستگاه ذخیره می‌شود. برنامه برای کارکرد اصلی به حساب یا '
        'سرور اجباری متصل نیست. فایل گزارش یا پشتیبان فقط با اقدام شما '
        'از طریق پنجره اشتراک‌گذاری دستگاه به برنامه مقصد منتقل می‌شود.\n\n'
        'بانک اطلاعات داخلی در این نسخه به‌صورت پیش‌فرض رمزگذاری‌شده نیست؛ '
        'بنابراین قفل دستگاه، به‌روزرسانی امنیتی و محافظت فیزیکی گوشی '
        'ضروری هستند. قفل اختیاری برنامه صرفاً دسترسی از داخل رابط کاربری '
        'را محدود می‌کند.\n\n'
        'پشتیبان‌های خروجی با رمز انتخابی کاربر و AES-256-GCM محافظت '
        'می‌شوند؛ رمز را جدا از فایل و خارج از گوشی نگهداری کنید.',
        style: TextStyle(height: 1.8))),
      SizedBox(height: 16),
      SectionHeading('محدودیت‌های انتشار'),
      SizedBox(height: 10),
      VipCard(child: Text(
        'این نسخه بدون آزمون واقعی روی دستگاه‌های هدف، آزمون بازیابی '
        'با داده نمونه و ثبت اطلاعات ناشر، پشتیبانی و سیاست حریم خصوصی '
        'حقوقی نباید به‌عنوان محصول تجاری نهایی معرفی یا منتشر شود.\n\n'
        'نرخ مالیات، ضرایب پیمان، کسورات و صورت‌وضعیت‌ها به اسناد و قوانین '
        'حاکم بر هر قرارداد وابسته‌اند و برنامه جایگزین تأیید مالی و '
        'فنی متخصص نیست.',
        style: TextStyle(color: muted, height: 1.8))),
    ]),
  );
}
