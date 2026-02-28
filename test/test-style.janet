# Tests for chalk/terminal/style.janet

(import ../chalk/terminal/style)

(var pass 0)
(defn check [name & assertions]
  (each a assertions (assert a name))
  (++ pass))

# --- make-style ---

(check "make-style defaults"
  (let [s (style/make-style)]
    (and (nil? (s :fg))
         (nil? (s :bg))
         (= false (s :bold))
         (= false (s :dim))
         (= false (s :italic))
         (= false (s :underline))
         (= false (s :reverse)))))

(check "make-style with named params"
  (let [s (style/make-style :fg :red :bg :blue :bold true :underline true)]
    (and (= :red (s :fg))
         (= :blue (s :bg))
         (= true (s :bold))
         (= true (s :underline))
         (= false (s :dim))
         (= false (s :italic))
         (= false (s :reverse)))))

(check "make-style with RGB tuple"
  (let [s (style/make-style :fg [255 128 0])]
    (deep= (s :fg) [255 128 0])))

(check "make-style with 256-color number"
  (let [s (style/make-style :fg 42)]
    (= 42 (s :fg))))

# --- style= ---

(check "style= equal styles"
  (style/style= (style/make-style :fg :red :bold true)
                 (style/make-style :fg :red :bold true)))

(check "style= different fg"
  (not (style/style= (style/make-style :fg :red)
                      (style/make-style :fg :blue))))

(check "style= different bold"
  (not (style/style= (style/make-style :bold true)
                      (style/make-style :bold false))))

(check "style= both default"
  (style/style= (style/make-style) (style/make-style)))

# --- style-sgr ---

(check "style-sgr nil style returns 0"
  (= "0" (style/style-sgr nil)))

(check "style-sgr default style returns 0"
  (= "0" (style/style-sgr (style/make-style))))

(check "style-sgr bold"
  (= "0;1" (style/style-sgr (style/make-style :bold true))))

(check "style-sgr dim"
  (= "0;2" (style/style-sgr (style/make-style :dim true))))

(check "style-sgr italic"
  (= "0;3" (style/style-sgr (style/make-style :italic true))))

(check "style-sgr underline"
  (= "0;4" (style/style-sgr (style/make-style :underline true))))

(check "style-sgr reverse"
  (= "0;7" (style/style-sgr (style/make-style :reverse true))))

(check "style-sgr named fg color"
  (= "0;31" (style/style-sgr (style/make-style :fg :red))))

(check "style-sgr named bg color"
  (= "0;41" (style/style-sgr (style/make-style :bg :red))))

(check "style-sgr 256-color fg"
  (= "0;38;5;42" (style/style-sgr (style/make-style :fg 42))))

(check "style-sgr 256-color bg"
  (= "0;48;5;200" (style/style-sgr (style/make-style :bg 200))))

(check "style-sgr RGB fg"
  (= "0;38;2;255;128;0" (style/style-sgr (style/make-style :fg [255 128 0]))))

(check "style-sgr RGB bg"
  (= "0;48;2;10;20;30" (style/style-sgr (style/make-style :bg [10 20 30]))))

(check "style-sgr combined bold + red fg + blue bg"
  (= "0;1;31;44" (style/style-sgr (style/make-style :bold true :fg :red :bg :blue))))

(check "style-sgr all attributes"
  (= "0;1;2;3;4;7" (style/style-sgr (style/make-style :bold true :dim true :italic true :underline true :reverse true))))

# --- style-sequence ---

(check "style-sequence wraps sgr"
  (= "\e[0;1;31m" (style/style-sequence (style/make-style :bold true :fg :red))))

(check "style-sequence default"
  (= "\e[0m" (style/style-sequence (style/make-style))))

# --- reset-sequence ---

(check "reset-sequence"
  (= "\e[0m" (style/reset-sequence)))

# --- color maps ---

(check "color-fg-map has standard colors"
  (and (= 30 (get style/color-fg-map :black))
       (= 31 (get style/color-fg-map :red))
       (= 37 (get style/color-fg-map :white))
       (= 39 (get style/color-fg-map :default))))

(check "color-bg-map has standard colors"
  (and (= 40 (get style/color-bg-map :black))
       (= 41 (get style/color-bg-map :red))
       (= 47 (get style/color-bg-map :white))
       (= 49 (get style/color-bg-map :default))))

(check "color-fg-map has bright colors"
  (and (= 90 (get style/color-fg-map :bright-black))
       (= 97 (get style/color-fg-map :bright-white))))

(printf "  %d tests passed" pass)
