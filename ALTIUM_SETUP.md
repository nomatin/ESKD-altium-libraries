# Подключение MY_LIB в Altium Designer 24

## Подготовка

Нужны Altium Designer 24, Microsoft Excel, совместимый с разрядностью Altium провайдер Microsoft ACE OLE DB и шрифт **Altium GOST Type A**. Сохраните структуру библиотеки: `MY_LIB.DbLib` и `MY_LIB.xlsx` должны находиться рядом с папками `Symbols`, `Footprints` и `Simulation`.

Откройте `MY_LIB.xlsx` в Excel, выполните полный пересчёт **Ctrl+Alt+F9**, сохраните и закройте книгу. Altium использует сохранённые результаты формул.

## Подключение

1. В Altium откройте `MY_LIB.DbLib` через **File → Open**.
2. В **Source of Connection** выберите **Use Connection String** и укажите свой путь к `MY_LIB.xlsx` в параметре `Data Source`. Сохраните провайдер `Microsoft.ACE.OLEDB.12.0` и `Extended Properties="Excel 12.0 Xml;HDR=YES;IMEX=1"`.
3. Нажмите **Connect** и убедитесь, что соединение установлено и таблицы читаются. Сохраните DbLib.
4. Откройте **Preferences → Data Management → File-based Libraries**, на вкладке **Installed** выберите **Install → Install from file** и укажите `MY_LIB.DbLib`.
5. В панели **Components** выберите таблицу библиотеки и разместите компонент. Устанавливать SchLib и PcbLib отдельно не требуется.

Пути к УГО, посадочным местам и SPICE-моделям относительны к DbLib. При переносе библиотеки также обновите абсолютные ссылки на локальные даташиты.

## Проверка и обновление

Проверьте отображение УГО, параметров и посадочного места. Перед изготовлением платы сверяйте распиновку, посадочное место и ограничения в `Notes` с даташитом конкретного изделия.

После обновления библиотеки заново откройте DbLib и открытые SchLib/PcbLib, не сохраняя поверх новых файлов старые версии. Для уже размещённых компонентов используйте **Tools → Update Parameters From Database**, проверяя предлагаемые изменения; графика и модели могут требовать отдельного обновления.

Если провайдер не найден, проверьте установку и разрядность ACE. Если данные или формулы устарели, пересчитайте и сохраните книгу в Excel, затем переподключите DbLib. Если УГО или посадочное место не найдены, проверьте имена и относительные пути в строке Excel. При пустых сопоставлениях проверьте ключ `ID → ID` и поля моделей в **Field Mappings**.

[Документация Altium по настройке DbLib](https://www.altium.com/documentation/altium-designer/components-libraries/database-libraries/creating-defining).
