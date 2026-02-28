# Layer 10: Border widget
# Wraps a single child with box-drawing characters.
# Shrinks content area by 1 on each side.

(import ./proto)
(import ../terminal/screen)
(import ../terminal/style)

(defn border
  "Create a border widget wrapping one child.
   border-style: :single (default) or :double
   title: optional string in top border
   title-align: :left (default), :center, or :right"
  [child &named id classes style border-style title title-align
   width height flex-grow flex-shrink margin padding dock]
  (default border-style :single)
  (default title-align :left)

  (def chars
    (case border-style
      :double {:tl "+" :tr "+" :bl "+" :br "+"
               :h "=" :v "|"}
      # :single (default)
      {:tl "+" :tr "+" :bl "+" :br "+"
       :h "-" :v "|"}))

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
