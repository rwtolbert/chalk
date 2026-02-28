# Layer 6: Layout nodes and box model
# A layout node is a mutable table with size constraints,
# box model (margin/padding), and a computed :rect.

(defn make-node
  "Create a layout node. margin/padding accept single int (all sides) or [v h]."
  [tag &named width height min-width max-width min-height max-height
   margin margin-top margin-right margin-bottom margin-left
   padding padding-top padding-right padding-bottom padding-left
   flex-direction flex-grow flex-shrink dock children]

  # Expand margin shorthand
  (var mt (or margin-top 0))
  (var mr (or margin-right 0))
  (var mb (or margin-bottom 0))
  (var ml (or margin-left 0))
  (when margin
    (if (indexed? margin)
      (let [[v h] margin]
        (set mt v) (set mb v)
        (set mr h) (set ml h))
      (do
        (set mt margin) (set mr margin)
        (set mb margin) (set ml margin))))

  # Expand padding shorthand
  (var pt (or padding-top 0))
  (var pr (or padding-right 0))
  (var pb (or padding-bottom 0))
  (var pl (or padding-left 0))
  (when padding
    (if (indexed? padding)
      (let [[v h] padding]
        (set pt v) (set pb v)
        (set pr h) (set pl h))
      (do
        (set pt padding) (set pr padding)
        (set pb padding) (set pl padding))))

  @{:tag tag
    :width (or width :auto)
    :height (or height :auto)
    :min-width (or min-width 0)
    :max-width (or max-width math/inf)
    :min-height (or min-height 0)
    :max-height (or max-height math/inf)
    :margin-top mt :margin-right mr
    :margin-bottom mb :margin-left ml
    :padding-top pt :padding-right pr
    :padding-bottom pb :padding-left pl
    :flex-direction (or flex-direction :column)
    :flex-grow (or flex-grow 0)
    :flex-shrink (or flex-shrink 1)
    :dock dock
    :children (or children @[])
    :rect nil})

(defn clamp-size
  "Clamp a size between min and max."
  [size min-size max-size]
  (min max-size (max min-size size)))

(defn outer-width
  "Total width including margin and padding."
  [node content-w]
  (+ content-w
     (node :margin-left) (node :margin-right)
     (node :padding-left) (node :padding-right)))

(defn outer-height
  "Total height including margin and padding."
  [node content-h]
  (+ content-h
     (node :margin-top) (node :margin-bottom)
     (node :padding-top) (node :padding-bottom)))

(defn content-rect
  "Return the content rect (inside padding) for a laid-out node."
  [node]
  (when-let [r (node :rect)]
    @{:col (+ (r :col) (node :padding-left))
      :row (+ (r :row) (node :padding-top))
      :width (- (r :width) (node :padding-left) (node :padding-right))
      :height (- (r :height) (node :padding-top) (node :padding-bottom))}))
