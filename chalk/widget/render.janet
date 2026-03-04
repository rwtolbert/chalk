# Layer 7: Full render pipeline
# Orchestrates: build-layout-tree -> flex/layout -> screen-clear -> paint-tree -> screen-render

(import ./proto)
(import ./border-util)
(import ../layout/box)
(import ../layout/flex)
(import ../terminal/screen)
(import ../terminal/style)

(defn- paint-tree
  "Depth-first paint: paint self (with border if set), then children."
  [scr widget]
  (when-let [node (widget :layout-node)
             rect (node :rect)]
    (def bs (widget :border-style))
    # Draw border frame if widget has one
    (when bs
      (def border-s
        (if-let [bc (widget :border-color)]
          (style/make-style :fg bc)
          (when (widget :style)
            (style/make-style ;(kvs (widget :style))))))
      (border-util/paint-border scr rect bs border-s
                                (widget :border-title)
                                (or (widget :border-title-align) :left)))
    # Widget's paint gets inner rect (inside border) or full rect
    (def paint-rect
      (if bs
        @{:col (+ (rect :col) 1) :row (+ (rect :row) 1)
          :width (- (rect :width) 2) :height (- (rect :height) 2)}
        rect))
    # Store content rect for mouse hit-testing in widget event handlers
    (put widget :content-rect paint-rect)
    # Paint self
    (when (widget :paint)
      ((widget :paint) widget scr paint-rect))
    # Paint children (content area)
    (each child (widget :children)
      (paint-tree scr child))))

(defn render-tree
  "Full render pipeline: layout, clear, paint, render."
  [scr root width height]
  (def layout-root (proto/build-layout-tree root))
  (flex/layout layout-root width height)
  (screen/screen-clear scr)
  (paint-tree scr root)
  (screen/screen-render scr))
