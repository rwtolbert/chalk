# Layer 1: Platform abstraction entry point
# Detects OS and re-exports the appropriate backend.

(import ./posix)

(defn enter-raw-mode [] (posix/enter-raw-mode))
(defn exit-raw-mode [] (posix/exit-raw-mode))
(defn raw-mode? [] (posix/raw-mode?))
(defn get-terminal-size [] (posix/get-terminal-size))
(defn open-tty [] (posix/open-tty))
(defn close-tty [fd] (posix/close-tty fd))
(defn poll-tty [fd timeout-ms] (posix/poll-tty fd timeout-ms))
(defn read-tty [fd nbytes] (posix/read-tty fd nbytes))
(defn write-stdout [buf] (posix/write-stdout buf))
