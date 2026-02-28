# Layer 8: PEG CSS parser
# Parses a subset of CSS: element/class/id selectors, descendant combinator,
# comma groups, property: value; declarations.

(def css-grammar
  (peg/compile
    ~{:main (any (+ :rule :ws))

      :ws (some (set " \t\n\r"))
      :opt-ws (any (set " \t\n\r"))

      # A rule: selectors { declarations }
      :rule (group (* :opt-ws :selector-list :opt-ws "{" :opt-ws :declarations :opt-ws "}"))

      # Comma-separated selectors
      :selector-list (* (group (* (constant :selectors) :selector
                                  (any (* :opt-ws "," :opt-ws :selector)))))

      # A selector: space-separated segments (descendant combinator)
      :selector (group (some (* :segment :opt-ws)))

      # A single segment: element, .class, or #id (can combine: div.foo#bar)
      :segment (group (some (+ :id-sel :class-sel :element-sel)))

      :element-sel (* (constant :element) (capture :ident))
      :class-sel (* (constant :class) "." (capture :ident))
      :id-sel (* (constant :id) "#" (capture :ident))

      :ident (some (+ :w "-"))

      # Declarations
      :declarations (group (* (constant :declarations)
                              (any (* :opt-ws :declaration :opt-ws))))

      # Single declaration: property: value;
      :declaration (group (* (capture :prop-name) :opt-ws ":" :opt-ws
                             (capture :prop-value) :opt-ws ";"))

      :prop-name (some (+ (range "az") "-"))
      :prop-value (some (if-not (set ";{}") 1))}))

(defn- parse-selector-list [raw]
  # raw is [:selectors seg1 seg2 ...]
  (def result @[])
  (for i 1 (length raw)
    (array/push result (get raw i)))
  result)

(defn- parse-declarations [raw]
  # raw is [:declarations [prop val] [prop val] ...]
  (def result @[])
  (for i 1 (length raw)
    (def pair (get raw i))
    (array/push result {:property (string/trim (get pair 0))
                        :value (string/trim (get pair 1))}))
  result)

(defn- parse-segment [raw]
  # raw is [:element "name" :class "cls" :id "id" ...]
  (def result @{})
  (var i 0)
  (while (< i (length raw))
    (def kind (get raw i))
    (def val (get raw (+ i 1)))
    (case kind
      :element (put result :element val)
      :class (do
               (unless (result :classes) (put result :classes @[]))
               (array/push (result :classes) val))
      :id (put result :id val))
    (+= i 2))
  result)

(defn- parse-selector [raw]
  # raw is [segment1 segment2 ...]  - segments are descendant-combined
  (map parse-segment raw))

(defn parse-css
  ```Parse a CSS string into an array of rules.
   Each rule: {:selectors [...] :declarations [...]}```
  [css-text]
  (def matches (peg/match css-grammar css-text))
  (unless matches (break @[]))

  (def rules @[])
  (each rule-group matches
    # rule-group is [selector-list-raw declarations-raw]
    (def sel-raw (get rule-group 0))
    (def decl-raw (get rule-group 1))
    (def selectors (map parse-selector (parse-selector-list sel-raw)))
    (def declarations (parse-declarations decl-raw))
    (array/push rules {:selectors selectors :declarations declarations}))
  rules)
