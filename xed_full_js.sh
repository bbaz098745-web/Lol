#!/usr/bin/env bash
set -e

echo "=== Xed JS Complete Setup (Light) for Linux Mint XFCE ==="

# 0) معلومات سريعة
echo "تأكد أنك متصل بالإنترنت. سيطلب السكربت صلاحية sudo."

# 1) تحديث الحزم
sudo apt update

# 2) تثبيت الأدوات الأساسية
sudo apt install -y xed xfce4-terminal xdotool inotify-tools curl wget gnupg python3-pip

# 3) تثبيت Node.js + npm (APT) إن لم يكن موجودًا (إصدار متوافق)
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js غير موجود — تثبيت nodejs & npm من المستودعات"
  sudo apt install -y nodejs npm
else
  echo "Node.js موجود: $(node -v)"
fi

# 4) تثبيت حزم npm العالمية المفيدة
if command -v npm >/dev/null 2>&1; then
  echo "تثبيت eslint, typescript, typescript-language-server, tern (عالمياً)"
  sudo npm install -g eslint typescript typescript-language-server tern || true
else
  echo "تنبيه: npm غير موجود. إذا أردت تثبيته يمكن: sudo apt install nodejs npm"
fi

# 5) إنشاء ~/bin و سكربتات التشغيل، Debug، الحفظ الذكي
mkdir -p "$HOME/bin"

cat > "$HOME/bin/run_node.sh" <<'BASH'
#!/usr/bin/env bash
# run_node.sh /full/path/to/file.js
FILE="$1"
if [ -z "$FILE" ]; then
  echo "Usage: run_node.sh /path/to/file.js"
  exit 1
fi
# افتح drop-down terminal مخصص (xfce4-terminal --drop-down) إن مدعوم
# إذا لم يدعم الأمر --drop-down سنفتح ترمينال عادي.
if xfce4-terminal --help 2>&1 | grep -q -- --drop-down; then
  xfce4-terminal --drop-down --title="JS Run: $(basename "$FILE")" -x bash -lc "node '$FILE'; echo; echo '--- Press ENTER to hide ---'; read -r"
else
  xfce4-terminal --title="JS Run: $(basename "$FILE")" -x bash -lc "node '$FILE'; echo; echo '--- Press ENTER to close ---'; read -r"
fi
BASH

cat > "$HOME/bin/debug_node.sh" <<'BASH'
#!/usr/bin/env bash
# debug_node.sh /full/path/to/file.js
FILE="$1"
if [ -z "$FILE" ]; then
  echo "Usage: debug_node.sh /path/to/file.js"
  exit 1
fi
if xfce4-terminal --help 2>&1 | grep -q -- --drop-down; then
  xfce4-terminal --drop-down --title="JS Debug: $(basename "$FILE")" -x bash -lc "node --inspect-brk '$FILE'; echo; echo 'Started node --inspect-brk. Open chrome://inspect to connect. Press ENTER to hide.'; read -r"
else
  xfce4-terminal --title="JS Debug: $(basename "$FILE")" -x bash -lc "node --inspect-brk '$FILE'; echo; echo 'Started node --inspect-brk. Open chrome://inspect to connect. Press ENTER to close.'; read -r"
fi
BASH

cat > "$HOME/bin/autosave_on_blank.sh" <<'BASH'
#!/usr/bin/env bash
# Usage: autosave_on_blank.sh /full/path/to/file.js
FILE="$1"
if [ -z "$FILE" ]; then
  echo "Usage: autosave_on_blank.sh /path/to/file.js"
  exit 1
fi
# requires inotifywait and xdotool
while inotifywait -e modify "$FILE" >/dev/null 2>&1; do
  # انتظر 0.1s حتى يكتب المحرر كل شيء
  sleep 0.1
  LAST_LINE=$(tail -n 1 "$FILE")
  if [ -z "$LAST_LINE" ]; then
    # ايجاد نافذة Xed ثم ارسال Ctrl+S
    WIN_ID=$(xdotool search --onlyvisible --class xed | head -n1)
    if [ ! -z "$WIN_ID" ]; then
      xdotool windowactivate --sync "$WIN_ID"
      xdotool key --window "$WIN_ID" ctrl+s
      echo "$(date '+%H:%M:%S') Auto-saved $FILE"
    fi
  fi
done
BASH

chmod +x "$HOME/bin/run_node.sh" "$HOME/bin/debug_node.sh" "$HOME/bin/autosave_on_blank.sh"

