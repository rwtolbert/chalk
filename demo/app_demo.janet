# Layer 10 Demo: Full todo-list app with CSS, borders, list, input
# ctrl-c to quit, tab to switch focus, enter to add/toggle, d to delete

(import ../src/platform/init :as platform)
(import ../src/terminal/output :as output)
(import ../src/terminal/screen :as screen)
(import ../src/terminal/style :as style)
(import ../src/events/loop :as loop)
(import ../src/widget/proto)
(import ../src/widget/text)
(import ../src/widget/container)
(import ../src/widget/border)
(import ../src/widget/list)
(import ../src/widget/input)
(import ../src/widget/render)
(import ../src/style/cascade)

(def app-css `
  #header {
    background: blue;
    color: white;
    bold: true;
    dock: top;
    height: 1;
  }

  #footer {
    background: bright-black;
    color: white;
    dock: bottom;
    height: 1;
  }

  #input-area {
    dock: top;
    height: 3;
  }

  #todo-list {
    flex-grow: 1;
  }

  #help {
    dock: right;
    width: 28;
    padding: 1;
  }
`)

(defn- format-todo [todo]
  (string (if (todo :done) "[x] " "[ ] ") (todo :text)))

(defn main [&]
  (def [cols rows] (platform/get-terminal-size))
  (var current-cols cols)
  (var current-rows rows)
  (var quit false)

  # App state
  (var todos @[@{:text "Learn Janet" :done true}
               @{:text "Build a TUI framework" :done true}
               @{:text "Write demo apps" :done false}
               @{:text "Take over the world" :done false}])
  (var input-value "")
  (var focus :list) # :list or :input

  (defn build-ui []
    (def todo-strings (map format-todo todos))

    (def input-w (input/input-widget
                   :id "input-field"
                   :value input-value
                   :placeholder "Type a new todo and press enter..."
                   :style {:fg :white}
                   :flex-grow 1
                   :height 1))

    (def todo-list (list/list-widget
                     :id "todo-list-inner"
                     :items (map format-todo todos)
                     :style {:fg :white}
                     :flex-grow 1))

    (def root
      (container/container
        :id "app"
        :flex-direction :column
        :children
        @[# Header
          (container/container
            :id "header"
            :children
            @[(text/text " Chalk Todo App " :flex-grow 1)])

          # Footer
          (container/container
            :id "footer"
            :children
            @[(text/text (string/format " %d todos, %d done | tab: switch focus | ctrl-c: quit "
                                        (length todos)
                                        (length (filter |($ :done) todos)))
                         :flex-grow 1)])

          # Main area
          (container/container
            :id "main"
            :flex-direction :row
            :flex-grow 1
            :children
            @[# Left side: input + list
              (container/container
                :id "left"
                :flex-direction :column
                :flex-grow 1
                :children
                @[# Input area with border
                  (border/border
                    (container/container
                      :children @[input-w])
                    :id "input-area"
                    :title (if (= focus :input) " New Todo (active) " " New Todo ")
                    :style (if (= focus :input) {:fg :cyan} {:fg :white}))

                  # Todo list with border
                  (border/border
                    todo-list
                    :id "todo-list"
                    :title (if (= focus :list) " Todos (active) " " Todos ")
                    :style (if (= focus :list) {:fg :cyan} {:fg :white}))])

              # Help panel
              (container/container
                :id "help"
                :children
                @[(text/text "Keyboard" :style {:fg :cyan :bold true})
                  (text/text "")
                  (text/text "tab    switch focus")
                  (text/text "")
                  (text/text "In todo list:")
                  (text/text " up/k   move up")
                  (text/text " down/j move down")
                  (text/text " space  toggle done")
                  (text/text " d      delete todo")
                  (text/text "")
                  (text/text "In input:")
                  (text/text " type   add text")
                  (text/text " enter  add todo")
                  (text/text "")
                  (text/text "ctrl-c  quit"
                             :style {:fg :bright-black})])])]))

    (cascade/apply-stylesheet app-css root)
    [root input-w todo-list])

  (platform/enter-raw-mode)
  (defer (do
           (loop/stop)
           (output/disable-mouse)
           (output/reset-style)
           (output/exit-alt-screen)
           (output/show-cursor)
           (output/flush)
           (platform/exit-raw-mode))

    (output/enter-alt-screen)
    (output/hide-cursor)
    (output/flush)

    (var scr (screen/make-screen current-cols current-rows))
    (screen/screen-force-redraw scr)

    (loop/start)

    (var ui-parts (build-ui))
    (var root (get ui-parts 0))
    (var input-w (get ui-parts 1))
    (var todo-list (get ui-parts 2))
    (proto/mount-tree root)
    (render/render-tree scr root current-cols current-rows)

    (while (not quit)
      (def events (loop/read-events))
      (var needs-redraw false)

      (each event events
        (case (event :type)
          :key
          (let [k (event :key)]
            (cond
              (= k :ctrl-c)
              (set quit true)

              (= k :tab)
              (do
                (set focus (if (= focus :list) :input :list))
                (set needs-redraw true))

              (= focus :input)
              (do
                # Forward to input widget
                (def result ((input-w :handle-event) input-w event))
                (set input-value (get-in input-w [:state :value]))
                # Check for enter (submit)
                (when (= k :enter)
                  (when (> (length input-value) 0)
                    (array/push todos @{:text input-value :done false})
                    (set input-value "")
                    (set needs-redraw true)))
                (when result (set needs-redraw true)))

              (= focus :list)
              (do
                (cond
                  # Toggle done
                  (= k " ")
                  (do
                    (def sel (get-in todo-list [:state :selected]))
                    (when (and sel (< sel (length todos)))
                      (def todo (get todos sel))
                      (put todo :done (not (todo :done)))
                      (set needs-redraw true)))

                  # Delete
                  (= k "d")
                  (do
                    (def sel (get-in todo-list [:state :selected]))
                    (when (and sel (< sel (length todos)))
                      (array/remove todos sel)
                      (set needs-redraw true)))

                  # Forward navigation keys to list
                  (do
                    (def result ((todo-list :handle-event) todo-list event))
                    (when result (set needs-redraw true)))))))

          :resize
          (do
            (set current-cols (event :cols))
            (set current-rows (event :rows))
            (set scr (screen/make-screen current-cols current-rows))
            (screen/screen-force-redraw scr)
            (set needs-redraw true))))

      (when (and needs-redraw (not quit))
        # Rebuild UI to reflect state changes
        (def old-sel (get-in todo-list [:state :selected] 0))
        (def new-ui (build-ui))
        (set root (get new-ui 0))
        (set input-w (get new-ui 1))
        (set todo-list (get new-ui 2))
        # Restore list selection
        (put (todo-list :state) :selected (min old-sel (max 0 (- (length todos) 1))))
        (proto/mount-tree root)
        (render/render-tree scr root current-cols current-rows)))))

(main)
(os/exit 0)
