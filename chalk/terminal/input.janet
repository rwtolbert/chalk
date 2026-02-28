# Layer 3: Thin re-export of event parsing for convenient import paths

(import ../events/types)

(def parse-input types/parse-input)
(def key-event types/key-event)
(def mouse-event types/mouse-event)
(def resize-event types/resize-event)
(def quit-event types/quit-event)
