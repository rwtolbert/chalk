# Border drawing utilities
# Shared border character tables and paint function used by
# both the border wrapper widget and property-based borders.

(import ../terminal/screen)

(def border-chars
  ```Map of border style keywords to character tables.
   Each table has :tl :tr :bl :br :h :v keys.```
  {:single {:tl "\xE2\x94\x8C" :tr "\xE2\x94\x90" :bl "\xE2\x94\x94" :br "\xE2\x94\x98"
            :h "\xE2\x94\x80" :v "\xE2\x94\x82"}
   :double {:tl "\xE2\x95\x94" :tr "\xE2\x95\x97" :bl "\xE2\x95\x9A" :br "\xE2\x95\x9D"
            :h "\xE2\x95\x90" :v "\xE2\x95\x91"}
   :rounded {:tl "\xE2\x95\xAD" :tr "\xE2\x95\xAE" :bl "\xE2\x95\xB0" :br "\xE2\x95\xAF"
             :h "\xE2\x94\x80" :v "\xE2\x94\x82"}
   :heavy {:tl "\xE2\x94\x8F" :tr "\xE2\x94\x93" :bl "\xE2\x94\x97" :br "\xE2\x94\x9B"
           :h "\xE2\x94\x81" :v "\xE2\x94\x83"}
   :ascii {:tl "+" :tr "+" :bl "+" :br "+"
           :h "-" :v "|"}})

(defn paint-border
  ```Draw a border frame with optional title.
   scr: screen buffer
   rect: {:col :row :width :height}
   border-style: keyword (:single :double :rounded :heavy :ascii)
   s: pre-compiled style (from style/make-style) or nil
   title: optional string
   title-align: :left (default), :center, or :right```
  [scr rect border-style s &opt title title-align]
  (default title-align :left)
  (def chars (get border-chars border-style (border-chars :single)))
  (def c1 (rect :col))
  (def r1 (rect :row))
  (def c2 (+ c1 (rect :width) -1))
  (def r2 (+ r1 (rect :height) -1))

  (when (and (> (rect :width) 1) (> (rect :height) 1))
    # Corners
    (screen/screen-put scr c1 r1 (chars :tl) s)
    (screen/screen-put scr c2 r1 (chars :tr) s)
    (screen/screen-put scr c1 r2 (chars :bl) s)
    (screen/screen-put scr c2 r2 (chars :br) s)

    # Horizontal lines
    (for c (+ c1 1) c2
      (screen/screen-put scr c r1 (chars :h) s)
      (screen/screen-put scr c r2 (chars :h) s))

    # Vertical lines
    (for r (+ r1 1) r2
      (screen/screen-put scr c1 r (chars :v) s)
      (screen/screen-put scr c2 r (chars :v) s))

    # Title
    (when (and title (> (rect :width) 4))
      (def max-title-w (- (rect :width) 4))
      (def display-title (if (> (length title) max-title-w)
                           (string/slice title 0 max-title-w)
                           title))
      (def title-col
        (case title-align
          :center (+ c1 (math/floor (/ (- (rect :width) (length display-title)) 2)))
          :right (- c2 (length display-title) 1)
          # :left default
          (+ c1 2)))
      (screen/screen-put scr (- title-col 1) r1 " " s)
      (screen/screen-put-string scr title-col r1 display-title s)
      (screen/screen-put scr (+ title-col (length display-title)) r1 " " s))))
