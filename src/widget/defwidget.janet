# Layer 9: defwidget macro
# Defines a widget constructor from declarative body forms.
# Body forms: (state {...}), (render [self] ...), (on :type [self msg] ...),
# (paint [self screen rect] ...), (mount [self] ...), (unmount [self] ...)

(import ./proto)

(defn get-state
  "Get a value from widget state."
  [widget key]
  (get (widget :state) key))

(defn set-state
  "Set a value in widget state and return the widget."
  [widget key val]
  (put (widget :state) key val)
  widget)

(defmacro defwidget
  "Define a widget constructor. Body forms:
   (state {:key default ...})
   (render [self] ...) — return child widgets
   (on :event-type [self event] ...) — event handler
   (paint [self screen rect] ...) — custom paint
   (mount [self] ...) — mount lifecycle
   (unmount [self] ...) — unmount lifecycle"
  [name & body]

  # Parse body forms
  (var state-init nil)
  (var render-form nil)
  (var paint-form nil)
  (var mount-form nil)
  (var unmount-form nil)
  (def on-forms @{})

  (each form body
    (def tag (get form 0))
    (case tag
      'state (set state-init (get form 1))
      'render (set render-form form)
      'paint (set paint-form form)
      'mount (set mount-form form)
      'unmount (set unmount-form form)
      'on (do
            (def event-type (get form 1))
            (put on-forms event-type form))))

  # Build the handler function body
  # Key/mouse events go to handle-event, other "on" types go to update
  (def event-types [:key :mouse :resize])
  (def event-handlers @[])
  (def update-handlers @[])

  (eachp [evt-type form] on-forms
    (if (find |(= $ evt-type) event-types)
      (array/push event-handlers [evt-type form])
      (array/push update-handlers [evt-type form])))

  # Build handle-event function
  (def handle-event-code
    (if (empty? event-handlers)
      nil
      ~(fn [self event]
         (case (event :type)
           ,;(mapcat
               (fn [[evt-type form]]
                 (def params (get form 2))
                 (def body-code (tuple/slice form 3))
                 [evt-type ~(let [,(get params 0) self
                                  ,(get params 1) event]
                              ,;body-code)])
               event-handlers)))))

  # Build update function
  (def update-code
    (if (empty? update-handlers)
      nil
      ~(fn [self msg]
         (case (get msg :type)
           ,;(mapcat
               (fn [[evt-type form]]
                 (def params (get form 2))
                 (def body-code (tuple/slice form 3))
                 [evt-type ~(let [,(get params 0) self
                                  ,(get params 1) msg]
                              ,;body-code)])
               update-handlers)))))

  # Build paint function
  (def paint-code
    (when paint-form
      (def params (get paint-form 1))
      (def body-code (tuple/slice paint-form 2))
      ~(fn [,(get params 0) ,(get params 1) ,(get params 2)]
         ,;body-code)))

  # Build mount function
  (def mount-code
    (when mount-form
      (def params (get mount-form 1))
      (def body-code (tuple/slice mount-form 2))
      ~(fn [,(get params 0)]
         ,;body-code)))

  # Build unmount function
  (def unmount-code
    (when unmount-form
      (def params (get unmount-form 1))
      (def body-code (tuple/slice unmount-form 2))
      ~(fn [,(get params 0)]
         ,;body-code)))

  # Build render function
  (def render-code
    (when render-form
      (def params (get render-form 1))
      (def body-code (tuple/slice render-form 2))
      ~(fn [,(get params 0)]
         ,;body-code)))

  # Generate constructor
  ~(defn ,name [&named id classes style width height flex-grow flex-shrink
                margin padding dock flex-direction]
     (def w (,proto/make-widget
              ,(string name)
              :id id
              :classes classes
              :style style
              :width width
              :height height
              :flex-grow flex-grow
              :flex-shrink flex-shrink
              :margin margin
              :padding padding
              :dock dock
              :flex-direction flex-direction
              :handle-event ,handle-event-code
              :update ,update-code
              :paint ,paint-code
              :mount ,mount-code
              :unmount ,unmount-code
              :render ,render-code))

     # Initialize state
     ,(when state-init
        ~(each [k v] (pairs ,state-init)
           (put (w :state) k v)))

     # Run render to build children
     ,(when render-form
        ~(when (w :render)
           (def children ((w :render) w))
           (when (indexed? children)
             (each child children
               (when child
                 (,proto/widget-add-child w child))))))

     w))
