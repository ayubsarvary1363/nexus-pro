# ─────────────────────────────────────────────────────────────
# ⏰ نگه‌داشتن سرور Render بیدار — پینگ خودکار هر ۵ دقیقه
# محل قرار گرفتن در ریپازیتوری گیت‌هاب:
#     .github/workflows/keepalive.yml
# فقط یک چیز را عوض کنید: مقدار NEXUS_URL (آدرس Render خودتان)
# ─────────────────────────────────────────────────────────────
name: keep-alive

on:
  schedule:
    - cron: '*/5 * * * *'   # هر ۵ دقیقه (وقت جهانی UTC)
  workflow_dispatch:         # امکان اجرای دستی از گوشی

jobs:
  ping:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Ping the trading server
        env:
          NEXUS_URL: https://nexus-pro-shxd.onrender.com   # ← اینجا آدرس خودتان
        run: |
          echo "آدرس: $NEXUS_URL"
          # دو تلاش، چون Render در بیدار شدن اول ~۵۰ ثانیه وقت می‌خواهد
          for i in 1 2; do
            echo "── تلاش $i ──"
            CODE=$(curl -sS -m 90 -o /tmp/out.json -w "%{http_code}" "$NEXUS_URL" || echo "000")
            echo "کد پاسخ: $CODE"
            if [ "$CODE" = "200" ]; then
              echo "پاسخ سرور:"
              cat /tmp/out.json
              echo ""
              if grep -q '"ok":true' /tmp/out.json; then
                echo "✅ سرور بیدار و سالم است"
                exit 0
              fi
            fi
            sleep 10
          done
          echo "⚠️ سرور پاسخ نداد (خواب یا در حال دیپلوی)"
          exit 0
