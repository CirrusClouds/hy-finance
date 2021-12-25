(import json)
(import requests)
(import [bs4 [BeautifulSoup]])
(import pkgutil)
(import os)
(import csv)
(import [yfinance :as yf])
(import [pandas :as pd])
(import time)

(with [f (open "src/resources/russell3000.csv")]
  (setv *reader* (csv.reader f))
  (setv *reader* (list (map (fn [row] (get row 0))
                            *reader*)))
  (setv *russelldata* (cut *reader* 10 -4)))

(with [f (open "src/resources/ftsesmallcap.csv")]
  (setv *reader* (csv.reader f))
  (setv *reader* (list (map (fn [row] (get row 0))
                            *reader*)))
  (setv *ftsedata* (list (map (fn [ticker] (+ ticker ".L")) (cut *reader* 10 -4)))))

(with [f (open "src/resources/koreanstocks.csv")]
  (setv *reader* (csv.reader f))
  (setv *reader* (list (map (fn [row] (get row 0))
                            *reader*)))
  (setv *koreadata* (list (map (fn [ticker] (+ ticker ".KS")) (cut *reader* 10 -4)))))

(with [f (open "src/resources/japanstocks.csv")]
  (setv *reader* (csv.reader f))
  (setv *reader* (list (map (fn [row] (get row 0))
                            *reader*)))
  (setv *japandata* (list (map (fn [ticker] (+ ticker ".T")) (cut *reader* 10 -4)))))

(with [f (open "src/resources/globalsmallcaps.csv")]
  (setv *reader* (csv.reader f))
  (setv *reader* (list (map (fn [row] (get row 0))
                            *reader*)))
  (setv *globalsmalldata* (cut *reader* 10 -4)))

(defn yfin [data]
  (setv acc [])
  (for [datum data]
    (try (do
           (setv tick (yf.Ticker datum))
           (print datum)
           ;; (time.sleep 10)
           ;; (print "sleep! 15?")
           (setv balsheet (.to_dict tick.balancesheet))
           (.append acc (get balsheet (get (list (.keys balsheet)) 0)))
           (setv (get (get acc -1) "Market Cap")
                 (get tick.info "marketCap"))
           (setv (get (get acc -1) "Ticker")
                 datum))
         (except [e Exception]
           (continue))))
  acc)

(defn find-ncav [balsheet]
  (try
    (do
      (setv *current-assets* (get balsheet "Total Current Assets"))
      (setv *total-liabilities* (get balsheet "Total Liab"))
      (setv *equity* (get balsheet "Other Stockholder Equity"))
      (setv *ncav-ratio* (/ (get balsheet "Market Cap") (- *current-assets* (+ *total-liabilities* *equity*))))
      (if (> *ncav-ratio* 0)
          {"ticker" (get balsheet "Ticker")
           "NCAV Ratio" *ncav-ratio*}
          {"ticker" (get balsheet "Ticker")
           "NCAV Ratio" 100000}))
    (except [e Exception]
      None)
    ))

(defn net-net [data]
  (setv *data* (list (filter (fn [datum] (< (get datum "NCAV Ratio") 1))
                             data)))
  (setv *sortedbynetnet* (sorted *data* :key (fn [stock] "NCAV Ratio")))
  *sortedbynetnet*)

(if (= __name__ "__main__")
    (do
      (print "Collecting and processing data...")
      (print "Searching for Net-Nets...")
      (setv *data* (cut *globalsmalldata* 2801 3200)) 
      (setv *data* (yfin *data*))
      (setv *data* (list (filter (fn [x] x) (list (map (fn [diction] (find-ncav diction))
                                                      *data*)))))
      (print *data*)
      (print (net-net *data*))
      (setv *scriptdir* (os.path.dirname __file__))
      (with [f (open (os.path.join *scriptdir* "resources/GlobalSmallCapNetNet.json") "w")]
        (f.write (json.dumps (net-net *data*) :indent 4)))
      (print "Done!")
      ) )
