#import "@preview/touying:0.6.1": *
#import themes.metropolis: *
#import "@preview/cades:0.3.1": qr-code

#let teal = rgb("#168C8C")
#let teal-light = rgb("#BFDCDC")
#let navy = rgb("#203642")
#let ink = rgb("#13262E")
#let muted = rgb("#5E7078")
#let paper = rgb("#F7FAF9")
#let green = rgb("#2F855A")
#let amber = rgb("#B7791F")
#let qr = qr-code(
            "https://nailatik.github.io/actl-shell-research/",
            width: 4.1cm,
            color: navy,
            background: paper,
          )

#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  footer: self => self.info.institution,
  config-info(
    title: [Исследование shell-режима для alteratorctl],
    subtitle: [Аналитика, архитектура и прототип],
    author: [Тугушев Наиль],
    date: datetime(
      year: 2026,
      month: 9,
      day: 2,
    ),
    institution: [actl-shell],
  ),
  config-colors(
    primary: teal,
    primary-light: teal-light,
    secondary: navy,
    neutral-lightest: paper,
    neutral-dark: muted,
    neutral-darkest: ink,
  ),
)

#set text(font: "Fira Sans")
#set strong(delta: 150)
#set par(leading: 0.72em)

#let terminal(body) = block(
  width: 100%,
  fill: ink,
  stroke: 0.8pt + teal,
  radius: 8pt,
  inset: 12pt,
)[
  #set text(font: "Fira Mono", size: 12.5pt, fill: white)
  #set par(leading: 0.62em)
  #body
]

#let prompt(body) = text(fill: teal-light, weight: "semibold", body)

#let card(title, body, accent: teal, fill: white) = block(
  width: 100%,
  fill: fill,
  stroke: 0.8pt + accent.lighten(42%),
  radius: 8pt,
  inset: 12pt,
)[
  #text(size: 15pt, weight: "semibold", fill: accent)[#title]
  #v(0.3em)
  #set text(size: 13.5pt, fill: ink)
  #body
]

#let note(body, accent: teal) = block(
  width: 100%,
  fill: accent.lighten(88%),
  stroke: (left: 3pt + accent),
  radius: 4pt,
  inset: (x: 12pt, y: 8pt),
)[
  #set text(size: 14pt, fill: ink)
  #body
]

#let chip(body) = box(
  fill: teal.lighten(88%),
  stroke: 0.7pt + teal.lighten(50%),
  radius: 10pt,
  inset: (x: 10pt, y: 5pt),
)[
  #text(size: 12pt, weight: "medium", fill: navy)[#body]
]

#title-slide()

= Зачем нужен actl-shell

== Одноразовый CLI решает одну задачу

#grid(
  columns: (1.2fr, 0.8fr),
  gutter: 1.2em,
  terminal[
    #prompt[\$] actl services status samba \
    #prompt[\$] actl services start samba \
    #prompt[\$] actl services status samba
  ],
  card([Что повторяется], [
    - запуск приложения
    - полный путь команды
    - выбор одного объекта
    - поиск нужных аргументов
  ], accent: amber),
)

#v(0.8em)

#note[
  Для одной известной команды, CI и внешнего shell-скрипта обычный `actl`
  остаётся правильным инструментом.
]

== Контекст вместо повторения полного пути

#grid(
  columns: (1.35fr, 0.65fr),
  gutter: 1em,
  terminal[
    #prompt[actl>] use packages \
    #prompt[actl:packages>] use apt \
    #prompt[actl:packages/apt>] search samba \
    #prompt[actl:packages/apt>] /systeminfo arch \
    x86_64 \
    #prompt[actl:packages/apt>] back \
    #prompt[actl:packages>] root \
    #prompt[actl>]
  ],
  card([Навигация], [
    `modules` \
    `ls` \
    `use <path>` \
    `back` \
    `root` \
    `pwd`
  ], accent: navy),
)

#v(0.6em)

#note[
  Относительная команда выполняется в текущем контексте. Путь с `/` всегда
  начинается от корня и не меняет выбранный контекст.
]

== Что подсказали существующие решения

