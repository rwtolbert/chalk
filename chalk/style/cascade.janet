# Layer 8: Selector matching and cascade resolution
# Matches CSS rules against widget trees, applies resolved styles.

(import ./css-parse)
(import ./properties)

(defn- segment-matches?
  "Test if a single selector segment matches a widget."
  [segment widget]
  # Check element type
  (when-let [elem (segment :element)]
    (unless (= elem (widget :type))
      (break false)))
  # Check id
  (when-let [id (segment :id)]
    (unless (= id (widget :id))
      (break false)))
  # Check classes
  (when-let [classes (segment :classes)]
    (def widget-classes (or (widget :classes) @[]))
    (unless (all (fn [cls] (find |(= $ cls) widget-classes)) classes)
      (break false)))
  true)

(defn selector-matches?
  ``Test if a full selector (array of segments) matches a widget.
   Segments use descendant combinator: each segment must match
   the widget or one of its ancestors, in order from right to left.``
  [selector widget]
  (when (empty? selector) (break false))

  # Last segment must match the widget itself
  (def last-seg (last selector))
  (unless (segment-matches? last-seg widget)
    (break false))

  # Remaining segments must match ancestors (in order, going up)
  (when (= (length selector) 1) (break true))

  (var seg-idx (- (length selector) 2))
  (var ancestor (widget :parent))
  (while (and (>= seg-idx 0) ancestor)
    (when (segment-matches? (get selector seg-idx) ancestor)
      (-- seg-idx))
    (set ancestor (ancestor :parent)))

  (< seg-idx 0))

(defn specificity
  "Calculate specificity of a selector: [ids classes elements]."
  [selector]
  (var ids 0)
  (var classes 0)
  (var elements 0)
  (each segment selector
    (when (segment :id) (++ ids))
    (when (segment :classes)
      (+= classes (length (segment :classes))))
    (when (segment :element) (++ elements)))
  [ids classes elements])

(defn- specificity-cmp
  "Compare two specificities. Returns negative if a < b, 0 if equal, positive if a > b."
  [a b]
  (def [a-ids a-classes a-elements] a)
  (def [b-ids b-classes b-elements] b)
  (if (not= a-ids b-ids) (- a-ids b-ids)
    (if (not= a-classes b-classes) (- a-classes b-classes)
      (- a-elements b-elements))))

(defn- apply-props-to-widget
  "Apply resolved style and layout props to a widget."
  [widget style-props layout-props]
  # Merge style props (CSS props, then inline overrides)
  (when (not (empty? style-props))
    (def current-style (or (widget :style) @{}))
    (def merged (merge style-props current-style))
    (put widget :style merged))

  # Apply layout props from CSS
  (each [k v] (pairs layout-props)
    (put widget k v)))

(defn resolve-styles
  ``Match all rules against each widget in the tree. Sort by specificity
   then source order, merge. Inline :style on widget overrides CSS.``
  [stylesheet root]
  (defn walk [widget]
    # Collect matching rules with specificity
    (def matches @[])
    (var rule-idx 0)
    (each rule stylesheet
      (each selector (rule :selectors)
        (when (selector-matches? selector widget)
          (array/push matches
                      @{:declarations (rule :declarations)
                        :specificity (specificity selector)
                        :order rule-idx})))
      (++ rule-idx))

    # Sort by specificity then source order
    (sort matches
          (fn [a b]
            (def cmp (specificity-cmp (a :specificity) (b :specificity)))
            (if (not= cmp 0) (< cmp 0)
              (< (a :order) (b :order)))))

    # Merge declarations in order (later overrides earlier)
    (def merged-style @{})
    (def merged-layout @{})
    (each m matches
      (def {:style-props sp :layout-props lp}
        (properties/declarations-to-props (get m :declarations)))
      (merge-into merged-style sp)
      (merge-into merged-layout lp))

    (apply-props-to-widget widget merged-style merged-layout)

    # Recurse into children
    (each child (widget :children)
      (walk child)))

  (walk root))

(defn apply-stylesheet
  "Parse CSS text and apply resolved styles to the widget tree."
  [css-text root]
  (def stylesheet (css-parse/parse-css css-text))
  (resolve-styles stylesheet root))
