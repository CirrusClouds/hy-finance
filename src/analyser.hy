(import [numpy :as np])
(import [matplotlib [pyplot :as plt]])
(import [datetime :as dt])
(import [dateparser :as dp])
(import logging)
(import sqlite3)

(setv logger (logging.getLogger __name__))
(logging.basicConfig)
(logger.setLevel logging.INFO)


(defn execute-query [connection query]
  (setv cursor (connection.cursor))
  (logger.debug f"Executing {query}")
  (try
    (do
      (cursor.execute query)
      (cursor.fetchall))
    (except [e Exception]
      (logger.error e))))


(defn -create-db []
  (setv new-db (sqlite3.connect "database.db"))
  (execute-query new-db #[==[CREATE TABLE investments(id SERIAL PRIMARY KEY, ticker VARCHAR(8) UNIQUE, investment DECIMAL(14,2), div_yield DECIMAL(14,3), location VARCHAR(6))]==])
  (execute-query new-db #[==[CREATE TABLE history(id SERIAL PRIMARY KEY, date DATE UNIQUE, invested DECIMAL(15,2))]==])
  (new-db.commit)
  (new-db.close))


(defn sql-data-to-dict [connection]
  (setv *data* (execute-query connection "SELECT * FROM investments order by investment desc;"))
  (setv *data2* [])
  (for [datum *data*]
    (*data2*.append {"TICKER" (get datum 1)
                     "INVESTMENT" (get datum 2)
                     "DIV-YIELD" (get datum 3)
                     "LOCATION" (get datum 4)
                     "TYPE" (get datum 5)}))
  *data2*)


(setv *connection* (sqlite3.connect "database.db"))
(setv *data* (sql-data-to-dict *connection*))

(defn get-asset-data [asset-list]
  (list (map (fn [datum]
               (get datum "INVESTMENT"))
             asset-list)))


(defn makepie [title data labels exploder titleid]
  (plt.figure)
  (plt.title title)
  (plt.pie data :labels labels :explode exploder :autopct "%1.1f%%" :shadow False :startangle 90)
  ;; (plt.savefig f"{*mostrecentdate*}_{titleid}.png")
  (plt.show))


(defn piechart [asset-set title exploder desired-ratio comparator compared-to-set compared-to-name showplot]
  (setv *exploder* (np.zeros (len asset-set)))
  (.fill *exploder* exploder)
  
  (setv *assetdata* (get-asset-data asset-set))
  (setv *title-id* (.replace title " " "-"))
  
  (if (= showplot True)
      (makepie title *assetdata* (list (map (fn [datum] (get datum "TICKER")) asset-set)) *exploder* *title-id*))
    
  (print title)
  (print "Total invested:")
  (print (round (sum *assetdata*) 2) "GBP")
  (ratio-tester desired-ratio asset-set compared-to-set comparator compared-to-name))


(defn multichart [title exploder showplot &rest sets]
  (setv *exploder* (np.zeros (len sets)))
  (.fill *exploder* exploder)
  (setv *title-id* (.replace title " " "-"))
  
  (setv *assetdatalist* (list (map (fn [x] (get-asset-data (get x 1))) sets)))
  (setv *sums* (list (map (fn [x] (sum x)) *assetdatalist*)))

  (if showplot
      (makepie title *sums* (list (map (fn [x] (get x 0)) sets)) *exploder* *title-id*))
  )


(defn ratio-tester [desired-ratio set1 set2 set1name set2name]
  (setv *sums* (list (map (fn [x] (sum (get-asset-data x))) [set1 set2])))
  (setv *ratio* (/ (get *sums* 0) (get *sums* 1)))
  (setv *ratio-difference* (- desired-ratio *ratio*))
  (setv *change-needed* (* *ratio-difference* (get *sums* 1)))
  (if (< 0 *change-needed*)
      (print f"You need to buy {(round *change-needed* 2)} GBP worth of {set1name} to reach a ratio of {desired-ratio}")
      (print f"You need to liquidate {(round (- 0 *change-needed*) 2)} GBP worth of {set1name} to reach a ratio of {desired-ratio}")
      )
  (print f"which is currently {(round *ratio* 3)} compared to {set2name}\n"))


(defn -main []
  (piechart *data* "Diversity of all holdings" 0.15 1 "all assets" *data* "all assets" True)
  (try
    (do
      (execute-query *connection* f"INSERT INTO history (date, invested) VALUES ('{(dt.date.today)}', {(sum (get-asset-data *data*))})"))
    (except [e Exception]
      (logger.error e)))
  (setv *historicals* (execute-query *connection* "SELECT * from history order by date asc"))
  (setv *dates* (list (map (fn [datum] (dp.parse (get datum 1))) *historicals*)))
  (setv *amounts* (list (map (fn [datum] (get datum 2)) *historicals*)))
  (plt.figure)
  (plt.grid)
  (plt.title "Portfolio value over time")
  (plt.xlabel "Date")
  (plt.ylabel "Value / £")
  (plt.plot_date *dates* *amounts* :xdate True :fmt "r--")
  (plt.show)
  (setv *query* (execute-query *connection* "select * from investments;"))
  (print f"You have {(len *query*)} stocks")
  (*connection*.commit))


(if (= __name__ "__main__")
    (-main))
