globals [
  nest-food            ;; количество собранной еды в гнезде
]

turtles-own [
  carrying?            ;; несёт ли муравей еду (true/false)
]

patches-own [
  chemical             ;; количество феромона на патче
  food                 ;; количество еды на патче
  nest?                ;; принадлежит ли патч гнезду
  nest-scent           ;; чем ближе к гнезду, тем больше значение
  food-source-number   ;; номер источника еды (1, 2 или 3)
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  set nest-food 0
  set-default-shape turtles "bug"
  create-turtles population
  [
    set size 2
    set color red          ;; красный = без еды
    set carrying? false
  ]
  setup-patches
  reset-ticks
end

to clear-pheromones
  ask patches [ set chemical 0 ]
end
to setup-patches
  ask patches
  [
    set chemical 0
    set food 0
    set food-source-number 0
    setup-nest
    setup-food
    recolor-patch
  ]
end

to setup-nest  ;; patch procedure
  ;; гнездо в центре радиусом 5
  set nest? (distancexy 0 0) < 5
  ;; чем ближе к гнезду, тем сильнее "запах" гнезда
  set nest-scent 200 - distancexy 0 0
end

to setup-food  ;; patch procedure
  ;; количество источников задаётся слайдером food-sources (1–3)

  ;; источник 1 — справа
  if (food-sources >= 1) and ((distancexy (0.6 * max-pxcor) 0) < 5)
  [
    set food-source-number 1
  ]

  ;; источник 2 — снизу слева
  if (food-sources >= 2) and ((distancexy (-0.6 * max-pxcor) (-0.6 * max-pycor)) < 5)
  [
    set food-source-number 2
  ]

  ;; источник 3 — сверху слева
  if (food-sources >= 3) and ((distancexy (-0.8 * max-pxcor) (0.8 * max-pycor)) < 5)
  [
    set food-source-number 3
  ]

  ;; на патчах-источниках еды кладём 1 или 2 единицы
  if food-source-number > 0
  [
    set food one-of [1 2]
  ]
end

to recolor-patch  ;; patch procedure
  ifelse nest?
  [
    set pcolor violet
  ]
  [
    ifelse food > 0
    [
      if food-source-number = 1 [ set pcolor cyan ]
      if food-source-number = 2 [ set pcolor sky  ]
      if food-source-number = 3 [ set pcolor blue ]
    ]
    [
      ;; цвет показывает концентрацию феромона
      set pcolor scale-color green chemical 0.1 5
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;
;;; Go procedures ;;;
;;;;;;;;;;;;;;;;;;;;;

to go  ;; forever button
  ask turtles
  [
    ;; задержка старта, как в оригинальной модели
    if who >= ticks [ stop ]

    ifelse carrying?
    [
      ;; несёт еду — идёт к гнезду
      return-to-nest
    ]
    [
      ;; без еды — ищет еду
      look-for-food
    ]
    wiggle
    fd 1
  ]

  ;; диффузия феромона
  diffuse chemical (diffusion-rate / 100)

  ;; испарение + перекраска патчей
  ask patches
  [
    set chemical chemical * (100 - evaporation-rate) / 100
    recolor-patch
  ]

  ;; рождение новых муравьёв, если включено и еды достаточно
  if spawning-enabled
  [
    maybe-spawn-ants
  ]

  tick
end

to return-to-nest  ;; turtle procedure
  if nest?
  [
    ;; если муравей несёт еду — добавляем в запас гнезда
    if carrying?
    [
      set nest-food nest-food + 1
      set carrying? false
    ]
    ;; развернуться обратно в поле
    set color red
    rt 180
    stop
  ]

  ;; не в гнезде — оставить феромон и двигаться к гнезду
  set chemical chemical + 60
  uphill-nest-scent
end

to look-for-food  ;; turtle procedure
  ;; если на патче есть еда — взять её
  if food > 0
  [
    set carrying? true

    ;; цвет муравья зависит от источника (для наглядности)
    if food-source-number = 1 [ set color orange + 1 ]
    if food-source-number = 2 [ set color orange + 2 ]
    if food-source-number = 3 [ set color orange + 3 ]

    set food food - 1
    rt 180         ;; развернуться к гнезду
    stop
  ]

  ;; идти туда, где сильнее запах феромона
  if (chemical >= 0.05) and (chemical < 2)
  [
    uphill-chemical
  ]
end

;; понюхать вперёд, вправо, влево и пойти туда, где сильнее запах феромона
to uphill-chemical  ;; turtle procedure
  let scent-ahead chemical-scent-at-angle   0
  let scent-right chemical-scent-at-angle  45
  let scent-left  chemical-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [
    ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ]
  ]
end

;; понюхать вперёд, вправо, влево и пойти туда, где сильнее запах гнезда
to uphill-nest-scent  ;; turtle procedure
  let scent-ahead nest-scent-at-angle   0
  let scent-right nest-scent-at-angle  45
  let scent-left  nest-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [
    ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ]
  ]
end

to wiggle  ;; turtle procedure
  rt random 40
  lt random 40
  if not can-move? 1 [ rt 180 ]
end

to-report nest-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [nest-scent] of p
end

to-report chemical-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [chemical] of p
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Новые процедуры
;;;;;;;;;;;;;;;;;;;;;;;;;;;

to maybe-spawn-ants
  ;; сколько новых муравьёв "заслужили" по накопленной пище
  let new-ants floor (nest-food / food-per-new-ant)
  if new-ants <= 0 [ stop ]

  ;; уменьшаем запас еды в гнезде
  set nest-food nest-food - new-ants * food-per-new-ant

  ;; создаём new-ants муравьёв на патчах гнезда
  ask n-of new-ants patches with [nest?]
  [
    sprout 1
    [
      set size 2
      set color red
      set carrying? false
      rt random 360
    ]
  ]
end

; Copyright 1997 Uri Wilensky.
; See Info tab for full copyright and license.
