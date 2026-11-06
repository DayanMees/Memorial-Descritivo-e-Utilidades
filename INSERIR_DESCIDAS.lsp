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

(defun md:ensure-style ()
  (if (null (tblsearch "STYLE" "DESCIDAS_CALIBRI"))
    (entmake
      '(
        (0 . "STYLE")
        (100 . "AcDbSymbolTableRecord")
        (100 . "AcDbTextStyleTableRecord")
        (2 . "DESCIDAS_CALIBRI")
        (70 . 0)
        (40 . 0.0)
        (41 . 1.0)
        (50 . 0.0)
        (71 . 0)
        (42 . 2.5)
        (3 . "calibri.ttf")
        (4 . "")
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
          (list (list (cons 1 value) (cons 40 height) (cons 7 "DESCIDAS_CALIBRI")))
        )
      )
      (if (or (null box) (vl-catch-all-error-p box))
        (* height 0.6 (strlen value))
        (- (caadr box) (caar box))
      )
    )
  )
)

(defun md:widths (headers rows height base scale / widths index maximum row width)
  (setq widths nil)
  (setq index 0)
  (repeat (length headers)
    (setq maximum (* 1.08 (md:text-width (nth index headers) height)))
    (foreach row rows
      (setq width (md:text-width (nth index row) height))
      (if (> width maximum)
        (setq maximum width)
      )
    )
    (setq widths
      (cons
        (max
          (* scale (if (nth index base) (nth index base) 4500.0))
          (+ maximum (* height 0.9))
        )
        widths
      )
    )
    (setq index (1+ index))
  )
  (reverse widths)
)

(defun md:apply-color (color spec)
  (if (listp spec)
    (vla-setrgb color (car spec) (cadr spec) (caddr spec))
    (vla-put-colorindex color spec)
  )
  color
)

(defun md:escape (value / result index character)
  (setq result "")
  (setq index 1)
  (while (<= index (strlen value))
    (setq character (substr value index 1))
    (setq result
      (strcat
        result
        (if (or (= character "{") (= character "}")) "\\" "")
        character
      )
    )
    (setq index (1+ index))
  )
  result
)

(defun md:cell (table color row column value height alignment bold text-color background)
  (if (and value (/= value ""))
    (vla-settext
      table
      row
      column
      (strcat "{\\fCalibri|b" (if bold "1" "0") "|i0;" (md:escape value) "}")
    )
  )
  (vla-setcellalignment table row column alignment)
  (vla-setcelltextheight table row column height)
  (vla-setcellcontentcolor table row column (md:apply-color color text-color))
  (if background
    (vla-setcellbackgroundcolor table row column (md:apply-color color background))
  )
)

(defun md:new-table (space x top rows columns row-height column-width / table)
  (setq table
    (vla-addtable
      space
      (vlax-3d-point (list x top 0.0))
      rows
      columns
      row-height
      column-width
    )
  )
  (vla-put-regeneratetablesuppressed table :vlax-true)
  (vla-put-layer table "DESCIDAS_AUTO")
  table
)

