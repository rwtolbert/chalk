# Tests for chalk/layout/box.janet

(import ../chalk/layout/box)

(var pass 0)
(defn check [name & assertions]
  (each a assertions (assert a name))
  (++ pass))

# --- make-node defaults ---

(check "make-node defaults"
  (let [n (box/make-node :test)]
    (and (= :test (n :tag))
         (= :auto (n :width))
         (= :auto (n :height))
         (= 0 (n :min-width))
         (= math/inf (n :max-width))
         (= 0 (n :min-height))
         (= math/inf (n :max-height))
         (= 0 (n :margin-top))
         (= 0 (n :margin-right))
         (= 0 (n :margin-bottom))
         (= 0 (n :margin-left))
         (= 0 (n :padding-top))
         (= 0 (n :padding-right))
         (= 0 (n :padding-bottom))
         (= 0 (n :padding-left))
         (= :column (n :flex-direction))
         (= 0 (n :flex-grow))
         (= 1 (n :flex-shrink))
         (nil? (n :dock))
         (deep= @[] (n :children))
         (nil? (n :rect)))))

# --- make-node explicit values ---

(check "make-node explicit values"
  (let [n (box/make-node :box :width 100 :height 50 :min-width 10 :max-width 200
                         :flex-direction :row :flex-grow 2 :flex-shrink 0 :dock :top)]
    (and (= 100 (n :width))
         (= 50 (n :height))
         (= 10 (n :min-width))
         (= 200 (n :max-width))
         (= :row (n :flex-direction))
         (= 2 (n :flex-grow))
         (= 0 (n :flex-shrink))
         (= :top (n :dock)))))

# --- margin shorthand: single int ---

(check "margin single int expands to all sides"
  (let [n (box/make-node :box :margin 5)]
    (and (= 5 (n :margin-top))
         (= 5 (n :margin-right))
         (= 5 (n :margin-bottom))
         (= 5 (n :margin-left)))))

# --- margin shorthand: [v h] ---

(check "margin [v h] expands correctly"
  (let [n (box/make-node :box :margin [3 7])]
    (and (= 3 (n :margin-top))
         (= 7 (n :margin-right))
         (= 3 (n :margin-bottom))
         (= 7 (n :margin-left)))))

# --- padding shorthand: single int ---

(check "padding single int expands to all sides"
  (let [n (box/make-node :box :padding 4)]
    (and (= 4 (n :padding-top))
         (= 4 (n :padding-right))
         (= 4 (n :padding-bottom))
         (= 4 (n :padding-left)))))

# --- padding shorthand: [v h] ---

(check "padding [v h] expands correctly"
  (let [n (box/make-node :box :padding [2 6])]
    (and (= 2 (n :padding-top))
         (= 6 (n :padding-right))
         (= 2 (n :padding-bottom))
         (= 6 (n :padding-left)))))

# --- explicit side overrides margin shorthand ---

(check "explicit margin-top overrides shorthand"
  (let [n (box/make-node :box :margin-top 10)]
    (and (= 10 (n :margin-top))
         (= 0 (n :margin-right)))))

# --- clamp-size ---

(check "clamp-size within range"
  (= 50 (box/clamp-size 50 0 100)))

(check "clamp-size below min"
  (= 10 (box/clamp-size 5 10 100)))

(check "clamp-size above max"
  (= 100 (box/clamp-size 150 0 100)))

(check "clamp-size at boundary"
  (and (= 10 (box/clamp-size 10 10 100))
       (= 100 (box/clamp-size 100 10 100))))

# --- outer-width ---

(check "outer-width adds margin and padding"
  (let [n (box/make-node :box :margin [0 5] :padding [0 3])]
    (= (+ 100 5 5 3 3) (box/outer-width n 100))))

(check "outer-width no margin/padding"
  (let [n (box/make-node :box)]
    (= 80 (box/outer-width n 80))))

# --- outer-height ---

(check "outer-height adds margin and padding"
  (let [n (box/make-node :box :margin [2 0] :padding [1 0])]
    (= (+ 40 2 2 1 1) (box/outer-height n 40))))

(check "outer-height no margin/padding"
  (let [n (box/make-node :box)]
    (= 24 (box/outer-height n 24))))

# --- content-rect ---

(check "content-rect subtracts padding"
  (let [n (box/make-node :box :padding 2)]
    (put n :rect @{:col 1 :row 1 :width 80 :height 24})
    (let [cr (box/content-rect n)]
      (and (= 3 (cr :col))
           (= 3 (cr :row))
           (= 76 (cr :width))
           (= 20 (cr :height))))))

(check "content-rect no padding"
  (let [n (box/make-node :box)]
    (put n :rect @{:col 5 :row 10 :width 40 :height 20})
    (let [cr (box/content-rect n)]
      (and (= 5 (cr :col))
           (= 10 (cr :row))
           (= 40 (cr :width))
           (= 20 (cr :height))))))

(check "content-rect nil when no rect"
  (let [n (box/make-node :box)]
    (nil? (box/content-rect n))))

# --- children ---

(check "make-node with children"
  (let [c1 (box/make-node :child1)
        c2 (box/make-node :child2)
        p (box/make-node :parent :children @[c1 c2])]
    (and (= 2 (length (p :children)))
         (= :child1 ((get (p :children) 0) :tag))
         (= :child2 ((get (p :children) 1) :tag)))))

(printf "  %d tests passed" pass)
