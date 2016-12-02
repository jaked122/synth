(in-package :synth)
(use-package :cl)
(defparameter *volume-scale* nil)
(defparameter *sample-rate* 44100)
(defmacro with-sound
    ((stream &rest options &key (sample-rate 44100) (format "S16_LE") (channels 2))
     &body body)
  `(let* ((aplay-process (sb-ext:run-program "/usr/bin/aplay"
                                    (list "-r" (princ-to-string ,sample-rate) "-f" (princ-to-string ,format) "-c" (princ-to-string ,channels) "-")
                                    :input :stream :output nil :wait nil )))
     (setf *volume-scale* (cond
                          ((equal ,format "S16_LE") 32757)
                          ((equal ,format "S32_LE") 2147473647)))
     (setf *sample-rate* ,sample-rate)
     (unwind-protect
          (with-open-stream
              (,stream (sb-ext:process-input aplay-process))
            ,@body)
       (when aplay-process (sb-ext:process-close aplay-process)))))
(defmacro <-(a b)
  "Assign one value to another and return the new one"
  `(progn
     (setf ,a ,b)
     ,a))
(defun get-byte(integer n)
  (ldb (byte 8 (* n 8)) integer))
(defun b-sin(n scale)
  (truncate (* scale (sin n))))
(defun sin-sound(freq volume)
  (declare (type single-float freq volume))
  (lambda (x)
    (declare (type single-float x))
    (b-sin (* freq 2 pi (/ x *sample-rate*)) (* volume *volume-scale*))))
(defstruct (decay)
  (limit 1.0e-5 :type single-float)
  (start 0 :type fixnum))
(defstruct (linear-decay (:include decay)
                         (:conc-name ldecay-))
  "A linear decay mode, modelled after a slope moving downwards (or upwards if you're insane)"
  (rate 1.0e-3 :type single-float))
(defstruct (exp-decay (:include decay)
                      (:conc-name ddecay-))
  "A damped decay mode, modelled after the amplitude of damped harmonic motion"
  (d-const 0.9 :type single-float))
(defgeneric decay-multiplier(decay time))
(defmethod decay-multiplier((decay linear-decay) (time fixnum))
  (* (ldecay-rate decay) (/ (- time (decay-start decay)) *sample-rate*)))
(defmethod decay-multiplier((decay exp-decay) (time fixnum))
  (exp (- 0 (* (ddecay-d-const decay)
               (/ (- time (decay-start decay)) *sample-rate*)))))
(defgeneric calc-decay(amplitude time decay))
(defmethod calc-decay((amplitude single-float) (time fixnum) (decay linear-decay))
  (* (decay-multiplier decay time) amplitude))
(defmethod calc-decay((amplitude single-float) (time fixnum) (decay exp-decay))
  (* amplitude (decay-multiplier decay time)))
(defun is-decay-alive(decay time)
  (< (decay-multiplier decay time)
     (decay-limit decay)))