(vl-load-com)

(defun md:split (text separator / position result)
  (setq result nil)
  (while (setq position (vl-string-search separator text))
    (setq result (cons (substr text 1 position) result))
    (setq text (substr text (+ position 2)))
  )
  (reverse (cons text result))
)

(defun md:read-tables (path / file line fields name headers rows result package-valid)
  (setq file (open path "r"))
  (if (null file)
    nil
    (progn
      (setq result nil)
      (setq package-valid nil)
      (while (setq line (read-line file))
        (setq fields (md:split line (chr 9)))
        (cond
          ((and
             (equal (car fields) "#CAD_PACKAGE")
             (equal (cadr fields) "1")
           )
            (setq package-valid T)
          )
          ((and (equal (car fields) "#TABLE") (= (length fields) 2))
            (progn
              (if name
                (setq result
                  (cons (list name headers (reverse rows)) result)
                )
              )
              (setq name (cadr fields))
              (setq headers nil)
              (setq rows nil)
            )
          )
          (name
            (if headers
              (setq rows (cons fields rows))
              (setq headers fields)
            )
          )
        )
      )
      (if name
        (setq result
          (cons (list name headers (reverse rows)) result)
        )
      )
      (close file)
      (if package-valid
        (reverse result)
        nil
      )
    )
  )
)

(defun md:ensure-layer ()
  (if (null (tblsearch "LAYER" "DESCIDAS_AUTO"))
    (entmake
      '(
        (0 . "LAYER")
        (100 . "AcDbSymbolTableRecord")
        (100 . "AcDbLayerTableRecord")
        (2 . "DESCIDAS_AUTO")
        (70 . 0)
        (62 . 7)
        (6 . "Continuous")
      )
    )
  )
)

(defun md:fill (x y width height color)
  (entmakex
    (list
      '(0 . "SOLID")
      '(100 . "AcDbEntity")
      '(8 . "DESCIDAS_AUTO")
      (cons 62 color)
      '(100 . "AcDbTrace")
      (cons 10 (list x y 0.0))
      (cons 11 (list (+ x width) y 0.0))
      (cons 12 (list x (+ y height) 0.0))
      (cons 13 (list (+ x width) (+ y height) 0.0))
    )
  )
)

(defun md:line (x1 y1 x2 y2)
  (entmakex
    (list
      '(0 . "LINE")
      '(100 . "AcDbEntity")
      '(8 . "DESCIDAS_AUTO")
      '(62 . 7)
      '(100 . "AcDbLine")
      (cons 10 (list x1 y1 0.0))
      (cons 11 (list x2 y2 0.0))
    )
  )
)

(defun md:text (value x y height centered)
  (if centered
    (entmakex
      (list
        '(0 . "TEXT")
        '(100 . "AcDbEntity")
        '(8 . "DESCIDAS_AUTO")
        '(62 . 7)
        '(100 . "AcDbText")
        (cons 10 (list x y 0.0))
        (cons 11 (list x y 0.0))
        (cons 40 height)
        (cons 1 value)
        (cons 7 (getvar "TEXTSTYLE"))
        '(72 . 1)
        '(73 . 2)
      )
    )
    (entmakex
      (list
        '(0 . "TEXT")
        '(100 . "AcDbEntity")
        '(8 . "DESCIDAS_AUTO")
        '(62 . 7)
        '(100 . "AcDbText")
        (cons 10 (list x y 0.0))
        (cons 40 height)
        (cons 1 value)
        (cons 7 (getvar "TEXTSTYLE"))
        '(72 . 0)
        '(73 . 0)
      )
    )
  )
)

(defun md:text-width (value height / box)
  (if (or (null value) (= value ""))
    0.0
    (progn
      (setq box
        (vl-catch-all-apply
          'textbox
          (list (list (cons 1 value) (cons 40 height) (cons 7 (getvar "TEXTSTYLE"))))
        )
      )
      (if (or (null box) (vl-catch-all-error-p box))
        (* height (strlen value))
        (- (caadr box) (caar box))
      )
    )
  )
)

(defun md:widths (headers rows height / widths index maximum row width)
  (setq widths nil)
  (setq index 0)
  (repeat (length headers)
    (setq maximum (md:text-width (nth index headers) height))
    (foreach row rows
      (setq width (md:text-width (nth index row) height))
      (if (> width maximum)
        (setq maximum width)
      )
    )
    (setq widths
      (cons
        (max (* height 8.0) (+ maximum (* height 1.2)))
        widths
      )
    )
    (setq index (1+ index))
  )
  (reverse widths)
)

