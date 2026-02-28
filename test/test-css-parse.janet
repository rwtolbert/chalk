# Tests for chalk/style/css-parse.janet

(import ../chalk/style/css-parse)

(var pass 0)
(defn check [name & assertions]
  (each a assertions (assert a name))
  (++ pass))

# --- Single rule with element selector ---

(check "single rule with element selector"
  (let [rules (css-parse/parse-css "div { color: red; }")]
    (and (= 1 (length rules))
         (let [rule (get rules 0)
               sels (rule :selectors)
               decls (rule :declarations)]
           (and (= 1 (length sels))
                (= 1 (length (get sels 0)))
                (= "div" (get-in sels [0 0 :element]))
                (= 1 (length decls))
                (= "color" ((get decls 0) :property))
                (= "red" ((get decls 0) :value)))))))

# --- ID selector ---

(check "id selector"
  (let [rules (css-parse/parse-css "#foo { bold: true; }")]
    (= "foo" (get-in rules [0 :selectors 0 0 :id]))))

# --- Class selector ---

(check "class selector"
  (let [rules (css-parse/parse-css ".bar { color: blue; }")]
    (deep= @["bar"] (get-in rules [0 :selectors 0 0 :classes]))))

# --- Combined element.class#id ---

(check "combined selector"
  (let [rules (css-parse/parse-css "div.foo#bar { color: red; }")]
    (let [seg (get-in rules [0 :selectors 0 0])]
      (and (= "div" (seg :element))
           (= "bar" (seg :id))
           (deep= @["foo"] (seg :classes))))))

# --- Descendant combinator ---

(check "descendant combinator"
  (let [rules (css-parse/parse-css "body div { color: red; }")]
    (let [sel (get-in rules [0 :selectors 0])]
      (and (= 2 (length sel))
           (= "body" ((get sel 0) :element))
           (= "div" ((get sel 1) :element))))))

# --- Comma groups ---

(check "comma groups produce multiple selectors"
  (let [rules (css-parse/parse-css "h1, h2 { bold: true; }")]
    (let [sels (get-in rules [0 :selectors])]
      (and (= 2 (length sels))
           (= "h1" (get-in sels [0 0 :element]))
           (= "h2" (get-in sels [1 0 :element]))))))

# --- Multiple declarations ---

(check "multiple declarations"
  (let [rules (css-parse/parse-css "div { color: red; bold: true; background: blue; }")]
    (let [decls (get-in rules [0 :declarations])]
      (and (= 3 (length decls))
           (= "color" ((get decls 0) :property))
           (= "red" ((get decls 0) :value))
           (= "bold" ((get decls 1) :property))
           (= "true" ((get decls 1) :value))
           (= "background" ((get decls 2) :property))
           (= "blue" ((get decls 2) :value))))))

# --- Empty CSS ---

(check "empty css returns empty array"
  (deep= @[] (css-parse/parse-css "")))

(check "whitespace-only css returns empty array"
  (deep= @[] (css-parse/parse-css "   \n  \t  ")))

# --- Whitespace handling ---

(check "extra whitespace around declarations"
  (let [rules (css-parse/parse-css "div  {  color :  red ;  }")]
    (= 1 (length (get-in rules [0 :declarations])))))

(check "newlines in css"
  (let [rules (css-parse/parse-css "div {\n  color: red;\n  bold: true;\n}")]
    (= 2 (length (get-in rules [0 :declarations])))))

# --- Multiple rules ---

(check "multiple rules"
  (let [rules (css-parse/parse-css "div { color: red; } .foo { bold: true; }")]
    (and (= 2 (length rules))
         (= "div" (get-in rules [0 :selectors 0 0 :element]))
         (deep= @["foo"] (get-in rules [1 :selectors 0 0 :classes])))))

# --- Multiple classes ---

(check "multiple classes on one selector"
  (let [rules (css-parse/parse-css ".a.b { color: red; }")]
    (let [classes (get-in rules [0 :selectors 0 0 :classes])]
      (and (= 2 (length classes))
           (= "a" (get classes 0))
           (= "b" (get classes 1))))))

(printf "  %d tests passed" pass)
