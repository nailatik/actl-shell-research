# Контекст и навигация

## Краткое решение

В `actl-shell` контекст - это **текущая позиция в дереве команд**. От неё зависят:

- какие относительные команды доступны;
- что предлагает `Tab`;
- какую справку показывает `help`;
- что отображается в prompt;
- база относительного пути.

Абсолютная команда всегда начинается от корня:

```text
actl:packages/apt> list
actl:packages/apt> /services list
```

## Что именно называется контекстом

В сессии есть три разных вида состояния.

### 1. Командный контекст

Текущая позиция в пространстве команд:

```text
/
/packages
/packages/apt
```

Он определяет разрешение команд, `help` и автодополнение.

### 2. Выбранный объект

Например, выбранная служба:

```text
selected service = samba
```

Это состояние сессии, а не статический узел каталога.

### 3. Техническое состояние сессии

Сюда входят D-Bus соединение, proxy-объекты, кэш автодополнения, таймауты и текущая операция. Они не влияют на синтаксис и не входят в путь.

В `bluetoothctl` выбранное устройство или GATT-атрибут меняет prompt, а активное menu отдельно ограничивает команды. В `actl-shell` эти состояния тоже нельзя смешивать.

## Предлагаемая модель actl-shell

Команды представляются деревом:

```text
/
├── components
├── diag
├── editions
├── manager
├── packages
│   ├── apt
│   ├── rpm
│   └── repo
├── services
├── sources
└── systeminfo
```

В первой версии дерево содержит восемь модулей, команды `actl` и подмодули `packages`: `apt`, `rpm`, `repo`. Динамические объекты, например службы, не становятся статическими узлами.

Типов узлов два:

- `Group` - содержит дочерние группы и команды;
- `Command` - выполняется и описывает свои аргументы.

### Навигационные команды

```text
modules       показать корневые модули
ls            показать содержимое текущего контекста
use <path>    перейти в дочерний или указанный контекст
back          перейти на один уровень вверх
root          перейти в корень
pwd           показать текущий путь
help          показать содержимое текущего контекста
exit          завершить shell
```

Команды shell доступны в любом контексте.

При выбранном объекте первый `back` снимает выбор, второй поднимается к родителю.
`root` сразу возвращает в корневой контекст.

При относительном вызове команды shell имеют приоритет. Абсолютный путь всегда обозначает предметную команду: `/diag help` вызывает C-модуль, а `help` - контекстную справку shell.

### Относительные и абсолютные команды

```text
actl:packages/apt> list
```

означает:

```text
/packages/apt/list
```

```text
actl:packages/apt> /services list
```

выполняется от корня.

Parser приводит оба варианта к каноническому пути:

```python
("packages", "apt", "list")
("services", "list")
```

### Prompt

```text
actl>
actl:packages>
actl:packages/apt>
```

Prompt показывает командный контекст и выбранный объект:

```text
actl:services/samba>
```

`Session` хранит командный контекст и выбранный объект отдельно, но `pwd`
показывает их как единый логический путь:

```text
actl:services/samba> pwd
/services/samba
```

## Алгоритм контекстного автодополнения

Автодополнение получает строку и позицию курсора.

1. Разбирает только текст до курсора.
2. Определяет, является путь абсолютным или относительным.
3. Выбирает корневой или текущий узел дерева.
4. Проходит по уже введённым сегментам.
5. Если текущий узел - группа, предлагает дочерние узлы.
6. Если найдена команда, определяет позицию аргумента.
7. Вызывает completion-provider этого аргумента.

Completion команды:

```text
actl:packages> <Tab>
apt    rpm    repo    back    root    help    exit

actl:packages> a<Tab>
apt

actl:packages/apt> /serv<Tab>
/services
```

Completion аргумента:

```text
actl:services> status <Tab>
samba      Samba server
sshd       OpenSSH server
winbind    Samba Winbind

actl:services/samba> <Tab>
info    resources    status    configure    start    stop    back    root
```

## Реализация на prompt_toolkit

