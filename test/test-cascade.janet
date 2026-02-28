# Tests for chalk/style/cascade.janet

(import ../chalk/style/cascade)
(import ../chalk/widget/proto)

(var pass 0)
(defn check [name & assertions]
  (each a assertions (assert a name))
  (++ pass))

# Helper: build a simple widget for matching
(defn make-test-widget [type &named id classes parent]
  (def w (proto/make-widget type :id id :classes classes))
  (when parent
    (proto/widget-add-child parent w))
  w)

# --- segment-matches? (tested via selector-matches? with single-segment selectors) ---

(check "selector matches element type"
  (let [w (make-test-widget "div")
        sel @[@{:element "div"}]]
    (cascade/selector-matches? sel w)))

(check "selector does not match wrong element"
  (let [w (make-test-widget "span")
        sel @[@{:element "div"}]]
    (not (cascade/selector-matches? sel w))))

(check "selector matches id"
  (let [w (make-test-widget "div" :id "foo")
        sel @[@{:id "foo"}]]
    (cascade/selector-matches? sel w)))

(check "selector does not match wrong id"
  (let [w (make-test-widget "div" :id "foo")
        sel @[@{:id "bar"}]]
    (not (cascade/selector-matches? sel w))))

(check "selector matches class"
  (let [w (make-test-widget "div" :classes @["active"])
        sel @[@{:classes @["active"]}]]
    (cascade/selector-matches? sel w)))

(check "selector does not match missing class"
  (let [w (make-test-widget "div" :classes @["active"])
        sel @[@{:classes @["hidden"]}]]
    (not (cascade/selector-matches? sel w))))

(check "selector matches combined element+class+id"
  (let [w (make-test-widget "div" :id "main" :classes @["active"])
        sel @[@{:element "div" :id "main" :classes @["active"]}]]
    (cascade/selector-matches? sel w)))

(check "selector fails combined when class missing"
  (let [w (make-test-widget "div" :id "main")
        sel @[@{:element "div" :id "main" :classes @["active"]}]]
    (not (cascade/selector-matches? sel w))))

# --- Descendant combinator ---

(check "descendant combinator matches parent chain"
  (let [root (make-test-widget "body")
        child (make-test-widget "div" :parent root)]
    (cascade/selector-matches? @[@{:element "body"} @{:element "div"}] child)))

(check "descendant combinator matches grandparent"
  (let [root (make-test-widget "body")
        mid (make-test-widget "main" :parent root)
        child (make-test-widget "div" :parent mid)]
    (cascade/selector-matches? @[@{:element "body"} @{:element "div"}] child)))

(check "descendant combinator fails without matching ancestor"
  (let [root (make-test-widget "header")
        child (make-test-widget "div" :parent root)]
    (not (cascade/selector-matches? @[@{:element "body"} @{:element "div"}] child))))

(check "empty selector does not match"
  (let [w (make-test-widget "div")]
    (not (cascade/selector-matches? @[] w))))

# --- specificity ---

(check "specificity element only"
  (deep= [0 0 1] (cascade/specificity @[@{:element "div"}])))

(check "specificity id only"
  (deep= [1 0 0] (cascade/specificity @[@{:id "foo"}])))

(check "specificity class only"
  (deep= [0 1 0] (cascade/specificity @[@{:classes @["active"]}])))

(check "specificity combined"
  (deep= [1 1 1]
    (cascade/specificity @[@{:element "div" :id "main" :classes @["active"]}])))

(check "specificity multiple segments"
  (deep= [0 0 2]
    (cascade/specificity @[@{:element "body"} @{:element "div"}])))

(check "specificity multiple classes"
  (deep= [0 2 0]
    (cascade/specificity @[@{:classes @["a" "b"]}])))

# --- resolve-styles ---

(check "resolve-styles applies CSS rule to matching widget"
  (let [root (make-test-widget "div")
        stylesheet @[{:selectors @[@[@{:element "div"}]]
                      :declarations @[{:property "color" :value "red"}]}]]
    (cascade/resolve-styles stylesheet root)
    (= :red (get-in root [:style :fg]))))

(check "resolve-styles higher specificity wins"
  (let [root (make-test-widget "div" :id "main")
        stylesheet @[{:selectors @[@[@{:element "div"}]]
                      :declarations @[{:property "color" :value "red"}]}
                     {:selectors @[@[@{:id "main"}]]
                      :declarations @[{:property "color" :value "blue"}]}]]
    (cascade/resolve-styles stylesheet root)
    (= :blue (get-in root [:style :fg]))))

(check "resolve-styles later rule overrides same specificity"
  (let [root (make-test-widget "div")
        stylesheet @[{:selectors @[@[@{:element "div"}]]
                      :declarations @[{:property "color" :value "red"}]}
                     {:selectors @[@[@{:element "div"}]]
                      :declarations @[{:property "color" :value "blue"}]}]]
    (cascade/resolve-styles stylesheet root)
    (= :blue (get-in root [:style :fg]))))

(check "resolve-styles inline style overrides CSS"
  (let [root (make-test-widget "div")]
    (put root :style @{:fg :green})
    (def stylesheet @[{:selectors @[@[@{:element "div"}]]
                       :declarations @[{:property "color" :value "red"}]}])
    (cascade/resolve-styles stylesheet root)
    (= :green (get-in root [:style :fg]))))

(check "resolve-styles applies to children"
  (let [root (make-test-widget "body")
        child (make-test-widget "div" :parent root)
        stylesheet @[{:selectors @[@[@{:element "div"}]]
                      :declarations @[{:property "bold" :value "true"}]}]]
    (cascade/resolve-styles stylesheet root)
    (= true (get-in child [:style :bold]))))

# --- apply-stylesheet end-to-end ---

(check "apply-stylesheet parses and applies"
  (let [root (make-test-widget "div")]
    (cascade/apply-stylesheet "div { color: red; bold: true; }" root)
    (and (= :red (get-in root [:style :fg]))
         (= true (get-in root [:style :bold])))))

(check "apply-stylesheet with descendant selector"
  (let [root (make-test-widget "body")
        child (make-test-widget "div" :parent root)]
    (cascade/apply-stylesheet "body div { color: blue; }" root)
    (= :blue (get-in child [:style :fg]))))

(check "apply-stylesheet layout props applied"
  (let [root (make-test-widget "div")]
    (cascade/apply-stylesheet "div { width: 80; margin: 2; }" root)
    (and (= 80 (root :width))
         (= 2 (root :margin)))))

(printf "  %d tests passed" pass)
