# Layer 2: Colors and text attributes  - SGR code generation

# Named color map: keyword -> SGR foreground index
(def color-fg-map
  {:black 30 :red 31 :green 32 :yellow 33
   :blue 34 :magenta 35 :cyan 36 :white 37
   :bright-black 90 :bright-red 91 :bright-green 92 :bright-yellow 93
   :bright-blue 94 :bright-magenta 95 :bright-cyan 96 :bright-white 97
   :default 39})

(def color-bg-map
  {:black 40 :red 41 :green 42 :yellow 43
   :blue 44 :magenta 45 :cyan 46 :white 47
   :bright-black 100 :bright-red 101 :bright-green 102 :bright-yellow 103
   :bright-blue 104 :bright-magenta 105 :bright-cyan 106 :bright-white 107
   :default 49})

(def default-style
  {:fg nil :bg nil
   :bold false :dim false :italic false
   :underline false :reverse false})

(defn make-style
  ```Create a style struct. Options: :fg :bg :bold :dim :italic :underline :reverse.
   Colors can be keywords (:red), numbers (0-255), or [r g b] tuples.```
  [&named fg bg bold dim italic underline reverse]
  {:fg fg :bg bg
   :bold (or bold false)
   :dim (or dim false)
   :italic (or italic false)
   :underline (or underline false)
   :reverse (or reverse false)})

(defn style=
  "Compare two styles for equality."
  [a b]
  (and (= (a :fg) (b :fg))
       (= (a :bg) (b :bg))
       (= (a :bold) (b :bold))
       (= (a :dim) (b :dim))
       (= (a :italic) (b :italic))
       (= (a :underline) (b :underline))
       (= (a :reverse) (b :reverse))))

(defn- color-sgr-codes
  "Return SGR code(s) for a color value in fg or bg position."
  [color is-bg]
  (cond
    (nil? color) @[]
    (keyword? color)
    (let [m (if is-bg color-bg-map color-fg-map)]
      @[(string (get m color (if is-bg 49 39)))])
    (number? color)
    @[(string (if is-bg 48 38)) "5" (string color)]
    (indexed? color)
    (let [[r g b] color]
      @[(string (if is-bg 48 38)) "2"
        (string r) (string g) (string b)])
    @[]))

(defn style-sgr
  "Build the SGR parameter string for a style (e.g. \"0;1;31\").
   Always starts with reset (0) so attributes from previous styles are cleared."
  [style]
  (when (nil? style) (break "0"))
  (def codes @["0"])
  (when (style :bold) (array/push codes "1"))
  (when (style :dim) (array/push codes "2"))
  (when (style :italic) (array/push codes "3"))
  (when (style :underline) (array/push codes "4"))
  (when (style :reverse) (array/push codes "7"))
  (array/concat codes (color-sgr-codes (style :fg) false))
  (array/concat codes (color-sgr-codes (style :bg) true))
  (string/join codes ";"))

(defn style-sequence
  "Return the full ANSI escape sequence string for a style."
  [style]
  (string "\e[" (style-sgr style) "m"))

(defn reset-sequence
  "Return the SGR reset sequence."
  []
  "\e[0m")
