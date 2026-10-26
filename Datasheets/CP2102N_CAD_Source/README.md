# CP2102N: официальный исходник и статус экспорта

Исходник: предоставленный пользователем архив `Interface Ultralibrarian CAD Footprints and Symbols.zip`, manifest version 1.15. Рабочая копия архива сохранена в `work/cp2102n_manufacturer` от корня рабочей папки.

В архиве присутствует `CP2102N-A01-GQFN24.bxl`. Файла A02 нет. BXL содержит footprint-варианты `QFN24_4X4`, `QFN24_4X4-M`, `QFN24_4X4-L`. Нельзя объявлять их проверенными для A02 до сверки с даташитом.

## Требуемый официальный путь

1. Войти в официальный [Ultra Librarian Online Reader](https://app.ultralibrarian.com/UploadBXL).
2. Загрузить соседний файл `CP2102N-A01-GQFN24.bxl`.
3. Выбрать официальный формат Altium Designer (Native), если он доступен для BXL. Сохранить весь полученный архив без изменения.
4. Если доступен только Altium Designer legacy, использовать поставленные Ultra Librarian `UL_Import.PrjScr` и `.txt` для штатного импорта в Altium. Самописный конвертер не заменяет этот шаг.
5. После экспорта проверить итоговую PcbLib независимым субагентом: геометрия, нумерация, маска, паста и соответствие даташиту A02.

Официальный нативный экспорт получен через Ultra Librarian Online Reader. Архив `ul_cp2102n-a01-gqfn24.zip` и все семь исходных файлов сохранены без изменений в `MY_LIB/Footprints/CP2102N_Official_Altium` от корня рабочей папки. Проверены CRC архива и побайтовое соответствие распакованных файлов. Контрольные суммы находятся в `archive_sha256.txt` и `export_sha256.json`.

Открывать в Altium следует `export/Altium/cp2102n-a01-gqfn24.LibPkg` из папки официального экспорта. Итоговый отчёт проверки: `CP2102N-A02-GQFN24_check.md` в той же папке. Имя исходной ревизии A01 сохранено намеренно; сам факт официального экспорта не подтверждает соответствие рекомендациям даташита A02.

Предварительные самописные конверсии перемещены из активной папки Footprints в `work/cp2102n_manufacturer/unofficial_drafts`. Они не являются официальным экспортом и не предназначены для использования как окончательный результат.

Документация:

- [Silicon Labs: официальный процесс BXL](https://www.silabs.com/support/resources/cad-cae-schematic-footprints-and-symbols)
- [Ultra Librarian: импорт Altium Native](https://app.ultralibrarian.com/content/help/altium_designer_2.htm)
- [Ultra Librarian: импорт Altium legacy](https://app.ultralibrarian.com/content/help/altium_designer.htm)
- [CP2102N datasheet, Rev. 1.5](https://www.silabs.com/documents/public/data-sheets/cp2102n-datasheet.pdf)
