#!/usr/bin/env bash

# === تنظیمات اولیه ===
# اطمینان از اینکه اسکریپت با خطا متوقف می‌شود و متغیرهای تعریف نشده خطا ایجاد می‌کنند.
set -euo pipefail

# URL هدف برای تست
TARGET_URL="https://google.com"
# نام فایل برای ذخیره گزارش
REPORT_FILE="https_test_report.txt"

# === پاک کردن گزارش قبلی (اگر وجود دارد) ===
> "$REPORT_FILE"

# === تابع برای اضافه کردن متن به گزارش ===
log_to_report() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$REPORT_FILE"
}

# === شروع گزارش ===
log_to_report "--- شروع تست HTTPS برای: $TARGET_URL ---"

# === تست اولیه با curl ===
log_to_report "اجرای curl برای دریافت اطلاعات اولیه..."
# -s: حالت ساکت (بدون نمایش progress meter)
# -o /dev/null: خروجی اصلی را به هیچ‌کجا هدایت نمی‌کند (چون فقط به وضعیت HTTP نیاز داریم)
# -w: فرمت خروجی curl را مشخص می‌کند
# --connect-timeout 10: حداکثر ۱۰ ثانیه برای برقراری اتصال صبر می‌کند
# --max-time 20: حداکثر ۲۰ ثانیه برای کل عملیات صبر می‌کند
# -L: دنبال کردن ریدایرکت‌ها (Redirects)
CURL_OUTPUT=$(curl -L -s -o /dev/null -w "%{http_code}\n" --connect-timeout 10 --max-time 20 "$TARGET_URL")
CURL_EXIT_CODE=$?

if [ $CURL_EXIT_CODE -ne 0 ]; then
    log_to_report "خطا در اجرای curl (کد خروج: $CURL_EXIT_CODE). ممکن است اتصال برقرار نشد یا timeout رخ داد."
    log_to_report "--- تست ناموفق بود ---"
    exit 1
else
    log_to_report "وضعیت HTTP: $CURL_OUTPUT"
    if [[ "$CURL_OUTPUT" =~ ^[23] ]]; then
        log_to_report "وضعیت HTTP موفقیت‌آمیز بود (کد 2xx یا 3xx)."
    else
        log_to_report "هشدار: وضعیت HTTP غیرمنتظره ($CURL_OUTPUT)."
    fi
fi

# === بررسی زنجیره SSL و گواهی با openssl ===
log_to_report "بررسی زنجیره SSL و گواهی با openssl..."

# اتصال به سرور و دریافت اطلاعات گواهی
# -servername: برای SNI (Server Name Indication) استفاده می‌شود که در HTTPS مهم است
# -connect google.com:443: به هاست و پورت مشخص شده متصل می‌شود
# Q: یک کاراکتر دلخواه برای ارسال به سرور و بستن اتصال بلافاصله پس از دریافت گواهی
# <<<: Here-string برای ارسال 'Q' به استاندارد ورودی openssl s_client
# timeout 15: حداکثر ۱۵ ثانیه برای این دستور صبر می‌کند
# 2>&1: خطاهای استاندارد (stderr) را به خروجی استاندارد (stdout) هدایت می‌کند تا با هم نمایش داده شوند
# grep '-----BEGIN CERTIFICATE-----': پیدا کردن شروع بلاک گواهی
# head -n 1: گرفتن اولین گواهی (گواهی سرور)
# openssl x509 -noout -dates -issuer -subject -fingerprint -sha256 -certfile <(...) : پردازش گواهی دریافتی
# -fingerprint -sha256: نمایش هش SHA256 گواهی
# -dates: نمایش تاریخ‌های notBefore و notAfter
# -issuer: نمایش اطلاعات صادر کننده (Issuer)
# -subject: نمایش اطلاعات گیرنده (Subject)

# استفاده از یک متغیر موقت برای ذخیره خروجی openssl s_client
TEMP_CERT_DATA=$(timeout 15 openssl s_client -connect "${TARGET_URL%:*}":443 -servername "${TARGET_URL%:*}" <<<"Q" 2>&1)
OPENSSL_EXIT_CODE=$?

if [ $OPENSSL_EXIT_CODE -ne 0 ]; then
    log_to_report "خطا در اتصال SSL یا دریافت گواهی (کد خروج: $OPENSSL_EXIT_CODE)."
    log_to_report "جزئیات احتمالی خطا: $(echo "$TEMP_CERT_DATA" | head -n 10)" # نمایش ۱۰ خط اول خطا
    log_to_report "--- تست ناموفق بود ---"
    exit 1
fi

# استخراج گواهی سرور
SERVER_CERT=$(echo "$TEMP_CERT_DATA" | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | sed '/-----BEGIN CERTIFICATE-----/d' | sed '/-----END CERTIFICATE-----/d')

if [ -z "$SERVER_CERT" ]; then
    log_to_report "خطا: نتوانست گواهی سرور را استخراج کند."
    log_to_report "--- تست ناموفق بود ---"
    exit 1
fi

# پردازش گواهی با openssl x509
# استفاده از process substitution <(...) برای ارسال داده به stdin دستور
CERT_INFO=$(openssl x509 -noout -dates -issuer -subject -fingerprint -sha256 -certfile <(echo "$SERVER_CERT"))
CERT_INFO_EXIT_CODE=$?

if [ $CERT_INFO_EXIT_CODE -ne 0 ]; then
    log_to_report "خطا در پردازش گواهی با openssl x509 (کد خروج: $CERT_INFO_EXIT_CODE)."
    log_to_report "--- تست ناموفق بود ---"
    exit 1
fi

# استخراج اطلاعات مورد نیاز از CERT_INFO
ISSUER=$(echo "$CERT_INFO" | grep "issuer=" | sed 's/issuer=//')
SUBJECT=$(echo "$CERT_INFO" | grep "subject=" | sed 's/subject=//')
NOT_BEFORE_STR=$(echo "$CERT_INFO" | grep "notBefore=" | sed 's/notBefore=//')
NOT_AFTER_STR=$(echo "$CERT_INFO" | grep "notAfter=" | sed 's/notAfter=//')
SHA256_FP=$(echo "$CERT_INFO" | grep "SHA256 Fingerprint=" | sed 's/SHA256 Fingerprint=//')

# نمایش اطلاعات در گزارش
log_to_report "Issuer: $ISSUER"
log_to_report "Subject: $SUBJECT"
log_to_report "SHA256 Fingerprint: $SHA256_FP"
log_to_report "Valid From: $NOT_BEFORE_STR"
log_to_report "Valid Until: $NOT_AFTER_STR"

# === محاسبه تاریخ انقضا ===
# تبدیل تاریخ‌ها به فرمت قابل فهم برای date
# مثال: '22 Jan 10:00:00 2024 GMT'
NOT_AFTER_FORMATTED=$(echo "$NOT_AFTER_STR" | awk '{print $1, $2, $3, "GMT"}') # فقط تاریخ و زمان را نگه می‌دارد

# گرفتن تاریخ فعلی به صورت timestamp Unix
CURRENT_DATE_TS=$(date +%s)
# تبدیل تاریخ انقضا به timestamp Unix
NOT_AFTER_TS=$(date -d "$NOT_AFTER_FORMATTED" +%s)

# محاسبه اختلاف روزها
DAYS_LEFT=$(( (NOT_AFTER_TS -