(defun md:sum (values / total)
  (setq total 0.0)
  (foreach value values
    (setq total (+ total value))
  )
  total
)

(defun md:draw-table (title headers rows x top height category-color / widths row-height table-width y index cell-x cell-width row value color baseline)
  (setq widths (md:widths headers rows height))
  (setq row-height (* height 1.8))
  (setq table-width (md:sum widths))
  (setq y top)

  (md:fill x (- y row-height) table-width row-height 8)
  (md:text
    title
    (+ x (/ table-width 2.0))
    (+ (- y row-height) (/ row-height 2.0))
    height
    T
  )
  (setq y (- y row-height))

  (setq index 0)
  (setq cell-x x)
  (foreach value headers
    (setq cell-width (nth index widths))
    (md:fill cell-x (- y row-height) cell-width row-height 8)
    (setq baseline (+ (- y row-height) (* height 0.45)))
    (md:text value (+ cell-x (* height 0.6)) baseline height nil)
    (setq cell-x (+ cell-x cell-width))
    (setq index (1+ index))
  )
  (setq y (- y row-height))

  (foreach row rows
    (setq index 0)
    (setq cell-x x)
    (repeat (length widths)
      (setq cell-width (nth index widths))
      (setq color (if (= index 0) category-color 8))
      (md:fill cell-x (- y row-height) cell-width row-height color)
      (setq value (nth index row))
      (if (null value)
        (setq value "")
      )
      (setq baseline (+ (- y row-height) (* height 0.45)))
      (md:text value (+ cell-x (* height 0.6)) baseline height nil)
      (setq cell-x (+ cell-x cell-width))
      (setq index (1+ index))
    )
    (setq y (- y row-height))
  )

  (md:line x top (+ x table-width) top)
  (md:line x y (+ x table-width) y)
  (setq index 0)
  (setq cell-x x)
  (foreach cell-width widths
    (md:line cell-x top cell-x y)
    (setq cell-x (+ cell-x cell-width))
    (setq index (1+ index))
  )
  (md:line cell-x top cell-x y)
  (setq index 1)
  (repeat (+ (length rows) 1)
    (md:line x (- top (* row-height index)) (+ x table-width) (- top (* row-height index)))
    (setq index (1+ index))
  )
  y
)

(defun md:draw-legend (x top height / row-height color-width description-width table-width y palette entry color)
  (setq row-height (* height 1.8))
  (setq color-width (* height 6.0))
  (setq description-width (* height 90.0))
  (setq table-width (+ color-width description-width))
  (setq y top)

  (md:fill x (- y row-height) table-width row-height 8)
  (md:text
    (strcat "LEGENDA RELAT" (chr 211) "RIO DE DESCIDAS")
    (+ x (/ table-width 2.0))
    (+ (- y row-height) (/ row-height 2.0))
    height
    T
  )
  (setq y (- y row-height))
  (md:fill x (- y row-height) table-width row-height 8)
  (md:text
    "LISTA INFORMATIVA DE CORES E PONTOS DE DESCIDAS E PROCESSOS CORRESPONDENTES"
    (+ x (/ table-width 2.0))
    (+ (- y row-height) (/ row-height 2.0))
    (* height 0.75)
    T
  )
  (setq y (- y row-height))
  (md:fill x (- y row-height) color-width row-height 8)
  (md:fill (+ x color-width) (- y row-height) description-width row-height 8)
  (md:text "CORES" (+ x (* height 0.6)) (+ (- y row-height) (* height 0.45)) height nil)
  (md:text
    (strcat "DESCRI" (chr 199) (chr 195) "O")
    (+ x color-width (* height 0.6))
    (+ (- y row-height) (* height 0.45))
    height
    nil
  )
  (setq y (- y row-height))

  (setq palette
    (list
      (list 30 (strcat "PONTOS DE LIGA" (chr 199) (chr 195) "O DE MOTORES - TRANSPORTADORES"))
      (list 5 "PONTOS DE COMANDO")
      (list 6 (strcat "CABOS ETHERNET (COMUNICA" (chr 199) (chr 195) "O ENTRE EQUIPAMENTOS E PONTOS ETHERNET)"))
      (list 3 (strcat "ALIMENTA" (chr 199) (chr 195) "O DOS EQUIPAMENTOS"))
      (list 8 "PONTOS DE TOMADA IDENTIFICADOS COM (T)")
      (list 210 "PONTOS DE CABOS DE REDE ENTRE EQUIPAMENTO (CAT5E)")
      (list 4 "PONTOS DE CABOS DE COMANDO (MULTIVIAS) ENTRE EQUIPAMENTOS")
      (list 7 "PONTOS DE ACIONAMENTOS E RESERVAS")
    )
  )
  (foreach entry palette
    (setq color (car entry))
    (md:fill x (- y row-height) color-width row-height color)
    (md:fill (+ x color-width) (- y row-height) description-width row-height 8)
    (md:text (cadr entry) (+ x color-width (* height 0.6)) (+ (- y row-height) (* height 0.45)) (* height 0.75) nil)
    (setq y (- y row-height))
  )

  (md:line x top (+ x table-width) top)
  (md:line x y (+ x table-width) y)
  (md:line x top x y)
  (md:line (+ x color-width) top (+ x color-width) y)
  (md:line (+ x table-width) top (+ x table-width) y)
  (setq row-height (* height 1.8))
  (setq y top)
  (repeat 10
    (setq y (- y row-height))
    (md:line x y (+ x table-width) y)
  )
  y
)

