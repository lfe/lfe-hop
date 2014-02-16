(defmodule hop_tests
  (export all)
  (import
    (from dict (store 3)
               (filter 2)
               (map 2)
               (fetch 2))
    (rename dict ((new 0) new-dict)
                 ((fetch_keys 1) keys))))

(include-lib "deps/lfeunit/include/lfeunit-macros.lfe")
(include-lib "include/hop-macros.lfe")

;; Set up data for tests

(defrecord entity
  name
  location
  (cash-total 0)
  (cash-owed 0))

(defun get-min-walking-distance ()
  2)

(defun get-taxi-rate (distance)
  (+ 1.5 (* 0.5 distance)))

(defun get-distance
  (('"home" '"park")
   8)
  (('"park" '"home")
   8)
  (('"downtown" '"home")
   17)
  (('"home" '"downtown")
   17)
  (('"park" '"downtown")
   21)
  (('"downtown" '"park")
   21))

(defun get-location (state name)
  (entity-location (fetch name state)))

(defun move (state agent-name location)
  (let ((mover (fetch agent-name state)))
    (store agent-name
           (set-entity-location mover location)
           state)))

(defun owe (state agent-name amount)
  (let ((payer (fetch agent-name state)))
    (store agent-name
           (set-entity-cash-owed payer amount)
           state)))

(defun update-cash (state agent-name amount)
  (let* ((cash-holder (fetch agent-name state))
         (cash (entity-cash-total cash-holder)))
    (store agent-name
           (set-entity-cash-total cash-holder (+ cash amount))
           state)))

(defun pay-cash (state payer-name payee-name amount)
  (let* ((payer (fetch payer-name state))
         (payer-cash (entity-cash-total payer))
         (payer-owed (entity-cash-owed payer))
         (state (update-cash state payer-name (* -1 amount)))
         (state (owe state payer-name (- payer-owed amount)))
         (payee (fetch payee-name state)))
    (cond
      ((>= payer-cash payer-owed)
        (update-cash state payee-name amount))
      ('true 'false))))

(defun walk (state agent-name location destination)
  (cond
    ((== (get-location state agent-name) location)
      (move state agent-name destination))
    ('true 'false)))

(defun call-taxi (state location)
  (move state '"Taxi" location))

(defun ride-taxi (state agent-name pickup destination)
  (let ((taxi-name '"Taxi"))
    (cond
      ((and
         (== (get-location state taxi-name) pickup)
         (== (get-location state agent-name) pickup))
       (let* ((state (move state taxi-name destination))
              (state (move state agent-name destination))
              (fee (get-taxi-rate (get-distance pickup destination))))
         (owe state agent-name fee)))
      ('true 'false))))

(defun pay-taxi (state agent-name amount)
  (pay-cash state agent-name '"Taxi" amount))

(defun travel-by-foot (state agent-name location destination)
  (cond
    ((=< (get-min-walking-distance) (get-distance location destination))
      (subtasks
        `(walk ,agent-name ,location ,destination)))
    ('true 'false)))

(defun travel-by-taxi (state agent-name pickup destination)
  (let* ((traveler (fetch agent-name state))
         (traveler-cash (entity-cash-total traveler))
         (fee (get-taxi-rate (get-distance pickup destination))))
    (cond
      ((>= traveler-cash fee)
        (subtasks
          `(call-taxi ,pickup)
          `(ride-taxi ,agent-name ,pickup ,destination)
          `(pay-taxi ,agent-name ,fee)))
      ('true 'false))))

(defoperators operators
  `(#(walk ,#'walk/4)
    #(call-taxi ,#'call-taxi/2)
    #(ride-taxi ,#'ride-taxi/4)
    #(pay-cash ,#'pay-cash/4)))

(defmethods methods
  `(#(travel (,#'travel-by-foot/4
              ,#'travel-by-taxi/4))))

(defun state ()
  (let* ((bob (make-entity name '"Bob" location '"home" cash-total 10))
         (state (store (entity-name bob) bob (new-dict)))
         (taxi (make-entity name '"Taxi" location '"downtown")))
    (store (entity-name taxi) taxi state)))

(deftasks tasks-empty
  '())

(deftasks tasks-no-matching
  '(stay-at-home "Bob" "home" "home"))

(deftasks tasks-one-method
  '(travel "Bob" "home" "park"))

(deftasks tasks-one-operator
  '(walk "Bob" "home" "park"))

(deftasks tasks-some
  '(travel "Bob" "home" "park")
  '(walk "Bob" "park" "home"))

;; Start of actual tests

(deftest search-operators-false-state
  (is-equal '() (: hop search-operators
                   'false
                   (tasks-empty)
                   (operators)
                   (methods)
                   'plan
                   (car (tasks-one-operator))
                   0)))

(deftest find-plan-empty-tasks
  (is-equal '() (: hop find-plan
                   (state)
                   (tasks-empty)
                   (operators)
                   (methods)))
  (is-equal
    '(the-plan "do this" "then that")
    (: hop find-plan
       (state)
       (tasks-empty)
       (operators)
       (methods)
       '(the-plan "do this" "then that"))))

(deftest find-plan-no-matching-task-key
  (is-equal 'false (: hop find-plan
                     (state)
                     (tasks-no-matching)
                     (operators)
                     (methods))))

(deftest find-plan-operator-task
  (is-equal '() (: hop find-plan
                   (state)
                   (tasks-one-operator)
                   (operators)
                   (methods))))

(deftest find-plan-method-task
  (is-equal '() (: hop find-plan
                   (state)
                   (tasks-one-method)
                   (operators)
                   (methods))))
