;;
;;
;;
;;
(defmodule lfe-hop
  (export all)
  (import
    (from dict (store 3)
               (filter 2)
               (map 2)
               (fetch 2))
    (rename dict ((new 0) new-dict)
                 ((fetch_keys 1) keys)
                 ((from_list 1) tuples->dict))
    (from lists (append 1)
                (append 2))
    (rename lists ((member 2) in?))
    ))


(defun first
  ((tasks) (when (>= (length tasks) 1))
    (car tasks))
  ((_)
    'false))

(defun search-operators (state tasks operators methods plan task depth)
  (let* ((operator-name (car task))
         (operator (fetch operator-name operators))
         (remaining (cdr task))
         (state (apply operator remaining)))
    (cond
      ((/= state 'false)
       (let ((solution (find-plan state (cdr tasks) operators methods
                                  (append plan '(task)) (+ depth 1))))
         (cond
           ((/= solution 'false) solution)))))))


(defun process-subtasks (state tasks operators methods plan task depth method)
  (let ((subtasks (apply method (append '(state) (cdr task)))))
    (cond
      ((/= subtasks 'false)
       (let ((solution (find-plan state (append subtasks (cdr tasks)) operators
                                  methods plan (+ depth 1))))
         (cond
           ((/= solution 'false) solution)))))))

(defun search-methods (state tasks operators methods plan task depth)
  (let* ((method-name (car task))
         (relevant-methods (fetch method-name methods)))
    (map (lambda (method)
           (process-subtasks state tasks operators methods plan task depth
                             method))
         relevant-methods)))

(defun find-plan (state tasks operators methods)
  (let ((plan ())
        (depth 0))
    (find-plan state tasks operators methods plan depth)))

(defun find-plan (state tasks operators methods plan depth)
  ""
  (let* ((task (first tasks))
         (task-key (car task)))
    (cond
      ((== tasks ())
        plan)
      ((in? task-key (keys operators))
        (search-operators state tasks operators methods plan task depth))
      ((in? task-key (keys methods))
        (search-methods state tasks operators methods plan task depth))
      ('true 'false))))

