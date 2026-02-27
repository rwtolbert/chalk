# Layer 2: Buffered escape sequence builder
# All writes accumulate in a buffer, flushed once per frame.

(import ./style)
(import ../platform/init :as platform)

(var buf @"")

(defn flush
  "Write accumulated buffer to stdout and clear it."
  []
  (when (> (length buf) 0)
    (platform/write-stdout buf)
    (buffer/clear buf)))

# --- Cursor movement ---

(defn move-to
  "Move cursor to col, row (1-based)."
  [col row]
  (buffer/push buf (string/format "\e[%d;%dH" row col)))

(defn home
  "Move cursor to top-left corner."
  []
  (buffer/push buf "\e[H"))

(defn move-up
  "Move cursor up n lines."
  [&opt n]
  (default n 1)
  (buffer/push buf (string/format "\e[%dA" n)))

(defn move-down
  "Move cursor down n lines."
  [&opt n]
  (default n 1)
  (buffer/push buf (string/format "\e[%dB" n)))

(defn move-right
  "Move cursor right n columns."
  [&opt n]
  (default n 1)
  (buffer/push buf (string/format "\e[%dC" n)))

(defn move-left
  "Move cursor left n columns."
  [&opt n]
  (default n 1)
  (buffer/push buf (string/format "\e[%dD" n)))

# --- Screen clearing ---

(defn clear-screen
  "Clear the entire screen."
  []
  (buffer/push buf "\e[2J"))

(defn clear-line
  "Clear the entire current line."
  []
  (buffer/push buf "\e[2K"))

(defn clear-to-eol
  "Clear from cursor to end of line."
  []
  (buffer/push buf "\e[K"))

# --- Cursor visibility ---

(defn hide-cursor
  "Hide the cursor."
  []
  (buffer/push buf "\e[?25l"))

(defn show-cursor
  "Show the cursor."
  []
  (buffer/push buf "\e[?25h"))

# --- Alternate screen ---

(defn enter-alt-screen
  "Switch to alternate screen buffer."
  []
  (buffer/push buf "\e[?1049h"))

(defn exit-alt-screen
  "Switch back to main screen buffer."
  []
  (buffer/push buf "\e[?1049l"))

# --- Mouse ---

(defn enable-mouse
  "Enable mouse tracking (SGR extended mode)."
  []
  (buffer/push buf "\e[?1000h\e[?1006h"))

(defn disable-mouse
  "Disable mouse tracking."
  []
  (buffer/push buf "\e[?1006l\e[?1000l"))

# --- Style ---

(defn set-style
  "Set text style using a style struct."
  [s]
  (buffer/push buf (style/style-sequence s)))

(defn reset-style
  "Reset all text attributes."
  []
  (buffer/push buf "\e[0m"))

(defn put-text
  "Write plain text to the buffer (no style change)."
  [text]
  (buffer/push buf text))

(defn put-styled
  "Write text with a style, then reset."
  [text s]
  (set-style s)
  (buffer/push buf text)
  (reset-style))
