# Layer 8: CSS property value parsing
# Converts CSS property strings to Janet values.

(def- named-colors
  {"black" :black "red" :red "green" :green "yellow" :yellow
   "blue" :blue "magenta" :magenta "cyan" :cyan "white" :white
   "bright-black" :bright-black "bright-red" :bright-red
   "bright-green" :bright-green "bright-yellow" :bright-yellow
   "bright-blue" :bright-blue "bright-magenta" :bright-magenta
   "bright-cyan" :bright-cyan "bright-white" :bright-white
   "default" :default})

(defn parse-color
  "Parse a color string: named, #hex, or rgb(r,g,b)."
  [s]
  (def trimmed (string/trim s))

  # Named color
  (when-let [c (get named-colors trimmed)]
    (break c))

  # 6-digit hex
  (when (and (string/has-prefix? "#" trimmed) (= (length trimmed) 7))
    (def r (scan-number (string "0x" (string/slice trimmed 1 3))))
    (def g (scan-number (string "0x" (string/slice trimmed 3 5))))
    (def b (scan-number (string "0x" (string/slice trimmed 5 7))))
    (when (and r g b) (break [r g b])))

  # 3-digit hex
  (when (and (string/has-prefix? "#" trimmed) (= (length trimmed) 4))
    (def r (scan-number (string "0x" (string/slice trimmed 1 2) (string/slice trimmed 1 2))))
    (def g (scan-number (string "0x" (string/slice trimmed 2 3) (string/slice trimmed 2 3))))
    (def b (scan-number (string "0x" (string/slice trimmed 3 4) (string/slice trimmed 3 4))))
    (when (and r g b) (break [r g b])))

  # rgb(r,g,b)
  (when (string/has-prefix? "rgb(" trimmed)
    (def inner (string/slice trimmed 4 (- (length trimmed) 1)))
    (def parts (map string/trim (string/split "," inner)))
    (when (= (length parts) 3)
      (def r (scan-number (get parts 0)))
      (def g (scan-number (get parts 1)))
      (def b (scan-number (get parts 2)))
      (when (and r g b) (break [r g b]))))

  # 256-color number
  (def n (scan-number trimmed))
  (when (and n (>= n 0) (<= n 255))
    (break n))

  nil)

(defn parse-dimension
  "Parse a dimension: 'auto', integer, or percentage (e.g. '50%')."
  [s]
  (def trimmed (string/trim s))
  (if (= trimmed "auto")
    :auto
    (if (string/has-suffix? "%" trimmed)
      (do
        (def n (scan-number (string/slice trimmed 0 (- (length trimmed) 1))))
        (when n (/ n 100)))
      (scan-number trimmed))))

(defn parse-bool
  "Parse a boolean property: 'true'/'yes' → true, else false."
  [s]
  (def trimmed (string/trim (string/ascii-lower s)))
  (or (= trimmed "true") (= trimmed "yes")))

(defn parse-property
  "Parse a CSS property name+value into [keyword parsed-value] or nil."
  [name value-str]
  (case name
    # Style properties
    "color" [:fg (parse-color value-str)]
    "background" [:bg (parse-color value-str)]
    "bold" [:bold (parse-bool value-str)]
    "dim" [:dim (parse-bool value-str)]
    "italic" [:italic (parse-bool value-str)]
    "underline" [:underline (parse-bool value-str)]
    "reverse" [:reverse (parse-bool value-str)]

    # Layout properties
    "width" [:width (parse-dimension value-str)]
    "height" [:height (parse-dimension value-str)]
    "min-width" [:min-width (parse-dimension value-str)]
    "max-width" [:max-width (parse-dimension value-str)]
    "min-height" [:min-height (parse-dimension value-str)]
    "max-height" [:max-height (parse-dimension value-str)]
    "flex-direction" [:flex-direction (keyword (string/trim value-str))]
    "flex-grow" [:flex-grow (or (scan-number value-str) 0)]
    "flex-shrink" [:flex-shrink (or (scan-number value-str) 1)]
    "dock" [:dock (keyword (string/trim value-str))]

    # Margin shorthand
    "margin" [:margin (or (scan-number value-str) 0)]
    "margin-top" [:margin-top (or (scan-number value-str) 0)]
    "margin-right" [:margin-right (or (scan-number value-str) 0)]
    "margin-bottom" [:margin-bottom (or (scan-number value-str) 0)]
    "margin-left" [:margin-left (or (scan-number value-str) 0)]

    # Padding shorthand
    "padding" [:padding (or (scan-number value-str) 0)]
    "padding-top" [:padding-top (or (scan-number value-str) 0)]
    "padding-right" [:padding-right (or (scan-number value-str) 0)]
    "padding-bottom" [:padding-bottom (or (scan-number value-str) 0)]
    "padding-left" [:padding-left (or (scan-number value-str) 0)]

    # Border properties
    "border-style" [:border-style (keyword (string/trim value-str))]
    "border-color" [:border-color (parse-color value-str)]
    "border-title-align" [:border-title-align (keyword (string/trim value-str))]

    nil))

(def- style-keys
  [:fg :bg :bold :dim :italic :underline :reverse])

(def- layout-keys
  [:width :height :min-width :max-width :min-height :max-height
   :flex-direction :flex-grow :flex-shrink :dock
   :margin :margin-top :margin-right :margin-bottom :margin-left
   :padding :padding-top :padding-right :padding-bottom :padding-left
   :border-style :border-color :border-title-align])

(defn declarations-to-props
  "Convert an array of {:property :value} declarations to {:style-props {...} :layout-props {...}}."
  [decls]
  (def style-props @{})
  (def layout-props @{})
  (when (nil? decls) (break {:style-props style-props :layout-props layout-props}))
  (each decl decls
    (when-let [pair (parse-property (decl :property) (decl :value))]
      (def [k v] pair)
      (if (find |(= $ k) style-keys)
        (put style-props k v)
        (put layout-props k v))))
  {:style-props style-props :layout-props layout-props})
