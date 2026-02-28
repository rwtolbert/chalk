# Layer 7: Widget protocol and tree utilities
# A widget is a mutable table with well-known keys for type, state,
# lifecycle hooks, layout node, children, and parent.

(import ../layout/box)

(defn make-widget
  "Create a widget table. Layout-related named args are forwarded to layout node creation."
  [type &named id classes style width height min-width max-width min-height max-height
   margin margin-top margin-right margin-bottom margin-left
   padding padding-top padding-right padding-bottom padding-left
   flex-direction flex-grow flex-shrink dock
   mount unmount render paint handle-event update]
  @{:type type
    :id id
    :classes (or classes @[])
    :state @{}
    :style style
    :layout-node nil
    :children @[]
    :parent nil
    :mounted false
    # Layout props stored for build-layout-tree
    :width (or width :auto)
    :height (or height :auto)
    :min-width min-width
    :max-width max-width
    :min-height min-height
    :max-height max-height
    :margin margin
    :margin-top margin-top
    :margin-right margin-right
    :margin-bottom margin-bottom
    :margin-left margin-left
    :padding padding
    :padding-top padding-top
    :padding-right padding-right
    :padding-bottom padding-bottom
    :padding-left padding-left
    :flex-direction flex-direction
    :flex-grow flex-grow
    :flex-shrink flex-shrink
    :dock dock
    # Lifecycle hooks
    :mount mount
    :unmount unmount
    :render render
    :paint paint
    :handle-event handle-event
    :update update})

(defn widget-add-child
  "Add a child widget to a parent."
  [parent child]
  (put child :parent parent)
  (array/push (parent :children) child)
  child)

(defn widget-remove-child
  "Remove a child widget from its parent."
  [parent child]
  (def children (parent :children))
  (def idx (find-index |(= $ child) children))
  (when idx
    (array/remove children idx)
    (put child :parent nil))
  child)

(defn build-layout-tree
  "Create a layout node tree from a widget tree. Attaches :layout-node to each widget."
  [widget]
  (def node (box/make-node
              (widget :type)
              :width (widget :width)
              :height (widget :height)
              :min-width (widget :min-width)
              :max-width (widget :max-width)
              :min-height (widget :min-height)
              :max-height (widget :max-height)
              :margin (widget :margin)
              :margin-top (widget :margin-top)
              :margin-right (widget :margin-right)
              :margin-bottom (widget :margin-bottom)
              :margin-left (widget :margin-left)
              :padding (widget :padding)
              :padding-top (widget :padding-top)
              :padding-right (widget :padding-right)
              :padding-bottom (widget :padding-bottom)
              :padding-left (widget :padding-left)
              :flex-direction (widget :flex-direction)
              :flex-grow (widget :flex-grow)
              :flex-shrink (widget :flex-shrink)
              :dock (widget :dock)))
  (put widget :layout-node node)
  (each child (widget :children)
    (def child-node (build-layout-tree child))
    (array/push (node :children) child-node))
  node)

(defn mount-tree
  "Recursively mount a widget tree (call :mount hooks depth-first, children first)."
  [widget]
  (each child (widget :children)
    (mount-tree child))
  (when (and (widget :mount) (not (widget :mounted)))
    ((widget :mount) widget))
  (put widget :mounted true))

(defn unmount-tree
  "Recursively unmount a widget tree (children first)."
  [widget]
  (each child (widget :children)
    (unmount-tree child))
  (when (and (widget :unmount) (widget :mounted))
    ((widget :unmount) widget))
  (put widget :mounted false))

(defn in-rect?
  "Test if (col, row) is inside a rect (1-based)."
  [rect col row]
  (and (>= col (rect :col))
       (< col (+ (rect :col) (rect :width)))
       (>= row (rect :row))
       (< row (+ (rect :row) (rect :height)))))

(defn find-by-id
  "Find a widget by :id in the tree (depth-first)."
  [root id]
  (if (= (root :id) id)
    root
    (do
      (var found nil)
      (each child (root :children)
        (when (not found)
          (set found (find-by-id child id))))
      found)))

(defn dispatch-event
  ```Deliver an event to the widget tree.
   Mouse events hit-test rects (deepest match wins).
   Key events go to root.
   Handlers return {:msg m} to bubble to parent's :update.```
  [root event]
  (var target nil)
  (var result nil)

  (case (event :type)
    :mouse
    (do
      # Find deepest widget whose rect contains the mouse position
      (defn find-target [widget]
        (when-let [node (widget :layout-node)
                   rect (node :rect)]
          (when (in-rect? rect (event :col) (event :row))
            (set target widget)
            (each child (widget :children)
              (find-target child)))))
      (find-target root)
      (when (and target (target :handle-event))
        (set result ((target :handle-event) target event))))

    :key
    (when (root :handle-event)
      (set result ((root :handle-event) root event)))

    :resize
    (when (root :handle-event)
      (set result ((root :handle-event) root event))))

  # Bubble messages up to parent's :update
  (when (and result (get result :msg) target)
    (var w (target :parent))
    (while w
      (when (w :update)
        ((w :update) w (result :msg)))
      (set w (w :parent))))

  result)