Для Python-версии подходит [`prompt_toolkit`](https://python-prompt-toolkit.readthedocs.io):

- `PromptSession` - интерактивный цикл, редактирование и история;
- `FileHistory` - постоянная история между запусками;
- `Completer` - интерфейс собственного автодополнение;
- `Completion` - отдельная подсказка с отображаемым описанием;
- `NestedCompleter` - быстрый прототип иерархического автодополнения;
- `ThreadedCompleter` или фоновый completion - защита интерфейса от медленных источников.

`NestedCompleter` годится для прототипа статического дерева. В настоящем Command Catalog должны быть все команды `actl`.

```python
NestedCompleter.from_nested_dict({
    "components": {"list", "info", "install", "remove"},
    "diag": {"list", "info", "report", "run", "help"},
    "editions": {"list", "info", "set", "get"},
    "manager": {"getobjects", "getifaces", "getsignals"},
    "packages": {
        "apt": {"info", "install", "list", "remove", "search", "update"},
        "rpm": {"files", "info", "install", "list", "remove"},
        "repo": {"add", "info", "list", "remove"},
    },
    "services": {
        "list": None,
        "status": None,
        "start": None,
        "stop": None,
    },
    "sources": {"list", "show", "enable", "disable", "check-sign"},
    "systeminfo": {"hostname", "arch", "kernel", "cpu", "memory"},
})
```

Для MVP нужен собственный `ActlCompleter`, который учитывает:

- `Session.context`;
- абсолютный префикс `/`;
- глобальные команды shell;
- позицию конкретного аргумента;
- динамические значения из backend;
- описания вариантов автодополнения;
- кэш и ошибки получения данных.

## Статические и динамические providers

Автодополнение аргумента описывается отдельно от handler:

```python
@dataclass
class ArgumentSpec:
    name: str
    required: bool
    completer: "CompletionProvider | None" = None
```

Статический provider:

```python
ChoiceProvider(["on", "off"])
```

Динамический provider:

```python
ServiceNameProvider(backend)
```

Команда:

```python
CommandNode(
    name="status",
    description="Show service status",
    handler=show_service_status,
    arguments=(
        ArgumentSpec("service", required=True,
                     completer=ServiceNameProvider()),
    ),
)
```

Это одна из точек замены: сначала provider обращается к временному backend, позднее - к общему ядру.

## Правила динамического автодополнения

Динамическое автодополнение не должно тормозить shell:

- Не обращаться к D-Bus на каждое нажатие клавиши.
- Запрашивать дорогие варианты по явному `Tab`.
- Кэшировать результаты на ограниченное время.
- Не считать пустой результат ошибкой всей сессии.
- Показывать ошибку кратко и позволять ввести значение вручную.
- Не выполнять изменяющие операции ради completion.
- Ограничивать время ожидания.
- Не допускать необработанных исключений из provider.

Полученный ранее список объектов берётся из кэша без нового D-Bus-вызова.

## Покрытие существующих модулей

Корневое дерево, `help`, parser и статическое автодополнение сразу охватывают все зарегистрированные модули.

| Контекст | Команды, переносимые из текущего CLI |
|---|---|
| `components` | `list`, `info`, `description`, `search`, `status`, `install`, `remove` |
| `diag` | `list`, `list-available`, `info`, `report`, `run`, `help` |
| `editions` | `list`, `list-available`, `description`, `license`, `info`, `set`, `get` |
| `manager` | `getobjects`, `getifaces`, `getsignals` |
| `packages/apt` | `info`, `install`, `list`, `reinstall`, `remove`, `search`, `update`, `last-update` |
| `packages/rpm` | `files`, `info`, `install`, `list`, `packageinfo`, `remove` |
| `packages/repo` | `add`, `info`, `list`, `remove` |
| `services` | `list`, `list-available`, `info`, `resources`, `status`, `deploy`, `configure`, `start`, `stop`, `backup`, `restore`, `undeploy`, `diagnose`, `play` |
| `sources` | `list`, `list-available`, `show`, `entries`, `enable`, `disable`, `check-sign` |
| `systeminfo` | `description`, `hostname`, `name`, `arch`, `branch`, `edition`, `kernel`, `cpu`, `gpu`, `memory`, `drive`, `monitor`, `motherboard`, `locales`, `desktops` |

Для каждого модуля нужны:

- выполнение существующих команд без потери аргументов и опций;
- относительный вызов после `use`;
- абсолютный вызов из любого контекста;
- статический command completion;
- справку из того же Command Catalog;
- прежние подтверждения опасных действий и понятные ошибки.

Object context не обязателен для каждого модуля. Команды `components` могут работать в `actl:components>` без `use <component>`. Глубокий контекст и динамическое автодополнение сначала проверяются на `services`.
