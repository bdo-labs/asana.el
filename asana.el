;;
;; Asana
;;
;; Interact with an Asana-project comfortably within Emacs
;;
;; Makes an Asana-project available within Emacs. It uses `helm` to
;; quickly filter tasks and once you've found the one your looking
;; for, you can grab it (assign it to yourself); comment it or change
;; it's current status. Additionally, you can commit your work using
;; the task in it's entirety as the commit-message.
;;
;; For this package to work properly, you'll need to make your
;; personal asana-token available. You do that, by adding it to the
;; environment-variable `ASANA_TOKEN`. Then I would recommend making a
;; `.dir-locals.el` in the root of your project where you set a
;; project-id. Ex. `(setq asana-project-id "000000000000001")`
;; That should be all there is to it. You can now issue asana-tasklist
;; at will.
;;
;; Author: Henrik Kjerringvåg <hekj@bdo.no>
;; License: GNU General Public License v.30
;; Version: 0.0.1
;;


(use-package cl-lib)
(use-package helm)
(use-package request)
(use-package browse-url)


(defvar asana-project-id nil "Asana project to search")
(defvar asana-current-project nil "More detailed information about the project")
(defvar asana-current-user nil "Information about the owner of the personal-token (you)")
(defvar asana-current-tasklist nil "Filtered list of tasks")
(defvar asana-current-task nil "Last selected task")


(defconst asana-token (getenv "ASANA_TOKEN"))
(defconst asana-api "https://app.asana.com/api/1.0")
(defconst asana-headers `(("Content-Type" . "application/x-www-form-urlencoded")
                          ("Authorization" . ,(concat "Bearer " asana-token))))


;; Macro helpers ----------------------------------------------------------


(defmacro ->> (&rest body)
      (let ((result (pop body)))
        (dolist (form body result)
          (setq result (append form (list result))))))


(defmacro -> (&rest body)
      (let ((result (pop body)))
        (dolist (form body result)
          (setq result (append (list (car form) result)
                               (cdr form))))))


;; Actions ----------------------------------------------------------------


(defun asana-select-task (task)
  (setq asana-current-task task))


(defun asana-complete-task (task)
  (let* ((task-id (number-to-string (assoc-default 'id task)))
         (url (concat asana-api "/tasks/" task-id)))
    (request url
             :type "PUT"
             :data "completed=true"
             :headers asana-headers
             :parser 'json-read
             :error (cl-function
                     (lambda (&rest args &key error-thrown &allow-other-keys)
                       (message "Error: %s" error-thrown)))
             :success (cl-function
                       (lambda (&key data &allow-other-keys)
                         (print "Do some verification"))))))


(defun asana-assign-me-task (task)
  (let* ((task-id (number-to-string (assoc-default 'id task)))
         (url (concat asana-api "/tasks/" task-id)))
    (request url
             :type "PUT"
             :data "assignee=me"
             :headers asana-headers
             :parser 'json-read
             :error (cl-function
                     (lambda (&rest args &key error-thrown &allow-other-keys)
                       (message "Error: %s" error-thrown)))
             :success (cl-function
                       (lambda (&key data &allow-other-keys)
                         (print "Do some verification"))))))


(defun asana-open-task (task)
  (let* ((workspace (assoc-default 'workspace task))
         (workspace-id (number-to-string (assoc-default 'id workspace)))
         (task-id (number-to-string (assoc-default 'id task)))
         (url (concat "https://app.asana.com/0/" workspace-id "/" task-id)))
    (browse-url url)))


;; Modifiers --------------------------------------------------------------


(defun asana-filter-incomplete (tasks)
  (->> tasks
       (cl-remove-if-not
        (lambda (task)
          (equal (assoc-default 'completed task) :json-false))))) 


(defun asana-filter-mine (tasks)
  (->> tasks
       (cl-remove-if-not
        (lambda (task)
          (let ((assignee (assoc-default 'assignee task)))
            (equal (assoc-default 'id assignee)
                   (assoc-default 'id asana-current-user)))))))


;; Gather Intel -----------------------------------------------------------


(defun asana-whoami ()
  (let ((url (concat asana-api "/users/me")))
    (request url
             :headers asana-headers
             :parser 'json-read
             :error (cl-function
                     (lambda (&rest args &key error-thrown &allow-other-keys)
                       (message "Error: %s" error-thrown)))
             :success (cl-function
                       (lambda (&key data &allow-other-keys)
                         (setq asana-current-user (assoc-default 'data data)))))))


(defun asana-project-information (project-id)
  (let ((url (concat asana-api "/projects/" project-id)))
    (request url
             :parser 'json-read
             :headers asana-headers
             :error (cl-function
                     (lambda (&rest args &key error-thrown &allow-other-keys)
                       (message "Error: %s" error-thrown)))
             :success (cl-function
                       (lambda (&key data &allow-other-keys)
                         (let ((project (assoc-default 'data data)))
                           (setq asana-current-project project)))))))


(defun asana-list-project-tasks (project-id)
  (let ((url (concat asana-api "/projects/" project-id "/tasks")))
    (request url
             :params '(("opt_fields" . "name,id,completed,workspace,assignee") ("limit" . "100"))
             :parser 'json-read
             :headers asana-headers
             :error (cl-function
                     (lambda (&rest args &key error-thrown &allow-other-keys)
                       (message "Error: %s" error-thrown)))
             :success (cl-function
                       (lambda (&key data &allow-other-keys)
                         (let* ((raw (assoc-default 'data data))
                                (tasks (->> raw
                                            (mapcar (lambda (task) `(,(assoc-default 'name task) . (task . ,task))))
                                            (remove-if 'null)
                                            (asana-filter-incomplete)
                                            (asana-filter-mine))))
                           (setq asana-current-tasklist tasks)
                           (and helm-alive-p (helm-update))))))))


;; Tidbits ----------------------------------------------------------------


(defun asana-commit-msg ()
  "Composes a commit-message from the selected task"
  (interactive)
  (let* ((task asana-current-task)
         (workspace (assoc-default 'workspace task))
         (workspace-id (number-to-string (assoc-default 'id workspace)))
         (task-id (number-to-string (assoc-default 'id task)))
         (url (concat "https://app.asana.com/0/" workspace-id "/" task-id)))
    (insert (concat (assoc-default 'name task) "\n\n" url))
    (previous-line 2)
    (end-of-line)
    (evil-insert-state)))


;; Helm -------------------------------------------------------------------


(defun asana-sources ()
  `((name . ,(assoc-default 'name asana-current-project))
    (candidates . ,asana-current-tasklist)
    (action . (("Select task" . asana-select-task)
               ("Complete task" . asana-complete-task)
               ("Assign to me" . asana-assign-me-task)
               ("Open in Asana" . asana-open-task)
               ("`-c' Show Completed Tasks" . asana-toggle-show-completed)
               ("`-o' Show Tasks Assigned to Others" . asana-toggle-show-others)))
    (fuzzy-match . t)))


;; TODO Apply filters using modifiers-strategy
(defun asana-tasklist ()
  "Search incomplete tasks for the current project"
  (interactive)
  (if (equal 'nil asana-project-id)
      (error "You have to set `asana-project-id`")
    (progn (asana-whoami)
           (asana-project-information asana-project-id)
           (asana-list-project-tasks asana-project-id)
           (helm :sources (asana-sources)
                 :buffer "*helm list-project-tasks*"))))
