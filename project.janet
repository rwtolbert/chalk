(def info (-> (slurp "./bundle/info.jdn") parse))

(declare-project
  :name (info :name)
  :description (info :description))

(declare-source
  :source @["chalk"])

(declare-binscript
  :main "demo/bundle_browser.janet"
  :hardcode-syspath true
  :is-janet true)
