(import [numpy :as np])
(import [matplotlib [pyplot :as plt]])
(import datetime)
(import [datetime :as dt])    
(import logging)
(import [analyser [get-asset-data *data* *connection* execute-query]])

(defn post-tax-div-yield [ticker]
  (setv div_yield_before_tax (* 0.01 (get (get (execute-query *connection* f"select div_yield from investments where ticker = '{ticker}'") 0) 0)))
  (if (= (get (get (execute-query *connection* f"select location from investments where ticker = '{ticker}'") 0) 0) "US")
      (- div_yield_before_tax (* 0.2 div_yield_before_tax))
      div_yield_before_tax))


(defn expected-dividends [ticker]
  (* (post-tax-div-yield ticker) (get (get (execute-query *connection* f"select investment from investments where ticker = '{ticker}'") 0) 0)))


(defn set-expected-dividends [asset-set]
  (setv *total* (get-asset-data asset-set))
  (setv *dividend-data* (list (map (fn [datum]
                                     (expected-dividends (get datum "TICKER")))
                                     asset-set)))
  
  (return [(* 100 (/ (sum *dividend-data*) (sum *total*))) (sum *dividend-data*)]))


(defn find-amount-needed-for [ticker desired-income]
  (setv dividend_yield (post-tax-div-yield ticker))
  (if (= (get (get (execute-query *connection* f"select div_yield from investments where ticker = '{ticker}'") 0) 0) 0.0)
      "N/A"
      (round (/ desired-income dividend_yield) 2)))

(defn dividend-snowball [years]
  (setv *total* (sum (get-asset-data *data*)))
  (setv *years* (list (range 0 years)))
  (setv *div_yield* (round (get (set-expected-dividends *data*) 0) 2))
  (setv *getalldatanogrowth* (list (map (fn [yr]
                                          (* *total*
                                             (** (+ 1 (/ *div_yield* 100)) yr)))
                                        *years*)))
  
  (setv *getalldatasomegrowth* (list (map (fn [yr]
                                            (* (* *total* (** 1.04 yr))
                                               (** (+ 1 (/ *div_yield* 100)) yr)))
                                          *years*)))
  
  (setv *getalldatalotsgrowth* (list (map (fn [yr]
                                            (* (* *total* (** 1.08 yr))
                                               (** (+ 1 (/ *div_yield* 100)) yr)))
                                          *years*)))


  (plt.figure)
  (plt.xlabel "Time / Yrs")
  (plt.ylabel "Projected worth of assets / GBP")
  (plt.title "Growth predictions with dividend snowball effect (no further investments)")
  (plt.grid)
  (plt.plot *years* *getalldatanogrowth* :label "No growth")
  (plt.plot *years* *getalldatasomegrowth* :label "Some growth")
  (plt.plot *years* *getalldatalotsgrowth* :label "Optimistic growth")
  (plt.legend)
  (plt.savefig f"{years}_growth_projections.png")
  (plt.show))


(defn -main []
  (dividend-snowball 5)
  (dividend-snowball 12)
  (dividend-snowball 25)
  (setv *acc* [])
  (for [datum *data*]
    (do
      (print (get datum #[=[TICKER]=]))
      (.append *acc* (expected-dividends (get datum "TICKER"))) 
        
      (print "Post-Tax Div Yield is:" (round (* 100 (post-tax-div-yield (get datum "TICKER"))) 2) "%")
      (print f"Expected yearly dividend return for {(get datum #[=[TICKER]=])}: £{(round (expected-dividends (get datum #[=[TICKER]=])) 2)}")
      (print f"Investment needed to make £20 a year: £{(find-amount-needed-for (get datum #[=[TICKER]=]) 20)}\n")))
  (print "Avg div yield after tax for all holdings")
  (setv *divyieldall* (* 100 (/ (sum *acc*) (sum (list (map (fn [datum] (get datum "INVESTMENT")) *data*))))))
  (print (+ (str (round *divyieldall* 2)) " %"))
  (print "Which comes to a yearly return of")
  (print (+ "£" (str (round (/ (* *divyieldall* (sum (get-asset-data *data*))) 100) 2)))))


(if (= __name__ "__main__")
    (-main))
