# Тестовые точки

Добавлены 23.10.2026. Библиотека `MY_LIB_TestPoints.PcbLib`, три отдельных посадочных места:

| ID в DbLib | Footprint | Диаметр меди |
|---|---|---|
| TP0001 | TestPoint_Pad_D1.0mm | 1,0 мм |
| TP0002 | TestPoint_Pad_D1.5mm | 1,5 мм |
| TP0003 | TestPoint_Pad_D2.0mm | 2,0 мм |

Каждое посадочное место содержит только одну круглую SMD-площадку 1 в начале координат на Top Layer. Отверстия, паста, шелкография и 3D-модель отсутствуют. Маска открыта на весь диаметр меди с расширением 0,05 мм на сторону. Паста подавлена ручным отрицательным расширением, превышающим радиус площадки.

Диаметры сверены с официальной библиотекой KiCad: [1,0 мм](https://github.com/KiCad/kicad-footprints/blob/master/TestPoint.pretty/TestPoint_Pad_D1.0mm.kicad_mod), [1,5 мм](https://github.com/KiCad/kicad-footprints/blob/master/TestPoint.pretty/TestPoint_Pad_D1.5mm.kicad_mod), [2,0 мм](https://github.com/KiCad/kicad-footprints/blob/master/TestPoint.pretty/TestPoint_Pad_D2.0mm.kicad_mod). Взяты размеры площадок; окружности шелкографии KiCad не добавлялись по запросу пользователя «просто точка меди».

Общее существующее УГО `TestPoint` в `MY_LIB_Special.SchLib`, вывод 1. Изменён только тип на **Standard (No BOM)** (`ComponentKind=5`, `ComponentKindVersion2=5`), графика и пины сохранены побайтно. Это штатный тип Altium, а не пользовательский параметр `nobom`. Поле `ComponentType` в таблице служит читаемой справочной отметкой; тип задаётся самим УГО. Описание [типа Standard No BOM в API Altium](https://www.altium.com/documentation/altium-dxp-developer/schematic-api-design-objects-interfaces-reference).

В `MY_LIB.xlsx` добавлен лист «Тестовые точки», включённый в `MY_LIB.DbLib`. Проверены три строки через ACE OLE DB, рассчитанные Comment/Description и пути к моделям. Существующие листы Excel сохранены побайтно. Независимый импорт PcbLib через KiCad 9 подтвердил круглую форму, размеры, номер 1, отсутствие отверстий и графики, открытие маски 0,05 мм и подавление апертуры пасты. Резервные копии изменённых библиотек и базы находятся в `Backup`. Нативное размещение и ECO в Altium не выполнялись.