(defun md:merge-row (table row columns)
  (vl-catch-all-apply 'vla-mergecells (list table row row 0 (1- columns)))
)

(defun md:draw-table (space title subtitle headers rows x top height base category-color / scale widths table color columns index row-number value)
  (setq scale (/ height 250.0))
  (setq columns (length headers))
  (setq widths (md:widths headers rows height base scale))
  (setq table
    (md:new-table space x top (+ (length rows) 3) columns (* 660.0 scale) (car widths))
  )
  (setq color (vla-get-truecolor table))
  (setq index 0)
  (foreach value widths
    (vla-setcolumnwidth table index value)
    (setq index (1+ index))
  )
  (vla-setrowheight table 0 (* 750.0 scale))
  (vla-setrowheight table 1 (* 720.0 scale))
  (vla-setrowheight table 2 (* 720.0 scale))
  (md:merge-row table 0 columns)
  (md:merge-row table 1 columns)

  (md:cell table color 0 0 title (* 1.2 height) 5 T 7 nil)
  (md:cell table color 1 0 subtitle height 5 T '(0 0 0) '(242 242 242))
  (setq index 0)
  (foreach value headers
    (md:cell table color 2 index value height 5 T '(0 0 0) '(217 217 217))
    (setq index (1+ index))
  )

  (setq row-number 3)
  (foreach value rows
    (vla-setrowheight table row-number (* 660.0 scale))
    (setq index 0)
    (repeat columns
      (if (= index 0)
        (md:cell table color row-number index (nth index value) height 5 nil 7 category-color)
        (md:cell
          table color row-number index
          (if (and (nth index value) (/= (nth index value) ""))
            (strcat " " (nth index value))
            ""
          )
          height 4 nil 7 nil
        )
      )
      (setq index (1+ index))
    )
    (setq row-number (1+ row-number))
  )

  (vla-setgridcolor table 63 3 (md:apply-color color 7))
  (vla-setgridcolor table 63 4 (md:apply-color color 18))
  (vla-put-regeneratetablesuppressed table :vlax-false)
  (- top (vla-get-height table))
)

(defun md:draw-legend (space x top height / scale table color palette row-number entry)
  (setq scale (/ height 250.0))
  (setq table
    (md:new-table space x top 11 2 (* 585.0 scale) (* 44279.0 scale))
  )
  (setq color (vla-get-truecolor table))
  (vla-setcolumnwidth table 0 (* 1737.0 scale))
  (vla-setcolumnwidth table 1 (* 44279.0 scale))
  (vla-setrowheight table 0 (* 748.5 scale))
  (vla-setrowheight table 1 (* 645.0 scale))
  (vla-setrowheight table 2 (* 677.0 scale))
  (md:merge-row table 0 2)
  (md:merge-row table 1 2)

  (md:cell
    table color 0 0
    (strcat "LEGENDA RELAT" (chr 211) "RIO DE DESCIDAS")
    (* 474.0 scale) 5 T 7 nil
  )
  (md:cell
    table color 1 0
    "LISTA INFORMATIVA DE CORES E PONTOS DE DESCIDAS E PROCESSOS CORRESPONDENTES"
    (* 406.0 scale) 5 T 7 nil
  )
  (md:cell table color 2 0 "CORES" (* 406.0 scale) 5 T '(0 0 0) '(217 217 217))
  (md:cell
    table color 2 1
    (strcat "DESCRI" (chr 199) (chr 195) "O")
    (* 406.0 scale) 5 T '(0 0 0) '(217 217 217)
  )

  (setq palette
    (list
      (list 32 (strcat "PONTOS DE LIGA" (chr 199) (chr 195) "O DE MOTORES - TRANSPORTADORES"))
      (list 5 "PONTOS DE COMANDO")
      (list 6 (strcat "CABOS ETHERNET (COMUNICA" (chr 199) (chr 195) "O ENTRE EQUIPAMENTOS E PONTOS ETHERNET)"))
      (list 3 (strcat "ALIMENTA" (chr 199) (chr 195) "O DOS EQUIPAMENTOS"))
      (list '(130 130 130) "PONTOS DE TOMADA IDENTIFICADOS COM (T)")
      (list '(249 170 249) "PONTOS DE CABOS DE REDE ENTRE EQUIPAMENTO (CAT5E)")
      (list 4 "PONTOS DE CABOS DE COMANDO (MULTIVIAS) ENTRE EQUIPAMENTOS")
      (list nil "PONTOS DE ACIONAMENTOS RESERVAS")
    )
  )
  (setq row-number 3)
  (foreach entry palette
    (vla-setrowheight table row-number (* 585.0 scale))
    (md:cell table color row-number 0 "" (* 372.0 scale) 5 nil 7 (car entry))
    (md:cell table color row-number 1 (strcat " " (cadr entry)) (* 372.0 scale) 4 nil 7 nil)
    (setq row-number (1+ row-number))
  )

  (vla-setgridcolor table 63 7 (md:apply-color color 7))
  (vla-put-regeneratetablesuppressed table :vlax-false)
  (- top (vla-get-height table))
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
  (if (> drawing-height 0.0) (* drawing-height 0.0038) 2.5)
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

(defun md:current-space (/ document)
  (setq document (vla-get-activedocument (vlax-get-acad-object)))
  (if (and (= (getvar "TILEMODE") 0) (= (getvar "CVPORT") 1))
    (vla-get-paperspace document)
    (vla-get-modelspace document)
  )
)

(defun md:run (path text-height origin / tables x y table color subtitle base point space scale)
  (if path
    (progn
      (setq tables (md:read-tables path))
      (if (null tables)
        (prompt "\nNao foi possivel ler tabelas com dados no arquivo selecionado.")
        (if (<= text-height 0.0)
          (prompt "\nA altura do texto deve ser maior que zero.")
          (progn
            (md:ensure-layer)
            (md:ensure-style)
            (setq scale (/ text-height 250.0))
            (setq space (md:current-space))
            (setq point (trans origin 1 0))
            (setq x (car point))
            (setq y (cadr point))
            (setq y (md:draw-legend space x y text-height))
            (setq y (- y (* 1200.0 scale)))
            (foreach table tables
              (cond
                ((equal (car table) "TRANSPORTADORES")
                  (setq color 32)
                  (setq subtitle "TRANSPORTADORES")
                  (setq base '(4376.0 4925.0 4376.0 4925.0 4925.0 16473.0))
                )
                ((equal (car table) "COMANDO")
                  (setq color 5)
                  (setq subtitle "COMANDO")
                  (setq base '(3994.0 4997.0 3994.0 2990.0 4495.0 4495.0 15035.0))
                )
                ((equal (car table) "RAMAL_DE_ALIMENTACAO")
                  (setq color 3)
                  (setq subtitle (strcat "RAMAL DE ALIMENTA" (chr 199) (chr 195) "O"))
                  (setq base '(5329.0 4794.0 4258.0 4794.0 4794.0 16032.0))
                )
                (T
                  (setq color 8)
                  (setq subtitle (car table))
                  (setq base nil)
                )
              )
              (setq y
                (md:draw-table
                  space
                  (strcat "RELAT" (chr 211) "RIO DE LEGENDAS")
                  subtitle
                  (cadr table)
                  (caddr table)
                  x
                  y
                  text-height
                  base
                  color
                )
              )
              (setq y (- y (* 550.0 scale)))
            )
            (command "_.REGEN")
            (prompt "\nTabelas inseridas na camada DESCIDAS_AUTO. Salve o DWG como uma nova versao.")
          )
        )
      )
    )
  )
  (princ)
)
