# Layer 7 Demo: Widget tree with text + containers
# Builds UI with containers and text widgets, styled inline.
# Shows last pressed key. Press q or ctrl-c to quit.

(import ../chalk/platform/init :as platform)
(import ../chalk/terminal/output :as output)
(import ../chalk/terminal/screen :as screen)
(import ../chalk/events/loop :as loop)
(import ../chalk/widget/proto)
(import ../chalk/widget/text)
(import ../chalk/widget/container)
(import ../chalk/widget/render)

(defn build-ui [last-key cols rows]
  (container/container
    :id "root"
    :flex-direction :column
    :children
    @[# Title bar
      (container/container
        :id "title-bar"
        :dock :top
        :height 1
        :style {:bg :blue :fg :white :bold true}
        :children
        @[(text/text (string/format " Chalk Widgets Demo  |  %dx%d" cols rows))])

      # Footer
      (container/container
        :id "footer"
        :dock :bottom
        :height 1
        :style {:bg :magenta :fg :bright-white}
        :children
        @[(text/text " q: quit | Chalk TUI Library ")])

      # Middle section
      (container/container
        :id "middle"
        :flex-direction :row
        :flex-grow 1
        :children
        @[# Sidebar
          (container/container
            :id "sidebar"
            :width 24
            :style {:bg :green :fg :black}
            :padding 1
            :children
            @[(text/text "Navigation" :style {:bold true})
              (text/text "")
              (text/text " > Home")
              (text/text "   About")
              (text/text "   Settings")])

          # Content area
          (container/container
            :id "content"
            :flex-grow 1
            :style {:bg :bright-black :fg :white}
            :padding 1
            :children
            @[(text/text "Welcome to Chalk!" :style {:fg :cyan :bold true})
              (text/text "")
              (text/text "This is a widget-based TUI demo.")
              (text/text "Widgets are composed into a tree,")
              (text/text "laid out with flex, and painted")
              (text/text "to a virtual screen buffer.")
              (text/text "")
              (text/text (string "Last key: " (or last-key "(none)"))
                         :style {:fg :yellow})
              (text/text "")
              (text/text "Press q or ctrl-c to quit."
                         :style {:fg :bright-black})])])]))

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

    # Initial render
    (var root (build-ui last-key current-cols current-rows))
    (render/render-tree scr root current-cols current-rows)

    # Event loop
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
        (set root (build-ui last-key current-cols current-rows))
        (render/render-tree scr root current-cols current-rows)))))

(main)
(os/exit 0)
