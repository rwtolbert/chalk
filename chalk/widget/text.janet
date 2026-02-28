# Layer 7: Text widget
# Displays text content, clipped to its layout rect.
# Inherits style from ancestor containers when no own style is set.

(import ./proto)
(import ../terminal/screen)
(import ../terminal/style)

(defn- resolve-effective-style
  "Walk up parent chain to find an inherited style, merge with own style."
  [widget]
  # Find nearest ancestor style
  (var base nil)
  (var p (widget :parent))
  (while (and p (nil? base))
    (when (p :style)
      (set base (p :style)))
    (set p (p :parent)))

  (def own (widget :style))
  (cond
    (and base own) (style/make-style ;(kvs (merge base own)))
    own (style/make-style ;(kvs own))
    base (style/make-style ;(kvs base))
    nil))

(defn text
  ``Create a text widget. Content is a string displayed within the rect.
   text-align: :left (default), :center, or :right``
  [content &named id classes style width height flex-grow flex-shrink
   margin padding dock text-align]
  (def lines (string/split "\n" content))
  (default text-align :left)

  (proto/make-widget
    "text"
    :id id
    :classes classes
    :style style
    :width (or width :auto)
    :height (or height (length lines))
    :flex-grow flex-grow
    :flex-shrink flex-shrink
    :margin margin
    :padding padding
    :dock dock
    :paint
    (fn [self scr rect]
      (def s (resolve-effective-style self))
      (def max-col (+ (rect :col) (rect :width)))
      (def max-row (+ (rect :row) (rect :height)))
      # Fill background across full rect width
      (when s
        (for i 0 (rect :height)
          (def row (+ (rect :row) i))
          (when (>= row max-row) (break))
          (for col (rect :col) max-col
            (screen/screen-put scr col row " " s))))
      # Paint text content
      (for i 0 (length lines)
        (def row (+ (rect :row) i))
        (when (>= row max-row) (break))
        (def line (get lines i))
        (def line-len (length line))
        (def col-start
          (case text-align
            :center (+ (rect :col) (math/floor (/ (- (rect :width) line-len) 2)))
            :right (+ (rect :col) (- (rect :width) line-len))
            (rect :col)))
        (var col (max col-start (rect :col)))
        (each byte line
          (when (>= col max-col) (break))
          (screen/screen-put scr col row (string/from-bytes byte) s)
          (++ col))))))
