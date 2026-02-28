# Layer 6: Flex layout algorithm
# Recursively lays out a tree of layout nodes, setting :rect on each.
# All coordinates are 1-based.

(import ./box)

(defn- resolve-size
  "Resolve a size value (:auto, integer, or float percentage) against available space."
  [spec available]
  (cond
    (= spec :auto) available
    (and (number? spec) (< spec 1) (> spec 0)) (math/floor (* spec available))
    (number? spec) (math/floor spec)
    available))

(defn layout
  "Recursively lay out a node tree. Sets :rect on every node. Coords are 1-based."
  [node available-width available-height &opt root-col root-row]
  (default root-col 1)
  (default root-row 1)

  # Resolve this node's content size
  (def raw-w (resolve-size (node :width) available-width))
  (def raw-h (resolve-size (node :height) available-height))

  # Subtract margin for the allocation
  (def alloc-w (- (min raw-w available-width)
                   (node :margin-left) (node :margin-right)))
  (def alloc-h (- (min raw-h available-height)
                   (node :margin-top) (node :margin-bottom)))

  # Clamp
  (def node-w (box/clamp-size alloc-w (node :min-width) (node :max-width)))
  (def node-h (box/clamp-size alloc-h (node :min-height) (node :max-height)))

  # Set rect (position includes margin offset)
  (def rect @{:col (+ root-col (node :margin-left))
              :row (+ root-row (node :margin-top))
              :width node-w
              :height node-h})
  (put node :rect rect)

  # Content area (inside padding)
  (def content-col (+ (rect :col) (node :padding-left)))
  (def content-row (+ (rect :row) (node :padding-top)))
  (def content-w (- node-w (node :padding-left) (node :padding-right)))
  (def content-h (- node-h (node :padding-top) (node :padding-bottom)))

  (when (<= content-w 0) (break))
  (when (<= content-h 0) (break))

  (def children (node :children))
  (when (empty? children) (break))

  # Separate docked vs flex children
  (def docked @[])
  (def flex-children @[])
  (each child children
    (if (child :dock)
      (array/push docked child)
      (array/push flex-children child)))

  # Track remaining content area after docking
  (var dock-col content-col)
  (var dock-row content-row)
  (var dock-w content-w)
  (var dock-h content-h)

  # Process docked children
  (each child docked
    (case (child :dock)
      :top
      (let [ch (resolve-size (child :height) dock-h)]
        (layout child dock-w ch dock-col dock-row)
        (+= dock-row (get-in child [:rect :height]))
        (-= dock-h (get-in child [:rect :height])))

      :bottom
      (let [ch (resolve-size (child :height) dock-h)]
        (layout child dock-w ch dock-col (+ dock-row dock-h (- ch)))
        (-= dock-h (get-in child [:rect :height])))

      :left
      (let [cw (resolve-size (child :width) dock-w)]
        (layout child cw dock-h dock-col dock-row)
        (+= dock-col (get-in child [:rect :width]))
        (-= dock-w (get-in child [:rect :width])))

      :right
      (let [cw (resolve-size (child :width) dock-w)]
        (layout child cw dock-h (+ dock-col dock-w (- cw)) dock-row)
        (-= dock-w (get-in child [:rect :width])))))

  # Flex layout for remaining children
  (when (empty? flex-children) (break))

  (def direction (or (node :flex-direction) :column))
  (def main-size (if (= direction :column) dock-h dock-w))
  (def cross-size (if (= direction :column) dock-w dock-h))

  # First pass: measure natural sizes of children
  (def naturals @[])
  (var total-natural 0)
  (var total-grow 0)
  (var total-shrink 0)
  (each child flex-children
    (def child-spec (if (= direction :column) (child :height) (child :width)))
    (def nat (if (= child-spec :auto) 0 (resolve-size child-spec main-size)))
    (array/push naturals nat)
    (+= total-natural nat)
    (+= total-grow (child :flex-grow))
    (+= total-shrink (child :flex-shrink)))

  # Second pass: distribute space
  (def remaining (- main-size total-natural))
  (def sizes (array/new (length flex-children)))
  (for i 0 (length flex-children)
    (def child (get flex-children i))
    (def nat (get naturals i))
    (var sz nat)
    (if (> remaining 0)
      # Grow
      (when (> total-grow 0)
        (+= sz (math/floor (* remaining (/ (child :flex-grow) total-grow)))))
      # Shrink
      (when (and (< remaining 0) (> total-shrink 0))
        (+= sz (math/floor (* remaining (/ (child :flex-shrink) total-shrink))))))
    (set sz (max 0 sz))
    (array/push sizes sz))

  # If all children have 0 natural size and 0 grow, divide evenly
  (when (and (= total-natural 0) (= total-grow 0))
    (def each-size (math/floor (/ main-size (length flex-children))))
    (for i 0 (length flex-children)
      (put sizes i each-size)))

  # Third pass: assign positions and recurse
  (var main-pos (if (= direction :column) dock-row dock-col))
  (for i 0 (length flex-children)
    (def child (get flex-children i))
    (def sz (get sizes i))
    (if (= direction :column)
      (layout child dock-w sz dock-col main-pos)
      (layout child sz dock-h main-pos dock-row))
    (+= main-pos sz)))
