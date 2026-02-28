# Tests for chalk/layout/flex.janet

(import ../chalk/layout/box)
(import ../chalk/layout/flex)

(var pass 0)
(defn check [name & assertions]
  (each a assertions (assert a name))
  (++ pass))

# --- Root sizing ---

(check "root auto fills available"
  (let [n (box/make-node :root)]
    (flex/layout n 80 24)
    (let [r (n :rect)]
      (and (= 1 (r :col))
           (= 1 (r :row))
           (= 80 (r :width))
           (= 24 (r :height))))))

(check "root fixed size"
  (let [n (box/make-node :root :width 40 :height 10)]
    (flex/layout n 80 24)
    (let [r (n :rect)]
      (and (= 40 (r :width))
           (= 10 (r :height))))))

(check "root percentage size"
  (let [n (box/make-node :root :width 0.5 :height 0.5)]
    (flex/layout n 80 24)
    (let [r (n :rect)]
      (and (= 40 (r :width))
           (= 12 (r :height))))))

# --- Margin offsets ---

(check "margin offsets rect position"
  (let [n (box/make-node :root :margin [2 5])]
    (flex/layout n 80 24)
    (let [r (n :rect)]
      (and (= 6 (r :col))
           (= 3 (r :row))
           (= 70 (r :width))
           (= 20 (r :height))))))

# --- Column layout: children stack vertically ---

(check "column layout even split"
  (let [c1 (box/make-node :a :flex-grow 1)
        c2 (box/make-node :b :flex-grow 1)
        root (box/make-node :root :children @[c1 c2])]
    (flex/layout root 80 24)
    (let [r1 (c1 :rect)
          r2 (c2 :rect)]
      (and (= 1 (r1 :col))
           (= 1 (r1 :row))
           (= 80 (r1 :width))
           (= 12 (r1 :height))
           (= 1 (r2 :col))
           (= 13 (r2 :row))
           (= 80 (r2 :width))
           (= 12 (r2 :height))))))

# --- Row layout ---

(check "row layout even split"
  (let [c1 (box/make-node :a :flex-grow 1)
        c2 (box/make-node :b :flex-grow 1)
        root (box/make-node :root :flex-direction :row :children @[c1 c2])]
    (flex/layout root 80 24)
    (let [r1 (c1 :rect)
          r2 (c2 :rect)]
      (and (= 1 (r1 :col))
           (= 1 (r1 :row))
           (= 40 (r1 :width))
           (= 24 (r1 :height))
           (= 41 (r2 :col))
           (= 1 (r2 :row))
           (= 40 (r2 :width))
           (= 24 (r2 :height))))))

# --- Flex-grow distribution ---

(check "flex-grow distributes by ratio"
  (let [c1 (box/make-node :a :flex-grow 1)
        c2 (box/make-node :b :flex-grow 3)
        root (box/make-node :root :children @[c1 c2])]
    (flex/layout root 80 24)
    (let [r1 (c1 :rect)
          r2 (c2 :rect)]
      (and (= 6 (r1 :height))
           (= 18 (r2 :height))))))

# --- Flex-shrink ---

(check "flex-shrink reduces overflow"
  (let [c1 (box/make-node :a :height 20 :flex-shrink 1)
        c2 (box/make-node :b :height 20 :flex-shrink 1)
        root (box/make-node :root :children @[c1 c2])]
    (flex/layout root 80 24)
    (let [r1 (c1 :rect)
          r2 (c2 :rect)]
      # Total natural = 40, available = 24, overflow = 16
      # Each shrinks by 8 → 12 each
      (and (= 12 (r1 :height))
           (= 12 (r2 :height))))))

# --- Docking ---

(check "dock top consumes from top"
  (let [header (box/make-node :header :height 3 :dock :top)
        body (box/make-node :body :flex-grow 1)
        root (box/make-node :root :children @[header body])]
    (flex/layout root 80 24)
    (let [hr (header :rect)
          br (body :rect)]
      (and (= 1 (hr :row))
           (= 80 (hr :width))
           (= 3 (hr :height))
           (= 4 (br :row))
           (= 21 (br :height))))))

(check "dock bottom consumes from bottom"
  (let [footer (box/make-node :footer :height 2 :dock :bottom)
        body (box/make-node :body :flex-grow 1)
        root (box/make-node :root :children @[footer body])]
    (flex/layout root 80 24)
    (let [fr (footer :rect)
          br (body :rect)]
      (and (= 23 (fr :row))
           (= 2 (fr :height))
           (= 1 (br :row))
           (= 22 (br :height))))))

(check "dock left consumes from left"
  (let [sidebar (box/make-node :sidebar :width 20 :dock :left)
        body (box/make-node :body :flex-grow 1)
        root (box/make-node :root :children @[sidebar body])]
    (flex/layout root 80 24)
    (let [sr (sidebar :rect)
          br (body :rect)]
      (and (= 1 (sr :col))
           (= 20 (sr :width))
           (= 24 (sr :height))
           (= 21 (br :col))
           (= 60 (br :width))))))

(check "dock right consumes from right"
  (let [sidebar (box/make-node :sidebar :width 20 :dock :right)
        body (box/make-node :body :flex-grow 1)
        root (box/make-node :root :children @[sidebar body])]
    (flex/layout root 80 24)
    (let [sr (sidebar :rect)
          br (body :rect)]
      (and (= 61 (sr :col))
           (= 20 (sr :width))
           (= 1 (br :col))
           (= 60 (br :width))))))

# --- Nested layout ---

(check "nested layout"
  (let [gc1 (box/make-node :gc1 :flex-grow 1)
        gc2 (box/make-node :gc2 :flex-grow 1)
        child (box/make-node :child :flex-grow 1 :flex-direction :row :children @[gc1 gc2])
        root (box/make-node :root :children @[child])]
    (flex/layout root 80 24)
    (let [cr (child :rect)
          g1r (gc1 :rect)
          g2r (gc2 :rect)]
      (and (= 80 (cr :width))
           (= 24 (cr :height))
           (= 40 (g1r :width))
           (= 24 (g1r :height))
           (= 40 (g2r :width))
           (= 41 (g2r :col))))))

# --- Padding shrinks content area ---

(check "padding shrinks content for children"
  (let [child (box/make-node :child :flex-grow 1)
        root (box/make-node :root :padding 2 :children @[child])]
    (flex/layout root 80 24)
    (let [cr (child :rect)]
      (and (= 3 (cr :col))
           (= 3 (cr :row))
           (= 76 (cr :width))
           (= 20 (cr :height))))))

# --- Zero-grow children get even split ---

(check "zero-grow zero-natural children get even split"
  (let [c1 (box/make-node :a)
        c2 (box/make-node :b)
        root (box/make-node :root :children @[c1 c2])]
    (flex/layout root 80 24)
    (let [r1 (c1 :rect)
          r2 (c2 :rect)]
      (and (= 12 (r1 :height))
           (= 12 (r2 :height))))))

# --- Custom root position ---

(check "custom root-col and root-row"
  (let [n (box/make-node :root :width 40 :height 10)]
    (flex/layout n 40 10 5 3)
    (let [r (n :rect)]
      (and (= 5 (r :col))
           (= 3 (r :row))))))

(printf "  %d tests passed" pass)