# 6) إضافة ~/bin للـ PATH عبر .profile إن لم يكن موجوداً
if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.profile"
  echo "Added ~/bin to PATH in ~/.profile (will be active after new login or source ~/.profile)."
fi

# 7) إنشاء قوالب مشروع خفيف JS (مجلد Templates)
TPL="$HOME/.local/share/xed-js-templates"
mkdir -p "$TPL/web"
cat > "$TPL/web/index.js" <<'JS'
console.log("Hello from template!");

// ضع هنا اختباراتك
JS

cat > "$TPL/web/README.txt" <<'TXT'
Template JS file for quick start.
To run: run_node.sh /path/to/index.js
TXT

# 8) إعداد ESLint افتراضي للمشروع (ملف .eslintrc.json في home كمثال)
cat > "$HOME/.eslintrc.json" <<'JSON'
{
  "env": { "es2021": true, "node": true, "browser": true },
  "extends": "eslint:recommended",
  "parserOptions": { "ecmaVersion": "latest", "sourceType": "module" },
  "rules": { "no-unused-vars": "warn", "no-console": "off" }
}
JSON

# 9) إضافة اختصار سطح المكتب لتشغيل Run/Debug من خارج Xed (يمكن ربطها بكيبورد)
cat > "$HOME/.local/share/applications/xed-run-node.desktop" <<DESK
[Desktop Entry]
Name=Run JS file (Xed helper)
Exec=$HOME/bin/run_node.sh %f
Type=Application
Terminal=false
Icon=utilities-terminal
Categories=Development;
DESK

cat > "$HOME/.local/share/applications/xed-debug-node.desktop" <<DESK
[Desktop Entry]
Name=Debug JS file (Xed helper)
Exec=$HOME/bin/debug_node.sh %f
Type=Application
Terminal=false
Icon=debug
Categories=Development;
DESK

# 10) (اختياري) إنشاء ملف autostart لفتح terminal drop-down عند تسجيل الدخول (مفيد كمخرجات دائمة)
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/js-output-terminal.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=JS Output Terminal (drop-down)
Exec=xfce4-terminal --drop-down
Hidden=false
X-GNOME-Autostart-enabled=true
DESK

# 11) تعليمات سريعة للمستخدم – سيطبعها السكربت في النهاية أيضاً
echo
echo "=== Done. What I installed/configured:"
echo "- xed editor"
echo "- xfce4-terminal (drop-down if supported)"
echo "- node/npm (if missing)"
echo "- eslint, typescript, typescript-language-server, tern (global npm tools)"
echo "- helper scripts in ~/bin: run_node.sh debug_node.sh autosave_on_blank.sh"
echo "- desktop launchers to run/debug from file manager"
echo "- project template at $TPL"
echo "- example ESLint config at ~/.eslintrc.json"
echo
echo "=== Next manual steps (2 minutes) to enable max features in Xed:"
echo "1) Open Xed, open the JS file you want to work on and save it as e.g. ~/projects/myproj/index.js"
echo "2) Start autosave for that file in background:"
echo "     ~/bin/autosave_on_blank.sh /full/path/to/your/index.js &"
echo "   (Now whenever you press Enter to create a blank line at end, the file saves automatically.)"
echo "3) To run file from outside or from file manager, right-click the file -> Open With -> choose 'Run JS file (Xed helper)'."
echo "4) To bind a keyboard shortcut in XFCE to run current file from Xed:"
echo "   - Open Settings -> Keyboard -> Application Shortcuts -> Add"
echo "   - For the Command use: $HOME/bin/run_node.sh %f"
echo "   - Press the shortcut you want (suggest Ctrl+Alt+R)."
echo "   - Do same for debug: $HOME/bin/debug_node.sh %f (suggest Ctrl+Alt+D)."
echo "5) For linting: in project folder run: npm install eslint --save-dev  (or use global eslint). Then run:"
echo "     eslint -f unix /full/path/to/your/file.js"
echo "   you can create a small script or file-manager action to run ESLint and see output in a terminal."
echo
echo "Notes:"
echo "- For full LSP/IntelliSense integration (autocomplete like VSCode), Xed needs external LSP client support or switching to a lightweight editor with LSP (Lite XL / Neovim + coc.nvim)."
echo "- The installed 'typescript-language-server' is ready if you later choose an editor that supports LSP or if you add an LSP bridge for Xed."
echo
echo "All done. Restart session (or run 'source ~/.profile') to load ~/bin into PATH, then open Xed and try it."
