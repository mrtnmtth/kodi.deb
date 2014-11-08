; based on http://stackoverflow.com/questions/5794640/how-to-convert-xcf-to-png-using-gimp-from-the-command-line
(define (xcf2png from to)
  (let* ((image 0) (layer 0))
    (set! image (car (gimp-file-load RUN-NONINTERACTIVE from from)))
    (set! layer (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE)))
    (gimp-file-save RUN-NONINTERACTIVE image layer to to)
    )
  )
