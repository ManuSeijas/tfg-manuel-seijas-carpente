extensions [csv]
globals [data initial-population]
breed [humats humat]

;;<summary>
;;  Variables características de los agentes individuales, incluyen demografía,
;;  variables de la arquitectura HUMAT, y otras que sirven para mejorar la implementación.
;;</summary>
humats-own[
  infected?
  inmune?

  ;; variables demográficas
  age
  gender
  type_of_home
  type_of_housing
  work_status
  essential_job
  net_income

  ;; número de ticks desde la última vez que se ha revisado la cura del agente
  removed-check-timer

  values-importance
  social-importance
  experiential-importance

  values-satisfaction-A
  values-satisfaction-B
  experiential-satisfaction-A
  experiential-satisfaction-B
  social-relation-satisfaction-A
  social-relation-satisfaction-B

  values-evaluation-A
  social-evaluation-A
  experiential-evaluation-A
  social-relation-evaluation-A

  values-evaluation-B
  social-evaluation-B
  experiential-evaluation-B
  social-relation-evaluation-B

  satisfaction-A
  satisfaction-B
  satisfaction

  ;; indica si la medida ha sido aceptada o no por el agente.
  measure-acceptance?

  dissonance-tolerance
  dissonance-A
  dissonance-B

  ;; si la fuerza de la disonancia es mayor a 0, habrá una disonancia.
  dissonance-strength

  ;; 1 si el agente tiene un dilema, 0 en caso contrario.
  experiential-dilemma?
  social-dilemma?
  values-dilemma?
  social-relation-dilemma?

  ;; medida de confianza en la red social del HUMAT
  trust

  ;; 1 Si el agente está realizando Inquire en este tick; 0 en caso contrario
  inquiring?

  ;; 1 Si el agente está realizando Signal en este tick; 0 en caso contrario
  signaling?
]

