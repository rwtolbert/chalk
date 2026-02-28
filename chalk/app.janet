# Layer 10: App framework  - defapp macro + run function
# defapp is defwidget plus :css-text. run handles full lifecycle.

(import ./platform/init :as platform)
(import ./terminal/output :as output)
(import ./terminal/screen :as screen)
(import ./terminal/style :as style)
(import ./events/loop :as loop)
(import ./widget/proto)
(import ./widget/render)
(import ./style/cascade)

(defn run
  ```Run a chalk app. app-constructor is a function returning a root widget.
   The widget may have a :css-text key for CSS styling.
   Handles: raw mode, alt screen, mount, CSS, event loop, cleanup.```
  [app-constructor]
  (def [cols rows] (platform/get-terminal-size))
  (var current-cols cols)
  (var current-rows rows)
  (var quit false)

  (def root (app-constructor))
  (def css-text (root :css-text))

  (platform/enter-raw-mode)
  (defer (do
           (proto/unmount-tree root)
           (loop/stop)
           (output/disable-mouse)
           (output/reset-style)
           (output/exit-alt-screen)
           (output/show-cursor)
           (output/flush)
           (platform/exit-raw-mode))

    (output/enter-alt-screen)
    (output/enable-mouse)
    (output/hide-cursor)
    (output/flush)

    (var scr (screen/make-screen current-cols current-rows))
    (screen/screen-force-redraw scr)

    # Apply CSS if present
    (when css-text
      (cascade/apply-stylesheet css-text root))

    # Mount
    (proto/mount-tree root)

    # Start event loop
    (loop/start)

    # Initial render
    (render/render-tree scr root current-cols current-rows)

    # Main loop
    (while (not quit)
      (def events (loop/read-events))
      (var needs-redraw false)

      (each event events
        (case (event :type)
          :key
          (let [k (event :key)]
            (if (= k :ctrl-c)
              (set quit true)
              (do
                (def result (proto/dispatch-event root event))
                (when result (set needs-redraw true)))))

          :mouse
          (do
            (proto/dispatch-event root event)
            (set needs-redraw true))

          :resize
          (do
            (set current-cols (event :cols))
            (set current-rows (event :rows))
            (set scr (screen/make-screen current-cols current-rows))
            (screen/screen-force-redraw scr)
            (when css-text
              (cascade/apply-stylesheet css-text root))
            (set needs-redraw true))))

      (when (and needs-redraw (not quit))
        (render/render-tree scr root current-cols current-rows)))))

(defmacro defapp
  "Define an app constructor. Like defwidget but also supports (css \"...\").
   Body forms: (state {...}), (css \"...\"), (render [self] ...), (on ...), etc."
  [name & body]

  (var css-form nil)
  (def widget-body @[])

  (each form body
    (if (and (tuple? form) (= (get form 0) 'css))
      (set css-form (get form 1))
      (array/push widget-body form)))

  # We generate a constructor that builds the widget, then attaches css-text
  (var state-init nil)
  (var render-form nil)
  (var paint-form nil)
  (var mount-form nil)
  (var unmount-form nil)
  (def on-forms @{})

  (each form widget-body
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

  (def event-types [:key :mouse :resize])
  (def event-handlers @[])
  (def update-handlers @[])

  (eachp [evt-type form] on-forms
    (if (find |(= $ evt-type) event-types)
      (array/push event-handlers [evt-type form])
      (array/push update-handlers [evt-type form])))

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

  (def paint-code
    (when paint-form
      (def params (get paint-form 1))
      (def body-code (tuple/slice paint-form 2))
      ~(fn [,(get params 0) ,(get params 1) ,(get params 2)]
         ,;body-code)))

  (def mount-code
    (when mount-form
      (def params (get mount-form 1))
      (def body-code (tuple/slice mount-form 2))
      ~(fn [,(get params 0)]
         ,;body-code)))

  (def unmount-code
    (when unmount-form
      (def params (get unmount-form 1))
      (def body-code (tuple/slice unmount-form 2))
      ~(fn [,(get params 0)]
         ,;body-code)))

  (def render-code
    (when render-form
      (def params (get render-form 1))
      (def body-code (tuple/slice render-form 2))
      ~(fn [,(get params 0)]
         ,;body-code)))

  ~(defn ,name []
     (def w (,proto/make-widget
              ,(string name)
              :handle-event ,handle-event-code
              :update ,update-code
              :paint ,paint-code
              :mount ,mount-code
              :unmount ,unmount-code
              :render ,render-code))

     ,(when state-init
        ~(each [k v] (pairs ,state-init)
           (put (w :state) k v)))

     ,(when css-form
        ~(put w :css-text ,css-form))

     ,(when render-form
        ~(when (w :render)
           (def children ((w :render) w))
           (when (indexed? children)
             (each child children
               (when child
                 (,proto/widget-add-child w child))))))

     w))
