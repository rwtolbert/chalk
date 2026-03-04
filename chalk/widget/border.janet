# Layer 10: Border widget
# Wraps a single child with box-drawing characters.
# Shrinks content area by 1 on each side.

(import ./proto)
(import ./border-util)
(import ../terminal/style)

(defn border
  ```Create a border widget wrapping one child.
   border-style: :single (default), :double, :rounded, :heavy, or :ascii
   title: optional string in top border
   title-align: :left (default), :center, or :right```
  [child &named id classes style border-style title title-align
   width height flex-grow flex-shrink margin padding dock]
  (default border-style :single)
  (default title-align :left)

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
             (def t (get (self :state) :title))
             (def ta (get (self :state) :title-align :left))
             (border-util/paint-border scr rect
                                       (get (self :state) :border-style :single)
                                       s t ta))))

  # Store title/title-align/border-style in state for dynamic updates
  (put (w :state) :title title)
  (put (w :state) :title-align (or title-align :left))
  (put (w :state) :border-style border-style)

  (when child
    (proto/widget-add-child w child))
  w)