links-own[
  ;; 1 si ya se han preguntado entre ellos; 0 en caso contrario
  inquired?

  persuasion

  ;; 1 si ya se han hecho signal entre ellos; 0 en caso contrario
  signaled?

  gullibility

  ;; 1 si ambos extremos poseen la misma aceptación de la medida seleccionada; 0 en caso contrario
  same-ma?
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; SETUP PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all
  set initial-population 2035
  Make-Population
  ask n-of initial-infected humats [State-Infected]
  Make-Network
  Update-Social-Satisfaction
  ask humats [Update-Dissonances]
  ask humats [Decide-Acceptance]
  Update-Social-Satisfaction
  ask humats [Update-Dissonances]
  reset-ticks
end

;;<summary>
;;  Se encarga de generar los agentes, y asignarles los datos de la encuesta según se definieron.
;;  Además, calcula los valores iniciales de satisfacción de las necesidades y la aceptación de la medida de contención.
;;</summary>
to Make-Population
  set-default-shape humats "person"

  file-close-all

  if not file-exists? "data.csv" [user-message "No file!"]
  let data_csv csv:from-file "data.csv"
  set data_csv shuffle data_csv ; shuffle the lit of responses so random ones are taken
  let index 0

  repeat initial-population [
    set data (item index data_csv)
    set index (index + 1)
    create-humats 1 [
      set size 0.8
      set removed-check-timer 1
      State-Susceptible
      setxy (random-xcor * 0.95) (random-ycor * 0.95) ; visual reinforcement

      set trust random-float 1

      set gender item 1 data
      set age item 2 data
      set type_of_home item 3 data
      set type_of_housing item 4 data
      set work_status item 5 data
      set essential_job item 6 data
      set net_income item 7 data

      ;; set de las importancias de las necesidades
      set values-importance Normalized-Min-Max (mean (list (item 21 data) (item 22 data))) -1 1 0 1
      set social-importance Normalized-Min-Max (Random-Normal-Trunc 0.5 0.14 0 1) -1 1 0 1
      set experiential-importance Normalized-Min-Max (item 23 data) -1 1 0 1

      set values-satisfaction-A (item 20 data)
      set values-satisfaction-B 0 - values-satisfaction-A

      (ifelse
        measure = "total isolation" [
          set experiential-satisfaction-A (mean (list (item 8 data) (item 10 data) (item 11 data) (item 12 data) (item 13 data)))
          set experiential-satisfaction-B 0 - experiential-satisfaction-A

          set social-relation-satisfaction-A (mean (list (item 16 data) (item 17 data) (item 18 data)))
          set social-relation-satisfaction-B 0 - social-relation-satisfaction-A
        ]
        measure = "partial isolation" [
          set experiential-satisfaction-A (mean (list (item 9 data) (item 10 data) (item 11 data)))
          set experiential-satisfaction-B 0 - experiential-satisfaction-A

          set social-relation-satisfaction-A (mean (list (item 16 data) (item 17 data) (item 19 data)))
          set social-relation-satisfaction-B 0 - social-relation-satisfaction-A
        ]
      )

      ;; set de las evaluaciones iniciales
      set values-evaluation-A (values-satisfaction-A * values-importance)
      set values-evaluation-B (values-satisfaction-B * values-importance)
      set experiential-evaluation-A (experiential-satisfaction-A * experiential-importance)
      set experiential-evaluation-B (experiential-satisfaction-B * experiential-importance)
      set social-relation-evaluation-A (social-relation-satisfaction-A * social-importance)
      set social-relation-evaluation-B (social-relation-satisfaction-B * social-importance)

      ;; set satisfacción global inicial, así como la aceptación de la medida
      set satisfaction-A ((values-evaluation-A + experiential-evaluation-A + social-relation-evaluation-A) / 3)
      set satisfaction-B ((values-evaluation-B + experiential-evaluation-B + social-relation-evaluation-B) / 3)
      ifelse satisfaction-A >= satisfaction-B
      [set measure-acceptance? true] ;; A = Aceptación de la medida de contención
      [set measure-acceptance? false] ;; B = No-Aceptación de la medida de contención

      ;; set del umbral de disonancia
      set dissonance-tolerance Random-Normal-Trunc 0.5 0.14 0 1
      set dissonance-strength 0

      ;; cálculo del nivel de confianza en la red social
      set trust Normalized-Min-Max (random-float 1) 0 1 0.5 1
    ]
  ]

  file-close
end

;;<summary>
;;  Crea la red social mediante un algoritmo de Small-Worlds.
;;</summary>
to Make-Network
  let n 0

  while [ n < count humats ] [
    make-i-edges n 1
    make-i-edges n 2
    make-i-edges n 3
    make-i-edges n 4
    set n n + 1
  ]

  ask links [
    if (random-float 1) < 0.2 [ ; re-wiring probability
      ask end1 [
        create-link-with one-of other humats with [not link-neighbor? myself]
      ]
      die
    ]
  ]

  ask links [hide-link]
end

;;<summary>
;;  Conecta dos nodos.
;;</summary>
to make-edge [node-A node-B this-shape]
  ask node-A [
    create-link-with node-B  [
      set shape this-shape
    ]
  ]
end

;;<summary>
;;  Encapsulamiento para generar conexiones entre nodos, para evitar repetición en Make-Network.
;;</summary>
to make-i-edges [n i]
  make-edge humat n
            humat ((n + i) mod count humats)
            "default"
end

;;;;;;;;;;;;;;;;;;;;;;;;
;;; STATE PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

;;<summary>
;;  Pasa el estado del agente a "susceptible".
;;</summary>
to State-Susceptible
  set infected? false
  set inmune? false
  set color green + 1
end

;;<summary>
;;  Pasa el estado del agente a "infectado".
;;</summary>
to State-Infected
  set infected? true
  set inmune? false
  set color red
end

;;<summary>
;;  Pasa el estado del agente a "inmune".
;;</summary>
to State-Inmune
  set infected? false
  set inmune? true
  set color yellow
end

;;<summary>
;;  Elimina al agente de la simulación, lo que le hace pasar al estado de defunción.
;;</summary>
to State-Dead
  die
end

;;;;;;;;;;;;;;;;;;;;;;;;;
;;; UPDATE PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

;;<summary>
;;  Actualización de la satisfacción social, en función de la red social del agente y de sus opiniones.
;;  Itera sobre la red social del agente, buscando similaritudes a nivel social (misma aceptación de la medida).
;;</summary>
to Update-Social-Satisfaction
  ask humats [
    let similar 0
    let dissimilar 0
    let net sort [other-end] of my-out-links

    ;; Número de agentes en la red inmedianta (links que salen del agente que ejecuta la actualización).
    let mutuals (count my-out-links)

    if mutuals != 0
    [
      foreach net
      [mutual ->
        ifelse [measure-acceptance?] of mutual = measure-acceptance?
        [set similar (similar + 1)]
        [set dissimilar (dissimilar + 1)]
      ]

      let social-satisfaction-A 0
      let social-satisfaction-B 0

      ifelse measure-acceptance?
      [
        set social-satisfaction-A Normalized-Min-Max (similar / mutuals) 0 1 -1 1
        set social-satisfaction-B Normalized-Min-Max (dissimilar / mutuals) 0 1 -1 1
      ]
      [
        set social-satisfaction-A Normalized-Min-Max (dissimilar / mutuals) 0 1 -1 1
        set social-satisfaction-B Normalized-Min-Max (similar / mutuals) 0 1 -1 1
      ]

      set social-evaluation-A (social-importance * social-satisfaction-A)
      set social-evaluation-B (social-importance * social-satisfaction-B)

      set satisfaction-A (experiential-evaluation-A + social-evaluation-A + values-evaluation-A + social-relation-evaluation-A) / 4
      set satisfaction-B (experiential-evaluation-B + social-evaluation-B + values-evaluation-B + social-relation-evaluation-B) / 4
    ]
  ]
end

;;<summary>
;;  Actualización de las disonancias del agente. Suma los valores de satisfacción e insatisfacción para cada alternativa de comportamiento,
;;  y se encarga de calcular el valor de disonancia y su peso, para después buscar los dilemas existentes en el agente.
;;</summary>
to Update-Dissonances
  set experiential-dilemma? 0
  set social-dilemma? 0
  set values-dilemma? 0
  set social-relation-dilemma? 0

  ifelse measure-acceptance? [
    let evaluation-list-A (list social-evaluation-A experiential-evaluation-A values-evaluation-A social-relation-evaluation-A)

    ;; suma de evaluaciones positivas (satisfactorias) y negativas (insatisfactorias) para cada alternativa de comportamiento
    let dissatisfying-A Dissatisfying-Status-BA evaluation-list-A
    let satisfying-A Satisfying-Status-BA evaluation-list-A

    ;; valor de disonancia
    set dissonance-A Dissonance-Status-BA satisfying-A dissatisfying-A

    ;; peso de la disonancia, si es mayor que 0, esa necesidad evocará una redudcción de la disonancia provocada
    let dissonance-strength-A (dissonance-A - dissonance-tolerance) / (1 - dissonance-tolerance)
    if dissonance-strength-A < 0 [set dissonance-strength-A 0]
    set dissonance-strength dissonance-strength-A

    if (experiential-evaluation-A > 0 and social-evaluation-A < 0 and values-evaluation-A < 0 and social-relation-evaluation-A < 0)  or
    (experiential-evaluation-A < 0 and social-evaluation-A > 0 and values-evaluation-A > 0 and social-relation-evaluation-A > 0)
    [set experiential-dilemma? 1]
    if (social-evaluation-A > 0 and experiential-evaluation-A < 0 and values-evaluation-A < 0 and social-relation-evaluation-A < 0)  or
    (social-evaluation-A < 0 and experiential-evaluation-A > 0 and values-evaluation-A > 0 and social-relation-evaluation-A > 0)
    [set social-dilemma? 1]
    if (values-evaluation-A > 0 and experiential-evaluation-A < 0 and social-evaluation-A < 0 and social-relation-evaluation-A < 0)  or
    (values-evaluation-A < 0 and experiential-evaluation-A > 0 and social-evaluation-A > 0 and social-relation-evaluation-A > 0)
    [set values-dilemma? 1]
    if (social-relation-evaluation-A > 0 and social-evaluation-A < 0 and experiential-evaluation-A < 0 and values-evaluation-A < 0) or
    (social-relation-evaluation-A < 0 and social-evaluation-A > 0 and experiential-evaluation-A > 0 and values-evaluation-A > 0)
    [set social-relation-dilemma? 1]
  ]
  [
    let evaluation-list-B (list social-evaluation-B experiential-evaluation-B values-evaluation-B social-relation-evaluation-B)

    let dissatisfying-B Dissatisfying-Status-BA evaluation-list-B
    let satisfying-B Satisfying-Status-BA evaluation-list-B

    set dissonance-B Dissonance-Status-BA satisfying-B dissatisfying-B

    let dissonance-strength-B (dissonance-B - dissonance-tolerance) / (1 - dissonance-tolerance)
    if dissonance-strength-B < 0 [set dissonance-strength-B 0]

    set dissonance-strength dissonance-strength-B

    if (experiential-evaluation-B > 0.2 and social-evaluation-B <= 0.2 and values-evaluation-B < 0 and social-relation-evaluation-B < 0)  or
    (experiential-evaluation-B < 0 and social-evaluation-B > 0 and values-evaluation-B > 0 and social-relation-evaluation-B > 0)
    [set experiential-dilemma? 1]
    if (social-evaluation-B > 0 and experiential-evaluation-B < 0 and values-evaluation-B < 0 and social-relation-evaluation-B < 0)  or
    (social-evaluation-B < 0 and experiential-evaluation-B > 0 and values-evaluation-B > 0 and social-relation-evaluation-B > 0)
    [set social-dilemma? 1]
    if (values-evaluation-B > 0 and experiential-evaluation-B < 0 and social-evaluation-B < 0 and social-relation-evaluation-B < 0)  or
    (values-evaluation-B < 0 and experiential-evaluation-B > 0 and social-evaluation-B > 0 and social-relation-evaluation-B > 0)
    [set values-dilemma? 1]
    if (social-relation-evaluation-B > 0 and social-evaluation-B < 0 and experiential-evaluation-B < 0 and values-evaluation-B < 0) or
    (social-relation-evaluation-B < 0 and social-evaluation-B > 0 and experiential-evaluation-B > 0 and values-evaluation-B > 0)
    [set social-relation-dilemma? 1]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DECIDE PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

;;<summary>
;;  Preferencia por la alternativa más satisfactoria, si la similaridad es menor al 10% del rango teórico (0.2 <-1; 1>), se pasa al siguiente nivel.
;;</summary>
to Decide-Acceptance
  (ifelse Further-Comparison-Needed? satisfaction-A satisfaction-B 2 [Compare-Dissonances]
    [ifelse satisfaction-A > satisfaction-B
      [set measure-acceptance? true set satisfaction satisfaction-A]
      [set measure-acceptance? false set satisfaction satisfaction-B]
    ]
  )
end

;;<summary>
;;  Preferencia por la alternativa que genere menos disonancias, si la similaridad es menor al 10% del rango teórico (0.1 <0; 1>), se pasa al siguiente nivel.
;;</summary>
to Compare-Dissonances
  (ifelse Further-Comparison-Needed? dissonance-A dissonance-B 1 [Compare-Experiential-Needs]
   [ifelse dissonance-A < dissonance-B
      [set measure-acceptance? true set satisfaction satisfaction-A]
      [set measure-acceptance? false set satisfaction satisfaction-B]
   ]
  )
end

;;<summary>
;;  Preferencia por la alternativa que genere más satisfacción en la necesidad experiencial,
;;  si la similaridad es menor al 10% del rango teórico (0.2 <-1; 1>), se pasa al siguiente nivel.
;;</summary>
to Compare-Experiential-Needs
  (ifelse Further-Comparison-Needed?  experiential-evaluation-A  experiential-evaluation-B 2 [Choose-Randomly]
   [ifelse  experiential-evaluation-A > experiential-evaluation-B
      [set measure-acceptance? true set satisfaction satisfaction-A]
      [set measure-acceptance? false set satisfaction satisfaction-B]
   ]
  )
end

;;<summary>
;;  Selección alteatoria.
;;</summary>
to Choose-Randomly
set measure-acceptance? one-of (list true false)
ifelse measure-acceptance?
  [set satisfaction satisfaction-A]
  [set satisfaction satisfaction-B]
end

;;;;;;;;;;;;;;;;;;;;;
;;; GO PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;
to go
  Inquire
  Signal

  ;; si no hay más infectados, la simulación puede finalizar
  if all? humats [not infected?] [stop]

  ;; control del recuperación (muerte/inmunidad) del virus
  ask humats with [infected?]
  [
    set removed-check-timer (removed-check-timer + 1)
    if removed-check-timer >= removed-check-frequency [set removed-check-timer 0]
  ]

  Update-Removed

  ;; expansión dependiendo de la medida tomada
  if measure = "no measure" [No-Measure]
  if measure = "total isolation" [Partial-Isolation 0.02] ;; 2% de tener un contacto aunque se cumpla la medida
  if measure = "partial isolation" [Partial-Isolation 0.2] ;; 20% de tener un contacto aunque se cumpla la medida

  tick
end

;;<summary>
;;  Cuando un agente tiene disonancias o un dilema experiencial o de valores, intenta reducirlo a través de su red social (preguntando opiniones).
;;</summary>
to Inquire
  ask humats [
    set inquiring? 0
    let mutuals count my-out-links
    if dissonance-strength > 0 and (values-dilemma? = 1 or experiential-dilemma? = 1 or social-relation-dilemma? = 1 and mutuals > 0) [
      set inquiring? 1
      let sorted-link-list Sort-List-Inquiring my-out-links
      let inquired-humat [other-end] of First sorted-link-list

      let inquired-humat-experiential-evaluation-A [experiential-evaluation-A] of inquired-humat
      let inquired-humat-values-evaluation-A [values-evaluation-A] of inquired-humat
      let inquired-humat-experiential-evaluation-B [experiential-evaluation-B] of inquired-humat
      let inquired-humat-values-evaluation-B [values-evaluation-B] of inquired-humat
      let inquired-humat-social-relation-evaluation-A [social-relation-evaluation-A] of inquired-humat
      let inquired-humat-social-relation-evaluation-B [social-relation-evaluation-B] of inquired-humat

      let inquired-humat-experiential-importance [experiential-importance] of inquired-humat
      let inquired-humat-values-importance [values-importance] of inquired-humat
      let inquired-humat-social-importance [social-importance] of inquired-humat

      ;; calcula similaridades para la aceptación de la medida
      let similarity-experiential-importance-A Need-Similarity experiential-evaluation-A inquired-humat-experiential-evaluation-A experiential-importance inquired-humat-experiential-importance
      let similarity-values-importance-A Need-Similarity values-evaluation-A inquired-humat-values-evaluation-A values-importance inquired-humat-values-importance
      let similarity-social-importance-A Need-Similarity social-relation-evaluation-A inquired-humat-social-relation-evaluation-A social-importance inquired-humat-social-importance

      ;; calcula similaridades para la no aceptación de la medida
      let similarity-experiential-importance-B Need-Similarity experiential-evaluation-B inquired-humat-experiential-evaluation-B experiential-importance inquired-humat-experiential-importance
      let similarity-values-importance-B Need-Similarity values-evaluation-B inquired-humat-values-evaluation-B values-importance inquired-humat-values-importance
      let similarity-social-importance-B Need-Similarity social-relation-evaluation-B inquired-humat-social-relation-evaluation-B social-importance inquired-humat-social-importance

      ;; calcula persuasiones
      let persuasion-experiential-A (similarity-experiential-importance-A * trust)
      let persuasion-values-A (similarity-values-importance-A * trust)
      let persuasion-experiential-B (similarity-experiential-importance-B * trust)
      let persuasion-values-B (similarity-values-importance-B * trust)
      let persuasion-social-relation-A (similarity-social-importance-A * trust)
      let persuasion-social-relation-B (similarity-social-importance-B * trust)

      ;; actualización de las satisfacciones
      set experiential-satisfaction-A New-Need-Satisfaction experiential-satisfaction-A persuasion-experiential-A [experiential-satisfaction-A] of inquired-humat
      set experiential-satisfaction-B New-Need-Satisfaction experiential-satisfaction-B persuasion-experiential-B [experiential-satisfaction-B] of inquired-humat
      set values-satisfaction-A New-Need-Satisfaction values-satisfaction-A persuasion-values-A [values-satisfaction-A] of inquired-humat
      set values-satisfaction-B New-Need-Satisfaction values-satisfaction-B persuasion-values-B [values-satisfaction-B] of inquired-humat
      set social-relation-satisfaction-A New-Need-Satisfaction social-relation-satisfaction-A persuasion-social-relation-A [social-relation-satisfaction-A] of inquired-humat
      set social-relation-satisfaction-B New-Need-Satisfaction social-relation-satisfaction-B persuasion-social-relation-B [social-relation-satisfaction-B] of inquired-humat

      Update-Evaluations
      Update-Dissonances
      Decide-Acceptance
      Update-Evaluations
      Update-Dissonances

      ;; set la persuasion existente en la conexión entre ambos agentes como la suma de todas las persuasiones calculadas
      ask First sorted-link-list [
        set persuasion persuasion-experiential-A + persuasion-values-A + persuasion-social-relation-A + persuasion-experiential-B + persuasion-values-B + persuasion-social-relation-B
        ifelse [measure-acceptance?] of other-end = [measure-acceptance?] of myself
        [set same-ma? 1]
        [set same-ma? 0]
        set inquired? 1
      ]

      ;; actualización de los valores de las conexiones
      ask inquired-humat[
        foreach sort my-out-links [ dir-link ->
          if [who] of [other-end] of dir-link = [who] of myself [
            ask dir-link [
              ifelse [measure-acceptance?] of other-end = [measure-acceptance?] of myself
              [set same-ma? 1]
              [set same-ma? 0]
            ]
          ]
        ]
      ]
    ]
  ]
end

;;<summary>
;;  Cuando un agente tiene disonancias y un dilema social, intenta reducir la disonancia convenciendo a otros dentro de su red social.
;;</summary>
to Signal
  ask humats [
    set signaling? 0
    let mutuals count my-out-links
    if dissonance-strength > 0 and social-dilemma? = 1 and mutuals > 0  [
      set signaling? 1
      let sorted-link-list Sort-List-Signaling my-out-links
      let signaled-humat [other-end] of First sorted-link-list

      ask signaled-humat [
        ;; obtiene las evaluaciones de las necesidades del agente al que se comunica
        let signaling-humat-experiential-evaluation-A [experiential-evaluation-A] of myself
        let signaling-humat-values-evaluation-A [values-evaluation-A] of myself
        let signaling-humat-social-relation-evaluation-A [social-relation-evaluation-A] of myself
        let signaling-humat-experiential-evaluation-B [experiential-evaluation-B] of myself
        let signaling-humat-values-evaluation-B [values-evaluation-B] of myself
        let signaling-humat-social-relation-evaluation-B [social-relation-evaluation-B] of myself

        ;; obtiene las importancias del agente al que se comunica
        let signaling-humat-experiential-importance [experiential-importance] of myself
        let signaling-humat-values-importance [values-importance] of myself
        let signaling-humat-social-importance [social-importance] of myself

        ;; calcula similaridades para la aceptación de la medida
        let similarity-experiential-importance-A Need-Similarity experiential-evaluation-A signaling-humat-experiential-evaluation-A experiential-importance signaling-humat-experiential-importance
        let similarity-values-importance-A Need-Similarity values-evaluation-A signaling-humat-values-evaluation-A values-importance signaling-humat-values-importance
        let similarity-social-relation-importance-A Need-Similarity social-relation-evaluation-A signaling-humat-social-relation-evaluation-A social-importance signaling-humat-social-importance

        ;; calcula similaridades para la no aceptación de la medida
        let similarity-experiential-importance-B Need-Similarity experiential-evaluation-B signaling-humat-experiential-evaluation-B experiential-importance signaling-humat-experiential-importance
        let similarity-values-importance-B Need-Similarity values-evaluation-B signaling-humat-values-evaluation-B values-importance signaling-humat-values-importance
        let similarity-social-relation-importance-B Need-Similarity social-relation-evaluation-B signaling-humat-social-relation-evaluation-B social-importance signaling-humat-social-importance

        ;; calcula las persuasiones pertinentes
        let persuasion-experiential-A (similarity-experiential-importance-A * trust)
        let persuasion-values-A (similarity-values-importance-A * trust)
        let persuasion-social-relation-A (similarity-social-relation-importance-A * trust)
        let persuasion-experiential-B (similarity-experiential-importance-B * trust)
        let persuasion-values-B (similarity-values-importance-B * trust)
        let persuasion-social-relation-B (similarity-social-relation-importance-B * trust)

        ;; actualización de las nuevas satisfacciones
        set experiential-satisfaction-A New-Need-Satisfaction experiential-satisfaction-A persuasion-experiential-A [experiential-satisfaction-A] of myself
        set values-satisfaction-A New-Need-Satisfaction values-satisfaction-A persuasion-values-A [values-satisfaction-A] of myself
        set social-relation-satisfaction-A New-Need-Satisfaction social-relation-satisfaction-A persuasion-social-relation-A [social-relation-satisfaction-A] of myself
        set experiential-satisfaction-B New-Need-Satisfaction experiential-satisfaction-B persuasion-experiential-B [experiential-satisfaction-B] of myself
        set values-satisfaction-B New-Need-Satisfaction values-satisfaction-B persuasion-values-B [persuasion-values-B] of myself
        set social-relation-satisfaction-B New-Need-Satisfaction social-relation-satisfaction-B persuasion-social-relation-B [social-relation-satisfaction-B] of myself

        Update-Evaluations
        Update-Dissonances
        Decide-Acceptance
        Update-Evaluations
        Update-Dissonances

        ;; actualización de los valores de las conexiones entre los agentes que se han comunicado
        let link-list sort my-out-links
        let reverse-link 0
        foreach link-list [link-in-list ->
          if [who] of [other-end] of link-in-list = [who] of myself [
            set reverse-link link-in-list
          ]
        ]

        ask reverse-link [
          ifelse [measure-acceptance?] of other-end = [measure-acceptance?] of myself
          [set same-ma? 1]
          [set same-ma? 0]
        ]

        ask First [sorted-link-list] of myself [
          set gullibility persuasion-experiential-A + persuasion-values-A + persuasion-social-relation-A + persuasion-experiential-B + persuasion-values-B + persuasion-social-relation-B
          ifelse [measure-acceptance?] of other-end = [measure-acceptance?] of myself
          [set same-ma? 1]
          [set same-ma? 0]
          set inquired? 1
        ]
      ]
    ]
  ]
end

;;<summary>
;;  Actualización de las evaluaciones de un agente, dependiendo de la selección de alternativas de la red social.
;;</summary>
to Update-Evaluations
  set experiential-evaluation-A experiential-importance * experiential-satisfaction-A
  set values-evaluation-A values-importance * values-satisfaction-A
  set social-relation-evaluation-A social-importance * social-relation-satisfaction-A

  set experiential-evaluation-B experiential-importance * experiential-satisfaction-B
  set values-evaluation-B values-importance * values-satisfaction-B
  set social-relation-evaluation-A social-importance * social-relation-satisfaction-B

  let similar 0
  let dissimilar 0
  let node-list sort [other-end] of my-out-links
  foreach node-list [ agent ->
    ifelse [measure-acceptance?] of agent = measure-acceptance?
    [set similar (similar + 1)]
    [set dissimilar (dissimilar + 1)]
  ]

  let mutuals count my-out-links

  let social-satisfaction-A 0
  let social-satisfaction-B 0

  ifelse measure-acceptance?
  [
    set social-satisfaction-A Normalized-Min-Max (similar / mutuals) 0 1 -1 1
    set social-satisfaction-B Normalized-Min-Max (dissimilar / mutuals) 0 1 -1 1
  ]
  [
    set social-satisfaction-A Normalized-Min-Max (dissimilar / mutuals) 0 1 -1 1
    set social-satisfaction-B Normalized-Min-Max (similar / mutuals) 0 1 -1 1
  ]

  set social-evaluation-A (social-importance * social-satisfaction-A)
  set social-evaluation-B (social-importance * social-satisfaction-B)

  set satisfaction-A (experiential-evaluation-A + social-evaluation-A + values-evaluation-A + social-relation-evaluation-A) / 4
  set satisfaction-B (experiential-evaluation-B + social-evaluation-B + values-evaluation-B + social-relation-evaluation-B) / 4

end

;;<summary>
;;  Función de expansión vírica en caso de que no se aplique ninguna medida de contención.
;;</summary>
to No-Measure
  ask humats
  [
    let i who
    repeat day-contacts
    [
      ifelse count link-neighbors > 0
      [
        ifelse (random-float 1) <= 0.3 ;; probabilidad 70% de tener contacto con alguien de la red antes que con cualquier otra persona
        [ask one-of humats [Spread i who]]
        [ask one-of link-neighbors [Spread i who]]
      ]
      [ask one-of humats [Spread i who]]
    ]
  ]
end

;;<summary>
;;  Función de expansión vírica en caso de que se aplique como medida de contención "partial-isolation" (confinamiento parcial).
;;; Aquellas personas que no cumplan las medidas podrán expandir el virus con total libertad, así como ser contagiados, mientras que
;;; las que si la cumplan, tendrán una pequeña posibilidad de contagiarse igualmente, debido al condicionamiento del estado.
;;</summary>
to Partial-Isolation [contact-prob]
  ask humats with [not measure-acceptance?]
  [
    let i who
    repeat day-contacts [Check-Contact-Net i contact-prob]
  ]

  ask humats with [measure-acceptance?]
  [
    let i who
    repeat (floor (day-contacts * contact-prob)) [Check-Contact-Net i contact-prob]
  ]
end

;;<summary>
;;  Se encarga de comprobar si el contacto se produce dentro de la red social del agente o con alguien desconocido.
;;</summary>
to Check-Contact-Net [i contact-prob]
  ifelse count link-neighbors > 0
  [
    ifelse (random-float 1) <= 0.3
    [ask one-of humats [Check-Acceptance-Spread i contact-prob]]
    [ask one-of link-neighbors [Check-Acceptance-Spread i contact-prob]]
  ]
  [ask one-of humats [Check-Acceptance-Spread i contact-prob]]
end

;;<summary>
;;  Se comprueba si el individuo con el que se tiene contacto cumle las medidas de contención, teniendo en cuenta
;;  que si se cumplen las normas, aunque tengas un contacto es más dificil transmitir la enfermedad.
;;</summary>
to Check-Acceptance-Spread [i contact-prob]
  ifelse measure-acceptance?
  [if (random-float 1) <= contact-prob [Spread i who]]
  [Spread i who]
end

;;<summary>
;;  Función de expansión encapsulada, que deriva en dos casos, si el agente es infectado o no.
;;</summary>
to Spread [i j]
  ask humat i
  [
    ifelse infected?
    [ask humat j [Spread-S]]
    [if not inmune? [
      ask humat j [Spread-I i]
    ]]
  ]
end

;;<summary>
;;  Función de expansión vírica en caso de que el agente esté infectado.
;;</summary>
to Spread-S
  if not infected? and not inmune?
  [
    if (random-float 1) <= contagion-probability [State-Infected]
  ]
end

;;<summary>
;;  Función de expansión vírica en caso de que el agente sea susceptible.
;;</summary>
to Spread-I [i]
  if infected?
  [
    if (random-float 1) <= contagion-probability [ask humat i [State-Infected]]
  ]
end

;;<summary>
;;  Se encarga de actualizar los agentes que llegan a estado inmune o muerto, eliminandolos de la simulación en este último caso,
;; además de controlar a los que se curan de la enfermedad.
;;</summary>
to Update-Removed
  ask humats with [infected? and removed-check-timer = 0] [
    ifelse (random-float 1) <= mortality-risk
    [State-Dead]
    [
      ifelse (random-float 1) <= removed-probability
      [State-Inmune]
      [State-Susceptible]
    ]
  ]
end


;;;;;;;;;;;;;;;;;
;;; Reporters ;;;
;;;;;;;;;;;;;;;;;

;;<summary>
;;  Se encarga de normalizar un valor entre un rango nuevo de valores.
;;</summary>
to-report Normalized-Min-Max [tonormalize min-old max-old min-new max-new]
  report min-new + (((tonormalize - min-old) * (max-new - min-new)) / (max-old - min-old))
end

;;<summary>
;;  Se encarga de generar un valor "aleatorio" siguiendo una distribución normal.
;;</summary>
to-report Random-Normal-Trunc [mid dev mmin mmax]
  let result random-normal mid dev
  if result < mmin or result > mmax [
    report Random-Normal-Trunc mid dev mmin mmax
  ]
  report result
end

;;<summary>
;;  Dada una lista con todas las evaluaciones para una alternativa de comportamiento,
;;  devuelve la suma de todas las evaluaciones menores que 0 para esa alternativa.
;;</summary>
to-report Dissatisfying-Status-BA [evaluation-list-BA]
  let dissatisfying-list-BA filter [i -> i < 0] evaluation-list-BA
  let dissatisfying-stat-BA abs sum dissatisfying-list-BA
  report dissatisfying-stat-BA
end

;;<summary>
;;  Dada una lista con todas las evaluaciones para una alternativa de comportamiento,
;;  devuelve la suma de todas las evaluaciones mayores que 0 para esa alternativa.
;;</summary>
to-report Satisfying-Status-BA [evaluation-list-BA]
 let satisfying-list-BA filter [i -> i > 0] evaluation-list-BA
 let satisfying-stat-BA sum satisfying-list-BA
 report satisfying-stat-BA
end

;;<summary>
;;  Devuelve el valor de disonancia para una determinada alternativa de comportamiento, dados los valores
;;  de satisfacción e insatisfacción con dicha alternativa.
;;</summary>
to-report Dissonance-Status-BA [satisfying dissatisfying]
  let dissonant min (list satisfying dissatisfying)
  let consonant max (list satisfying dissatisfying)
  let dissonance 0
  ifelse (dissonant + consonant = 0)
  [set dissonance (2 * dissonant)]
  [set dissonance (2 * dissonant)/(dissonant + consonant)]
  report dissonance
end

;;<summary>
;;  Devuelve 1 si la diferencia entre ambas dimensiones dadas es menor al 10% que el rango teórico proporcionado.
;;  Devuelve 0 en caso contrario.
;;</summary>
to-report Further-Comparison-Needed? [comparison-dimension-A comparison-dimension-B theoretical-range]
  let value 0
  ifelse (comparison-dimension-A > comparison-dimension-B - 0.1 * theoretical-range) and (comparison-dimension-A < comparison-dimension-B + 0.1 * theoretical-range) [set value true] [set value false]
  report value
end

;;<summary>
;;  Devuelve una lista de links ordenada:
;;    (1) de forma ascendente por inquired? (a los que no se les haya preguntado primero),
;;    (2) de forma descendiente por same-MA? (misma aceptación primero), y
;;    (3) de forma descendiente por persuasion (una persuasion fuerte irá primero).
;;</summary>
to-report Sort-List-Inquiring [link-list]
  let sorted-link-list sort-by [[link1 link2] -> [persuasion] of link1 > [persuasion] of link2]  link-list ;(3) descendingly by persuasion (strongest persuasion first),
  set sorted-link-list sort-by [[link1 link2] -> [same-ma?] of link1 > [same-ma?] of link2]  sorted-link-list ;(2) descendingly by same-BA? (same behaviour first),
  set sorted-link-list sort-by [[link1 link2] -> [inquired?] of link1 < [inquired?] of link2]  sorted-link-list ;(1) ascendingly by inquired? (not inquired first).
  report sorted-link-list
end

;;<summary>
;;  Devuelve una lista de links ordenada:
;;    (1) de forma ascendente por signaled? (a los que no se les haña señalizado ya primero),
;;    (2) de forma descendiente por same-MA? (primero aquellos que tengan una aceptación diferente), y
;;    (3) de forma descendiente por guilibility (primero los más "credulos", los más faciles de persuadir).
;;</summary>
to-report Sort-List-Signaling [link-list]
  let sorted-link-list sort-by [[link1 link2] -> [gullibility] of link1 > [gullibility] of link2]  link-list
  set sorted-link-list sort-by [[link1 link2] -> [same-ma?] of link1 < [same-ma?] of link2]  sorted-link-list
  set sorted-link-list sort-by [[link1 link2] -> [signaled?] of link1 < [signaled?] of link2]  sorted-link-list
  report sorted-link-list
end

;;<summary>
;;  Pesado de la similaridad en las necesidades del "alter" (agente con el que se comunica), aplicable a cada grupo de necesidades para cada alternativa de comportamiento.
;;  Puede obtener un valor máximo de 0.4, ya que siempre va a pesar más la opinión del propio agente, por tanto
;;  si dos agentes valoran las mismas necesidades del mismo modo, el agente influenciador afectará al influenciado en un máximo, entonces, del 40%.
;;  Si dos agentes no encuentran las mismas importancias en sus necesidades, el agente influenciador no afectará al influenciado.
;;</summary>
to-report Need-Similarity [need-evaluation-BA-ego need-evaluation-BA-alter need-importance-ego need-importance-alter]
  ifelse
  (need-evaluation-BA-ego > 0 and need-evaluation-BA-alter > 0) or
  (need-evaluation-BA-ego < 0 and need-evaluation-BA-alter < 0)
  [report 0.4 * (1 - abs(need-importance-ego - need-importance-alter))]
  [report 0]
end

;;<summary>
;;  Cuando los humats son persuadidos por otros humats de su red social, pueden cambiar sus satisfacciones por alternativas de comportamiento
;;  al valor que es persuadido.
;;</summary>
to-report New-Need-Satisfaction [need-satisfaction-BA inquired-need-persuasion need-satisfaction-alter]
  report (1 - inquired-need-persuasion) * need-satisfaction-BA + inquired-need-persuasion * need-satisfaction-alter
end
@#$#@#$#@
GRAPHICS-WINDOW
434
30
1027
624
-1
-1
9.6
1
10
1
1
1
0
1
1
1
-30
30
-30
30
1
1
1
ticks
30.0

BUTTON
97
23
160
56
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
19
23
85
56
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
24
124
196
157
initial-infected
initial-infected
0
initial-population / 4
50.0
1
1
humats
HORIZONTAL

SLIDER
23
186
195
219
day-contacts
day-contacts
0
5
2.0
1
1
NIL
HORIZONTAL

SLIDER
25
234
197
267
contagion-probability
contagion-probability
0
1
0.05
0.05
1
NIL
HORIZONTAL

PLOT
1111
177
1623
555
Contagion evolution
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Susceptible" 1.0 0 -11085214 true "" "plot count humats with [not infected? and not inmune?]"
"Infected" 1.0 0 -955883 true "" "plot count humats with [infected?]"
"Inmune" 1.0 0 -9276814 true "" "plot count humats with [inmune?]"
"Dead" 1.0 0 -2674135 true "" "plot 2035 - count humats"

MONITOR
1192
81
1267
126
Susceptible
count humats with [not infected? and not inmune?]
17
1
11

MONITOR
1297
80
1357
125
Infected
count humats with [infected?]
17
1
11

MONITOR
1377
79
1438
124
Inmune
count humats with [inmune?]
17
1
11

SLIDER
23
342
204
375
removed-probability
removed-probability
0
1
0.1
0.1
1
NIL
HORIZONTAL

CHOOSER
24
460
260
505
measure
measure
"no measure" "total isolation" "partial isolation"
2

SLIDER
22
293
200
326
removed-check-frequency
removed-check-frequency
1
20
10.0
1
1
ticks
HORIZONTAL

SLIDER
24
391
204
424
mortality-risk
mortality-risk
0
1
0.05
0.01
1
NIL
HORIZONTAL

MONITOR
1464
79
1521
124
Dead
2035 - count humats
17
1
11

MONITOR
1543
78
1623
123
Acceptance
count humats with [measure-acceptance?]
17
1
11

MONITOR
1108
80
1165
125
Total
count humats
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
