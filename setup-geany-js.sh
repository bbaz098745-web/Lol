#!/usr/bin/env bash
set -e

echo "== Geany JS + LSP + ESLint setup for Linux Mint XFCE =="

# تحديث النظام
sudo apt update

echo "1) تثبيت Geany والإضافات الأساسية..."
sudo apt install -y geany geany-plugins geany-plugin-vte xfce4-terminal xdotool inotify-tools

echo "2) تثبيت Node.js & npm (إذا غير مثبت)"
if ! command -v node >/dev/null 2>&1; then
  sudo apt install -y nodejs npm
fi

echo "3) تثبيت أدوات npm العالمية: eslint, typescript, typescript-language-server"
sudo npm install -g eslint typescript typescript-language-server || true

echo "4) إنشاء ~/bin وحط سكربتات التشغيل و الحفظ الذكي"
mkdir -p "$HOME/bin"

cat > "$HOME/bin/run_node.sh" <<'BASH'
#!/usr/bin/env bash
FILE="$1"
if [ -z "$FILE" ]; then
  echo "Usage: run_node.sh file.js"
  exit 1
fi
xfce4-terminal --title="JS Run: $(basename "$FILE")" --hide-menubar -x bash -lc "node '$FILE'; echo; echo '--- Press ENTER to close ---'; read -r"
BASH

cat > "$HOME/bin/debug_node.sh" <<'BASH'
#!/usr/bin/env bash
FILE="$1"
if [ -z "$FILE" ]; then
  echo "Usage: debug_node.sh file.js"
  exit 1
fi
xfce4-terminal --title="JS Debug: $(basename "$FILE")" --hide-menubar -x bash -lc "node --inspect-brk '$FILE'; echo; echo 'Started node --inspect-brk. Open chrome://inspect to connect. Press ENTER to close.'; read -r"
BASH

cat > "$HOME/bin/autosave_on_blank.sh" <<'BASH'
#!/usr/bin/env bash
# Usage: autosave_on_blank.sh /full/path/to/file.js
FILE="$1"
if [ -z "$FILE" ]; then
  echo "Usage: autosave_on_blank.sh /path/to/file.js"
  exit 1
fi
# يتطلب inotifywait و xdotool
while inotifywait -e modify "$FILE" >/dev/null 2>&1; do
  LAST_LINE=$(tail -n 1 "$FILE")
  if [ -z "$LAST_LINE" ]; then
    WIN_ID=$(xdotool search --onlyvisible --class geany | head -n1)
    if [ ! -z "$WIN_ID" ]; then
      xdotool windowactivate --sync "$WIN_ID"
      xdotool key --window "$WIN_ID" ctrl+s
      echo "$(date '+%H:%M:%S') Auto-saved $FILE"
    fi
  fi
done
BASH

chmod +x "$HOME/bin/run_node.sh" "$HOME/bin/debug_node.sh" "$HOME/bin/autosave_on_blank.sh"

# إضافة ~/bin إلى PATH إذا غير مضاف
if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.profile"
fi

echo "5) ضبط أوامر التشغيل/الـ Lint داخل إعدادات Geany (ملفاتconfig)..."
GEANY_CONF_DIR="$HOME/.config/geany"
mkdir -p "$GEANY_CONF_DIR/filedefs"
mkdir -p "$GEANY_CONF_DIR"

cat > "$GEANY_CONF_DIR/filedefs/filetypes.javascript" <<'INI'
[build-menu]
FT_00_LB=Lint
FT_00_CM=eslint -f unix "%f"
FT_00_WD=%d

FT_01_LB=Run
FT_01_CM=node "%f"
FT_01_WD=%d

FT_02_LB=Debug
FT_02_CM=node --inspect-brk "%f"
FT_02_WD=%d
INI

# خيار: تهيئة geany.conf خفيفة
cat > "$GEANY_CONF_DIR/geany.conf" <<'INI'
[editor]
use_tabs=false
tab_width=2
auto_indent=true
show_line_numbers=true

[document]
autosave=false

[ui]
statusbar_visible=true
INI

echo "✅ كل الملفات الأساسية انضبطت."

echo
echo "== إرشادات بعد التثبيت =="
echo "1) افتح Geany الآن (أعد فتح التيرمنال أو سجل خروج/دخول أول مرة لتحميل PATH)."
echo "2) من: Tools -> Plugin Manager: فعل الإضافات: 'VTE' و 'GeanyLinter' (إن وجدت) و 'Auto Save' (اختياري)."
echo "3) افتح ملف JavaScript (.js)."
echo "4) لتشغيل lint (ويظهر الأخطاء مع مؤشرات في Geany): من القائمة Build اختر 'Lint' أو اضغط F8 (حسب إعدادك)."
echo "   - Geany سيقرأ مخرجات eslint (تنسيق unix) ويعرض الأخطاء في تبويب الاخطاء ويضع مؤشرات على السطور."
echo "5) لتشغيل الكود: Build -> Run (أو F5) سيستخدم node \"%f\"."
echo "6) لتشغيل الـdebug: Build -> Debug سيستخدم node --inspect-brk \"%f\"."
echo
echo "لتشغيل الحفظ التلقائي لملف معيّن:"
echo "  ~/bin/autosave_on_blank.sh /full/path/to/your/file.js &"
echo
echo "انتهى التثبيت. افتح Geany وجرب الفحص (Build -> Lint) لتشوف الدوائر/المؤشرات."