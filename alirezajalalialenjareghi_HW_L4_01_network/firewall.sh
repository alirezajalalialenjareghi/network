#!/bin/bash

# مشخص کردن IP مجاز برای SSH
SSH_IP="192.168.56.1"

# ۱. فعال‌سازی فایروال
ufw --force enable

# ۲. سیاست پیش‌فرض: بلاک کردن تمام ورودی‌ها و آزادسازی تمام خروجی‌ها
ufw default deny incoming
ufw default allow outgoing

# ۳. تنظیم قوانین خاص
# اجازه SSH فقط برای IP مشخص شده
ufw allow from $SSH_IP to any port 22 proto tcp

# اجازه HTTP و HTTPS از همه جا
ufw allow 80/tcp
ufw allow 443/tcp

# ۴. ذخیره لیست قوانین در فایل
ufw status verbose > firewall_active_rules.txt

echo "فایروال تنظیم شد. قوانین در فایل firewall_active_rules.txt ذخیره شدند."
