# Theme system for chalk applications
# Provides semantic color roles, built-in palettes, and palette access.

# --- Theme registry ---

(def- themes @{})

(defn deftheme
  ```Register a theme palette under a name.
  The palette is a table mapping semantic color roles to color values.
  Color values can be keywords (:red, :default), numbers (0-255),
  RGB tuples ([r g b]), or hex strings ("#ff0000").

  Roles:
    :fg :bg              main text and background
    :primary :secondary  accent colors
    :muted               dim/placeholder text
    :border              normal borders
    :border-active       focused/active borders
    :surface             panel/widget backgrounds
    :surface-alt         contrasting areas (headers, footers)
    :success :warning :error  semantic status colors```
  [name palette]
  (put themes name palette)
  palette)

(defn list-themes
  "Return a sorted array of all registered theme names."
  []
  (sort (keys themes)))

# --- Palette access ---

(defn palette
  ```Return the resolved palette table for a theme, with defaults filled in
  for any missing roles. Returns a mutable table.

  Example:
    (def p (theme/palette :dracula))
    (text/text "hello" :style {:fg (p :primary)})
    (list/list-widget :border-color (p :border-active))```
  [&opt theme-name]
  (default theme-name :default)
  (def raw (get themes theme-name))
  (unless raw
    (errorf "unknown theme: %s (available: %s)"
            theme-name (string/join (map string (list-themes)) ", ")))
  @{:fg (or (raw :fg) :default)
    :bg (or (raw :bg) :default)
    :primary (or (raw :primary) :cyan)
    :secondary (or (raw :secondary) :blue)
    :muted (or (raw :muted) :bright-black)
    :border (or (raw :border) (or (raw :fg) :default))
    :border-active (or (raw :border-active) (or (raw :primary) :cyan))
    :surface (or (raw :surface) (or (raw :bg) :default))
    :surface-alt (or (raw :surface-alt) :bright-black)
    :success (or (raw :success) :green)
    :warning (or (raw :warning) :yellow)
    :error (or (raw :error) :red)})

(defn color
  ```Format a palette color value as a string suitable for embedding in CSS.
  Convenience for building CSS strings with theme colors.

  Example:
    (def p (theme/palette :dracula))
    (string "background: " (theme/color p :bg) ";")```
  [palette-table role]
  (def c (get palette-table role))
  (cond
    (keyword? c) (string c)
    (number? c) (string c)
    (tuple? c) (string/format "rgb(%d,%d,%d)"
                              (get c 0) (get c 1) (get c 2))
    (array? c) (string/format "rgb(%d,%d,%d)"
                              (get c 0) (get c 1) (get c 2))
    (string? c) c
    "default"))

# --- Built-in themes ---

# Default: uses terminal's own fg/bg via :default, works in light and dark
(deftheme :default
  {:fg :default
   :bg :default
   :primary :cyan
   :secondary :blue
   :muted :bright-black
   :border :default
   :border-active :cyan
   :surface :default
   :surface-alt :bright-black
   :success :green
   :warning :yellow
   :error :red})

# Dark: explicit ANSI colors for dark terminal backgrounds
(deftheme :dark
  {:fg :white
   :bg :black
   :primary :cyan
   :secondary :blue
   :muted :bright-black
   :border :white
   :border-active :cyan
   :surface :black
   :surface-alt :bright-black
   :success :green
   :warning :yellow
   :error :red})

# Light: explicit ANSI colors for light terminal backgrounds
(deftheme :light
  {:fg :black
   :bg :white
   :primary :blue
   :secondary :magenta
   :muted :bright-black
   :border :black
   :border-active :blue
   :surface :white
   :surface-alt :bright-white
   :success :green
   :warning :red
   :error :red})

# Catppuccin Mocha (dark)
(deftheme :catppuccin-mocha
  {:fg [205 214 244]
   :bg [30 30 46]
   :primary [137 180 250]
   :secondary [180 190 254]
   :muted [108 112 134]
   :border [88 91 112]
   :border-active [137 180 250]
   :surface [30 30 46]
   :surface-alt [49 50 68]
   :success [166 227 161]
   :warning [249 226 175]
   :error [243 139 168]})

# Catppuccin Latte (light)
(deftheme :catppuccin-latte
  {:fg [76 79 105]
   :bg [239 241 245]
   :primary [30 102 245]
   :secondary [114 135 253]
   :muted [140 143 161]
   :border [172 176 190]
   :border-active [30 102 245]
   :surface [239 241 245]
   :surface-alt [230 233 239]
   :success [64 160 43]
   :warning [223 142 29]
   :error [210 15 57]})

# Dracula
(deftheme :dracula
  {:fg [248 248 242]
   :bg [40 42 54]
   :primary [139 233 253]
   :secondary [189 147 249]
   :muted [98 114 164]
   :border [68 71 90]
   :border-active [139 233 253]
   :surface [40 42 54]
   :surface-alt [68 71 90]
   :success [80 250 123]
   :warning [241 250 140]
   :error [255 85 85]})

# Solarized Dark
(deftheme :solarized-dark
  {:fg [131 148 150]
   :bg [0 43 54]
   :primary [38 139 210]
   :secondary [108 113 196]
   :muted [88 110 117]
   :border [88 110 117]
   :border-active [38 139 210]
   :surface [0 43 54]
   :surface-alt [7 54 66]
   :success [133 153 0]
   :warning [181 137 0]
   :error [220 50 47]})

# Solarized Light
(deftheme :solarized-light
  {:fg [101 123 131]
   :bg [253 246 227]
   :primary [38 139 210]
   :secondary [108 113 196]
   :muted [147 161 161]
   :border [147 161 161]
   :border-active [38 139 210]
   :surface [253 246 227]
   :surface-alt [238 232 213]
   :success [133 153 0]
   :warning [181 137 0]
   :error [220 50 47]})

# Nord
(deftheme :nord
  {:fg [216 222 233]
   :bg [46 52 64]
   :primary [136 192 208]
   :secondary [129 161 193]
   :muted [76 86 106]
   :border [76 86 106]
   :border-active [136 192 208]
   :surface [46 52 64]
   :surface-alt [59 66 82]
   :success [163 190 140]
   :warning [235 203 139]
   :error [191 97 106]})

# Gruvbox Dark
(deftheme :gruvbox-dark
  {:fg [235 219 178]
   :bg [40 40 40]
   :primary [131 165 152]
   :secondary [211 134 155]
   :muted [146 131 116]
   :border [102 92 84]
   :border-active [131 165 152]
   :surface [40 40 40]
   :surface-alt [60 56 54]
   :success [184 187 38]
   :warning [250 189 47]
   :error [251 73 52]})

# Gruvbox Light
(deftheme :gruvbox-light
  {:fg [60 56 54]
   :bg [251 241 199]
   :primary [69 133 136]
   :secondary [177 98 134]
   :muted [146 131 116]
   :border [168 153 132]
   :border-active [69 133 136]
   :surface [251 241 199]
   :surface-alt [242 229 188]
   :success [121 116 14]
   :warning [181 118 20]
   :error [204 36 29]})

# Tokyo Night
(deftheme :tokyo-night
  {:fg [169 177 214]
   :bg [26 27 38]
   :primary [122 162 247]
   :secondary [187 154 247]
   :muted [84 88 122]
   :border [59 63 87]
   :border-active [122 162 247]
   :surface [26 27 38]
   :surface-alt [42 44 62]
   :success [115 218 202]
   :warning [224 175 104]
   :error [247 118 142]})