(defun c:INSERIR_DESCIDAS (/ path default-height text-height origin)
  (setq path (getfiled "Selecione o arquivo de dados do relatorio" "" "tsv" 0))
  (if path
    (progn
      (setq origin (getpoint "\nClique no canto superior esquerdo onde as tabelas serao inseridas: "))
      (if origin
        (progn
          (setq default-height (md:default-height))
          (setq text-height (getreal (strcat "\nAltura do texto <" (rtos default-height 2 2) ">: ")))
          (md:run path (if text-height text-height default-height) origin)
        )
      )
    )
  )
  (princ)
)

(defun md:default-height (/ ext-min ext-max drawing-height)
  (setq ext-min (getvar "EXTMIN"))
  (setq ext-max (getvar "EXTMAX"))
  (setq drawing-height (- (cadr ext-max) (cadr ext-min)))
  (if (> drawing-height 0.0) (* drawing-height 0.002) 2.5)
)

(defun md:fechar ()
  (if (= (getvar "DBMOD") 0)
    (command "_.QUIT")
    (command "_.QUIT" "_Y")
  )
)

(defun md:interativo (path done-path / tables origin status f)
  (setq tables (md:read-tables path))
  (if tables
    (progn
      (setq origin
        (vl-catch-all-apply
          'getpoint
          (list "\nClique no canto superior esquerdo onde as tabelas serao inseridas: ")
        )
      )
      (if (and origin (not (vl-catch-all-error-p origin)))
        (progn
          (setq status
            (vl-catch-all-apply 'md:run (list path (md:default-height) origin))
          )
          (if (not (vl-catch-all-error-p status))
            (progn
              (command "_.QSAVE")
              (if (= (getvar "DBMOD") 0)
                (progn
                  (setq f (open done-path "w"))
                  (write-line "ok" f)
                  (close f)
                )
              )
            )
          )
        )
      )
    )
  )
  (md:fechar)
  (princ)
)

(defun md:run (path text-height origin / tables x y table color title point)
  (if path
    (progn
      (setq tables (md:read-tables path))
      (if (null tables)
        (prompt "\nNao foi possivel ler tabelas com dados no arquivo selecionado.")
        (progn
          (md:ensure-layer)
          (if (<= text-height 0.0)
            (prompt "\nA altura do texto deve ser maior que zero.")
            (progn
              (setq point (trans origin 1 0))
              (setq x (car point))
              (setq y (cadr point))
              (setq y (md:draw-legend x y text-height))
              (setq y (- y (* text-height 3.0)))
              (foreach table tables
                (setq color
                  (cond
                    ((equal (car table) "TRANSPORTADORES") 30)
                    ((equal (car table) "COMANDO") 5)
                    ((equal (car table) "RAMAL_DE_ALIMENTACAO") 3)
                    (T 8)
                  )
                )
                (setq title
                  (cond
                    ((equal (car table) "TRANSPORTADORES") "TRANSPORTADORES")
                    ((equal (car table) "COMANDO") "COMANDO")
                    ((equal (car table) "RAMAL_DE_ALIMENTACAO")
                      (strcat "RAMAL DE ALIMENTA" (chr 199) (chr 195) "O")
                    )
                    (T (car table))
                  )
                )
                (setq y
                  (md:draw-table
                    (strcat "RELAT" (chr 211) "RIO DE LEGENDAS - " title)
                    (cadr table)
                    (caddr table)
                    x
                    y
                    text-height
                    color
                  )
                )
                (setq y (- y (* text-height 2.0)))
              )
              (command "_.REGEN")
              (prompt "\nTabelas inseridas na camada DESCIDAS_AUTO. Salve o DWG como uma nova versao.")
            )
          )
        )
      )
    )
  )
  (princ)
)
