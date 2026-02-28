# Layer 8 Demo: Same layout as widgets_test but styled via CSS
# Press q or ctrl-c to quit.

(import ../src/platform/init :as platform)
(import ../src/terminal/output :as output)
(import ../src/terminal/screen :as screen)
(import ../src/events/loop :as loop)
(import ../src/widget/proto)
(import ../src/widget/text)
(import ../src/widget/container)
(import ../src/widget/render)
(import ../src/style/cascade)

(def app-css `
  #title-bar {
    background: blue;
    color: white;
    bold: true;
    dock: top;
    height: 1;
  }

  #footer {
    background: magenta;
    color: bright-white;
    dock: bottom;
    height: 1;
  }

  #sidebar {
    background: green;
    color: black;
    width: 24;
    padding: 1;
  }

  #content {
    background: bright-black;
    color: white;
    flex-grow: 1;
    padding: 1;
  }

  .heading {
    color: cyan;
    bold: true;
  }

  .dim {
    color: bright-black;
  }

  .nav-active {
    bold: true;
  }
`)

(defn build-ui [last-key]
  (container/container
    :id "root"
    :flex-direction :column
    :children
    @[(container/container
        :id "title-bar"
        :children
        @[(text/text " Chalk CSS Demo ")])

      (container/container
        :id "footer"
        :children
        @[(text/text " q: quit | Styled via CSS ")])

      (container/container
        :id "middle"
        :flex-direction :row
        :flex-grow 1
        :children
        @[(container/container
            :id "sidebar"
            :children
            @[(text/text "Navigation" :classes @["heading"])
              (text/text "")
              (text/text " > Home" :classes @["nav-active"])
              (text/text "   About")
              (text/text "   Settings")])

          (container/container
            :id "content"
            :children
            @[(text/text "Welcome to Chalk!" :classes @["heading"])
              (text/text "")
              (text/text "This demo is styled entirely via CSS.")
              (text/text "No inline styles on any widget.")
              (text/text "The cascade resolves selectors and")
              (text/text "applies properties to the tree.")
              (text/text "")
              (text/text (string "Last key: " (or last-key "(none)")))
              (text/text "")
              (text/text "Press q or ctrl-c to quit."
                         :classes @["dim"])])])]))

(defn main [&]
  (def [cols rows] (platform/get-terminal-size))
  (var current-cols cols)
  (var current-rows rows)
  (var quit false)
  (var last-key nil)

  (platform/enter-raw-mode)
  (defer (do
           (loop/stop)
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

    (var root (build-ui last-key))
    (cascade/apply-stylesheet app-css root)
    (render/render-tree scr root current-cols current-rows)

    (while (not quit)
      (def events (loop/read-events))
      (var needs-redraw false)

      (each event events
        (case (event :type)
          :key
          (do
            (if (or (= (event :key) "q") (= (event :key) :ctrl-c))
              (set quit true)
              (do
                (set last-key (string (event :key)))
                (set needs-redraw true))))

          :resize
          (do
            (set current-cols (event :cols))
            (set current-rows (event :rows))
            (set scr (screen/make-screen current-cols current-rows))
            (screen/screen-force-redraw scr)
            (set needs-redraw true))))

      (when (and needs-redraw (not quit))
        (set root (build-ui last-key))
        (cascade/apply-stylesheet app-css root)
        (render/render-tree scr root current-cols current-rows)))))

(main)
(os/exit 0)
