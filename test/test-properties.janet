# Tests for chalk/style/properties.janet

(import ../chalk/style/properties)

(var pass 0)
(defn check [name & assertions]
  (each a assertions (assert a name))
  (++ pass))

# --- parse-color ---

(check "parse-color named red"
       (= :red (properties/parse-color "red")))

(check "parse-color named bright-blue"
       (= :bright-blue (properties/parse-color "bright-blue")))

(check "parse-color named default"
       (= :default (properties/parse-color "default")))

(check "parse-color 6-digit hex"
       (deep= [255 128 0] (properties/parse-color "#ff8000")))

(check "parse-color 3-digit hex"
       (deep= [255 255 255] (properties/parse-color "#fff")))

(check "parse-color 3-digit hex #f00"
       (deep= [255 0 0] (properties/parse-color "#f00")))

(check "parse-color rgb()"
       (deep= [10 20 30] (properties/parse-color "rgb(10,20,30)")))

(check "parse-color rgb() with spaces"
       (deep= [10 20 30] (properties/parse-color "rgb(10, 20, 30)")))

(check "parse-color 256-color number"
       (= 42 (properties/parse-color "42")))

(check "parse-color 0 is valid"
       (= 0 (properties/parse-color "0")))

(check "parse-color 255 is valid"
       (= 255 (properties/parse-color "255")))

(check "parse-color invalid returns nil"
       (nil? (properties/parse-color "notacolor")))

(check "parse-color with leading/trailing whitespace"
       (= :red (properties/parse-color "  red  ")))

# --- parse-dimension ---

(check "parse-dimension auto"
       (= :auto (properties/parse-dimension "auto")))

(check "parse-dimension integer"
       (= 42 (properties/parse-dimension "42")))

(check "parse-dimension percentage"
       (= 0.5 (properties/parse-dimension "50%")))

(check "parse-dimension 100%"
       (= 1.0 (properties/parse-dimension "100%")))

(check "parse-dimension 25%"
       (= 0.25 (properties/parse-dimension "25%")))

# --- parse-bool ---

(check "parse-bool true"
       (= true (properties/parse-bool "true")))

(check "parse-bool yes"
       (= true (properties/parse-bool "yes")))

(check "parse-bool TRUE"
       (= true (properties/parse-bool "TRUE")))

(check "parse-bool YES"
       (= true (properties/parse-bool "YES")))

(check "parse-bool false"
       (= false (properties/parse-bool "false")))

(check "parse-bool no"
       (= false (properties/parse-bool "no")))

(check "parse-bool random string"
       (= false (properties/parse-bool "blah")))

# --- parse-property ---

(check "parse-property color"
       (let [[k v] (properties/parse-property "color" "red")]
         (and (= :fg k) (= :red v))))

(check "parse-property background"
       (let [[k v] (properties/parse-property "background" "#ff0000")]
         (and (= :bg k) (deep= [255 0 0] v))))

(check "parse-property bold"
       (let [[k v] (properties/parse-property "bold" "true")]
         (and (= :bold k) (= true v))))

(check "parse-property width"
       (let [[k v] (properties/parse-property "width" "80")]
         (and (= :width k) (= 80 v))))

(check "parse-property height auto"
       (let [[k v] (properties/parse-property "height" "auto")]
         (and (= :height k) (= :auto v))))

(check "parse-property flex-direction"
       (let [[k v] (properties/parse-property "flex-direction" "row")]
         (and (= :flex-direction k) (= :row v))))

(check "parse-property flex-grow"
       (let [[k v] (properties/parse-property "flex-grow" "2")]
         (and (= :flex-grow k) (= 2 v))))

(check "parse-property dock"
       (let [[k v] (properties/parse-property "dock" "top")]
         (and (= :dock k) (= :top v))))

(check "parse-property margin"
       (let [[k v] (properties/parse-property "margin" "5")]
         (and (= :margin k) (= 5 v))))

(check "parse-property padding-left"
       (let [[k v] (properties/parse-property "padding-left" "3")]
         (and (= :padding-left k) (= 3 v))))

(check "parse-property border-style"
       (let [[k v] (properties/parse-property "border-style" "rounded")]
         (and (= :border-style k) (= :rounded v))))

(check "parse-property border-color named"
       (let [[k v] (properties/parse-property "border-color" "cyan")]
         (and (= :border-color k) (= :cyan v))))

(check "parse-property border-color hex"
       (let [[k v] (properties/parse-property "border-color" "#ff0000")]
         (and (= :border-color k) (deep= [255 0 0] v))))

(check "parse-property border-title-align"
       (let [[k v] (properties/parse-property "border-title-align" "center")]
         (and (= :border-title-align k) (= :center v))))

(check "parse-property unknown returns nil"
       (nil? (properties/parse-property "unknown-prop" "whatever")))

# --- declarations-to-props ---

(check "declarations-to-props splits style and layout"
       (let [decls [{:property "color" :value "red"}
                    {:property "bold" :value "true"}
                    {:property "width" :value "80"}
                    {:property "margin" :value "2"}]
             result (properties/declarations-to-props decls)
             sp (result :style-props)
             lp (result :layout-props)]
         (and (= :red (sp :fg))
              (= true (sp :bold))
              (= 80 (lp :width))
              (= 2 (lp :margin)))))

(check "declarations-to-props nil input"
       (let [result (properties/declarations-to-props nil)]
         (and (deep= @{} (result :style-props))
              (deep= @{} (result :layout-props)))))

(check "declarations-to-props empty array"
       (let [result (properties/declarations-to-props @[])]
         (and (deep= @{} (result :style-props))
              (deep= @{} (result :layout-props)))))

(check "declarations-to-props border properties go to layout-props"
       (let [decls [{:property "border-style" :value "rounded"}
                    {:property "border-color" :value "cyan"}
                    {:property "border-title-align" :value "center"}]
             result (properties/declarations-to-props decls)
             lp (result :layout-props)]
         (and (= :rounded (lp :border-style))
              (= :cyan (lp :border-color))
              (= :center (lp :border-title-align)))))

(printf "  %d tests passed" pass)
