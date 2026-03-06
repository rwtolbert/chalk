# Tests for chalk/theme

(import ../chalk/theme)

(var pass-count 0)
(defn assert-t [expr &opt msg]
  (assert expr (or msg "assertion failed"))
  (++ pass-count))

# --- deftheme and list-themes ---

(assert-t (find |(= $ :default) (theme/list-themes))
          "default theme exists")
(assert-t (find |(= $ :dracula) (theme/list-themes))
          "dracula theme exists")
(assert-t (>= (length (theme/list-themes)) 11)
          "at least 11 built-in themes")

# Custom theme registration
(theme/deftheme :test-custom
  {:fg :white :bg :black :primary :red})
(assert-t (find |(= $ :test-custom) (theme/list-themes))
          "custom theme registered")

# --- palette ---

# Default theme fills all roles
(def p (theme/palette :default))
(assert-t (= (p :fg) :default) "default fg is :default")
(assert-t (= (p :bg) :default) "default bg is :default")
(assert-t (= (p :primary) :cyan) "default primary is :cyan")
(assert-t (= (p :success) :green) "default success is :green")

# Custom theme fills missing roles with defaults
(def cp (theme/palette :test-custom))
(assert-t (= (cp :fg) :white) "custom fg preserved")
(assert-t (= (cp :primary) :red) "custom primary preserved")
(assert-t (= (cp :muted) :bright-black) "custom muted falls back to default")
(assert-t (= (cp :border) :white) "custom border falls back to fg")
(assert-t (= (cp :border-active) :red) "custom border-active falls back to primary")
(assert-t (= (cp :surface) :black) "custom surface falls back to bg")

# RGB palette values preserved
(def dp (theme/palette :dracula))
(assert-t (= (dp :fg) [248 248 242]) "dracula fg is RGB tuple")
(assert-t (= (dp :bg) [40 42 54]) "dracula bg is RGB tuple")

# Error on unknown theme
(var caught false)
(try (theme/palette :nonexistent) ([_] (set caught true)))
(assert-t caught "palette errors on unknown theme")

# --- color formatting ---

(assert-t (= (theme/color p :fg) "default") "keyword color formats as string")
(assert-t (= (theme/color p :primary) "cyan") "keyword primary formats")
(assert-t (= (theme/color dp :fg) "rgb(248,248,242)") "RGB tuple formats as rgb()")
(assert-t (= (theme/color dp :bg) "rgb(40,42,54)") "RGB bg formats as rgb()")

# Number colors
(def np @{:fg 196})
(assert-t (= (theme/color np :fg) "196") "number color formats as string")

(print (string "  " pass-count " tests passed"))
