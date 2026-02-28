# Layer 10: Border widget
# Wraps a single child with box-drawing characters.
# Shrinks content area by 1 on each side.

(import ./proto)
(import ../terminal/screen)
(import ../terminal/style)

(defn border
  ``Create a border widget wrapping one child.
   border-style: :single (default), :double, :rounded, :heavy, or :ascii
   title: optional string in top border
   title-align: :left (default), :center, or :right``
  [child &named id classes style border-style title title-align
   width height flex-grow flex-shrink margin padding dock]
  (default border-style :single)
  (default title-align :left)

  (def chars
    (case border-style
      :double  {:tl "\xE2\x95\x94" :tr "\xE2\x95\x97" :bl "\xE2\x95\x9A" :br "\xE2\x95\x9D"
                :h "\xE2\x95\x90" :v "\xE2\x95\x91"}
      :rounded {:tl "\xE2\x95\xAD" :tr "\xE2\x95\xAE" :bl "\xE2\x95\xB0" :br "\xE2\x95\xAF"
                :h "\xE2\x94\x80" :v "\xE2\x94\x82"}
      :heavy   {:tl "\xE2\x94\x8F" :tr "\xE2\x94\x93" :bl "\xE2\x94\x97" :br "\xE2\x94\x9B"
                :h "\xE2\x94\x81" :v "\xE2\x94\x83"}
      :ascii   {:tl "+" :tr "+" :bl "+" :br "+"
                :h "-" :v "|"}
      # :single (default)  - light box drawing
      {:tl "\xE2\x94\x8C" :tr "\xE2\x94\x90" :bl "\xE2\x94\x94" :br "\xE2\x94\x98"
       :h "\xE2\x94\x80" :v "\xE2\x94\x82"}))

  (def w (proto/make-widget
           "border"
           :id id
           :classes classes
           :style style
           :width width
           :height height
           :flex-grow flex-grow
           :flex-shrink flex-shrink
           :margin margin
           :padding (if padding
                      (if (number? padding)
                        (+ padding 1)
                        (let [[v h] padding] [(+ v 1) (+ h 1)]))
                      1)
           :dock dock
           :paint
           (fn [self scr rect]
             (def s (when (self :style)
                      (style/make-style ;(kvs (self :style)))))
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
                 (screen/screen-put scr (+ title-col (length display-title)) r1 " " s))))))

  (when child
    (proto/widget-add-child w child))
  w)