#grid(
  columns: (1fr, 1fr),
  gutter: 1em,
  card([apt-shell], [
    Постоянная сессия, повторное использование загруженных данных и выполнение
    файлов тем же обработчиком команд.

    Общий `commit` не переносится: модули Alterator не образуют одну транзакцию.
  ]),
  card([bluetoothctl], [
    Активное меню ограничивает команды, `help` зависит от контекста, а отдельные
    команды получают динамическое автодополнение.

    Для actl-shell нужна более глубокая навигация с путём в prompt.
  ], accent: navy),
)

= Модель взаимодействия

== Одна задача становится одной сессией

#terminal[
  #prompt[actl>] use services \
  #prompt[actl:services>] use samba \
  #prompt[actl:services/samba>] status \
  stopped \
  #prompt[actl:services/samba>] start \
  #text(fill: green.lighten(35%))[Служба samba запущена] \
  #prompt[actl:services/samba>] status \
  running
]

#v(0.7em)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 0.7em,
  card([Меньше ввода], [Модуль и объект выбираются один раз.]),
  card([Проще исследовать], [`help` и Tab учитывают текущий контекст.]),
  card([Ошибки не завершают shell], [После сбоя пользователь получает следующий prompt.]),
)

== Автодополнение знает, где находится пользователь

#grid(
  columns: (1fr, 1fr),
  gutter: 1em,
  card([Статическое], [
    Модули, команды, подкоманды и параметры берутся из Command Catalog.

    #terminal[
      #prompt[actl:packages>] a#text(fill: amber.lighten(35%))[\<Tab\>] \
      apt
    ]
  ]),
  card([Динамическое], [
    Имена служб и других объектов запрашиваются через Backend и ненадолго
    сохраняются в кэше.

    #terminal[
      #prompt[actl:services>] status #text(fill: amber.lighten(35%))[\<Tab\>] \
      samba   sshd   winbind
    ]
  ], accent: navy),
)

#v(0.55em)

#note[
  Справка и автодополнение используют описания команд и структурированные данные.
]

== Преимущества REPL
#card([Интерактивная работа], [
  - `Up` и `Down` - история
  - `Ctrl+R` - поиск
  - редактирование строки
  - до 100 команд в истории
])

== История превращается в воспроизводимый сценарий

#terminal[
  #prompt[actl>] history \
  ...\
    4  use services\
    5  use samba\
    6  status\
    7  start\
    8  status\
  ...\
  #prompt[actl>] history save inspect.actl 4..8 \
  Сохранено команд: 5 \
  #prompt[actl>] script inspect.actl \
  Выполнить 5 команд? [y/N] y
]

#v(0.7em)

#grid(
  columns: (1fr, 1fr),
  gutter: 0.8em,
  card([`--stop`], [Остановить сценарий после первой ошибки.], accent: amber),
  card([`--continue`], [Продолжить и показать ошибки с именем файла и номером строки.], accent: green),
)

= Архитектура первой версии

== Разделение ответственности

#grid(
  columns: (1fr, 1fr),
  rows: (auto, auto),
  gutter: 0.8em,
  card([Command Catalog], [Описывает команды, аргументы, справку и источники автодополнения.]),
  card([Shell Context], [Хранит текущий путь и выбранный объект, но не опасные разрешения.], accent: navy),
  card([Backend], [Получает уже разрешённый запрос и не зависит от prompt или истории.], accent: navy),
  card([Shell Renderer], [Показывает подтверждение, промежуточный вывод, обработку ошибок и прерываний.]),
)

#v(0.7em)

#note[
  Временный Backend можно заменить адаптером общего ядра без изменения REPL и
  пользовательского синтаксиса.
]

== Как команда проходит через actl-shell

#align(center, block(
  width: 100%,
  fill: white,
  stroke: 0.8pt + teal-light,
  radius: 8pt,
  inset: 8pt,
)[
  #image("../src/images/actl-shell-architecture.png", width: 100%)
])

== Граница MVP

#let scope-card(title, body, accent: teal) = block(
  width: 100%,
  height: 8cm,
  fill: white,
  stroke: 0.8pt + accent.lighten(42%),
  radius: 8pt,
  inset: 12pt,
)[
  #text(size: 15pt, weight: "semibold", fill: accent)[#title]
  #v(0.3em)
  #set text(size: 13.5pt, fill: ink)
  #body
]

