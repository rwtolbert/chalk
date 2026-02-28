# Layer 7: Full render pipeline
# Orchestrates: build-layout-tree → flex/layout → screen-clear → paint-tree → screen-render

(import ./proto)
(import ../layout/box)
(import ../layout/flex)
(import ../terminal/screen)

(defn- paint-tree
  "Depth-first paint: paint self, then children."
  [scr widget]
  (when-let [node (widget :layout-node)
             rect (node :rect)]
    # Paint self
    (when (widget :paint)
      ((widget :paint) widget scr rect))
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
