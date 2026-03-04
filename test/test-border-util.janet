# Tests for chalk/widget/border-util.janet and property-based borders

(import ../chalk/widget/border-util)
(import ../chalk/widget/proto)

(var pass 0)
(defn check [name & assertions]
  (each a assertions (assert a name))
  (++ pass))

# --- border-chars table ---

(check "border-chars has all five styles"
       (not (nil? (border-util/border-chars :single)))
       (not (nil? (border-util/border-chars :double)))
       (not (nil? (border-util/border-chars :rounded)))
       (not (nil? (border-util/border-chars :heavy)))
       (not (nil? (border-util/border-chars :ascii))))

(check "each border style has required keys"
       (do
         (each style [:single :double :rounded :heavy :ascii]
           (def chars (border-util/border-chars style))
           (assert (chars :tl) (string style " missing :tl"))
           (assert (chars :tr) (string style " missing :tr"))
           (assert (chars :bl) (string style " missing :bl"))
           (assert (chars :br) (string style " missing :br"))
           (assert (chars :h) (string style " missing :h"))
           (assert (chars :v) (string style " missing :v")))
         true))

(check "ascii border chars are correct"
       (def chars (border-util/border-chars :ascii))
       (and (= "+" (chars :tl))
            (= "+" (chars :tr))
            (= "+" (chars :bl))
            (= "+" (chars :br))
            (= "-" (chars :h))
            (= "|" (chars :v))))

# --- build-layout-tree adds border padding ---

(check "build-layout-tree adds border padding when border-style set"
       (let [w (proto/make-widget "test" :border-style :single :padding 1)
             node (proto/build-layout-tree w)]
         # padding 1 expanded to all sides = 1, plus border adds 1 = 2 each side
         (and (= 2 (node :padding-top))
              (= 2 (node :padding-right))
              (= 2 (node :padding-bottom))
              (= 2 (node :padding-left)))))

(check "build-layout-tree does not add border padding when no border-style"
       (let [w (proto/make-widget "test" :padding 1)
             node (proto/build-layout-tree w)]
         (and (= 1 (node :padding-top))
              (= 1 (node :padding-right))
              (= 1 (node :padding-bottom))
              (= 1 (node :padding-left)))))

(check "build-layout-tree border padding with zero padding"
       (let [w (proto/make-widget "test" :border-style :rounded)
             node (proto/build-layout-tree w)]
         (and (= 1 (node :padding-top))
              (= 1 (node :padding-right))
              (= 1 (node :padding-bottom))
              (= 1 (node :padding-left)))))

# --- Widget border properties ---

(check "make-widget stores border properties"
       (let [w (proto/make-widget "test"
                                  :border-style :double
                                  :border-color :cyan
                                  :border-title "Title"
                                  :border-title-align :center)]
         (and (= :double (w :border-style))
              (= :cyan (w :border-color))
              (= "Title" (w :border-title))
              (= :center (w :border-title-align)))))

(check "make-widget border properties default to nil"
       (let [w (proto/make-widget "test")]
         (and (nil? (w :border-style))
              (nil? (w :border-color))
              (nil? (w :border-title))
              (nil? (w :border-title-align)))))

(printf "  %d tests passed" pass)