#grid(
  columns: (1fr, 1fr),
  gutter: 1em,
  align: top,
  scope-card([Входит в MVP], [
    #text(size: 12.5pt, weight: "medium", fill: muted)[Все восемь модулей actl]
    #v(0.45em)
    #grid(
      columns: (1fr, 1fr, 1fr, 1fr),
      column-gutter: 0.25em,
      row-gutter: 0.4em,
      align(center)[#chip[components]],
      align(center)[#chip[diag]],
      align(center)[#chip[editions]],
      align(center)[#chip[manager]],
      align(center)[#chip[packages]],
      align(center)[#chip[services]],
      align(center)[#chip[sources]],
      align(center)[#chip[systeminfo]],
    )
    #v(0.75em)
    - контекст и абсолютные команды
    - справка и автодополнение
    - история, `Ctrl+R` и сценарии `.actl`
    - подтверждения и обработка `Ctrl+C`
  ]),
  scope-card([После MVP], [
    - режим плана
    - типизированные результаты и переменные
    - повторное использование результатов команд
    - `watch` и фоновые задачи
    - транзакции там, где их поддерживает Backend
    - удалённое управление через remote
    - TUI и общее плагинное ядро
  ], accent: muted),
)

= Результат исследования

== actl и actl-shell не заменяют друг друга

#grid(
  columns: (1fr, 1fr),
  gutter: 1em,
  card([Обычный actl], [
    - одна известная операция
    - Bash, CI и запуск по расписанию
    - простой машинный вызов
    - новый процесс на каждую команду
  ], accent: navy),
  card([actl-shell], [
    - исследование незнакомого модуля
    - последовательность связанных действий
    - контекст, история и подсказки
    - одна постоянная сессия
  ]),
)

#v(0.8em)

#note[
  Переходить в shell стоит тогда, когда пользователь ещё выбирает следующую
  команду или несколько раз работает с одним объектом.
]

== Что уже можно показать

#grid(
  columns: (0.8fr, 1.2fr),
  gutter: 1em,
  card([Прототип], [
    - все восемь модулей
    - контекстный prompt
    - статическое и динамическое автодополнение
    - история на 100 команд
    - выполнение `.actl`
    - 14 автоматических тестов
  ]),
  terminal[
    #prompt[actl>] modules \
    #prompt[actl>] use services \
    #prompt[actl:services>] use samba \
    #prompt[actl:services/samba>] status \
    #prompt[actl:services/samba>] start \
    #prompt[actl:services/samba>] /systeminfo arch \
    #prompt[actl:services/samba>] script demo/service-cycle.actl
  ],
)

== Итоговое предложение

#align(center)[
  #block(width: 82%)[
    #align(left)[
      #text(size: 24pt, weight: "semibold", fill: navy)[
        Первая версия - отдельное Python-приложение
      ]

      #v(0.7em)
      #text(size: 16pt)[
        - только shell. TUI и общее ядро - после согласования;
        - восемь модулей actl;
        - контекстная навигация, справка и автодополнение;
        - редактирование строки, история и сценарии .actl;
        - подтверждения, промежуточный вывод, обработка ошибок и прерываний;
      ]

      #v(0.55em)
    ]
  ]
]

== Вопросы для согласования

+ История и поиск - относительно каталога или общая?
+ Кто формирует Command Catalog (к вопросу о ядре)?
+ Сценарии - оставить как есть или сделать в виде полноценного скрипта?
+ Откуда выполняются сценарии: из корня или текущего каталога?

#focus-slide(
  config: config-page(fill: paper),
)[
  #set text(fill: ink)
  #align(center)[
    #text(size: 31pt, weight: "bold", fill: navy)[Спасибо за внимание]
    #v(0.35em)
    #line(length: 2.3cm, stroke: 2pt + teal)
    #v(0.75em)
    #qr
    #v(0.45em)
    #text(size: 13pt, weight: "semibold", fill: navy)[
      Документация исследования
    ]
    #v(0.12em)
    #text(size: 10pt, fill: muted)[
      nailatik.github.io/actl-shell-research
    ]
  ]
]
