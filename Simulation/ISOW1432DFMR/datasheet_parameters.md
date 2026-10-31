# Численные характеристики ISOW1432DFMR

Единственный основной источник: [TI SLLSF86D, Revision D, August 2026](https://www.ti.com/lit/ds/symlink/isow1432.pdf). Номера страниц ниже — печатные страницы PDF. DATASHEET_MIN_MAX не означает, что модель вычисляет все технологические/температурные углы. Модель номинальная.

Для строк IDD из §6.10 и §6.11, если отдельно не оговорено иначе, VIO=VDD; при проверке IDD с VDD=5 В логическое питание также равно 5 В. Строки IIO с явно указанным VIO=3,3 В проверяются отдельно. Земли каждой стороны соединены внешней схемой, VISOIN питается от VISOOUT; типовые сравнения относятся к +25 °C. Эти условия не следует подменять одним значением выходного напряжения.

| Класс | Параметр | Значение | Источник / условия и реализация |
|---|---|---|---|
| DATASHEET_MIN_MAX | VDD рабочее | 3…5,5 В | §6.3, p7; MODE5 требует VDD=4,5…5,5 В |
| DATASHEET_MIN_MAX | VIO рабочее | 1,71…1,89; 2,25…5,5 В | §6.3, p7; промежуточный режим не нормирован |
| DATASHEET_TYP | VDD UVLO on/off | 2,8/2,55 В | §6.3, p7; native SW с гистерезисом 0,25 В |
| DATASHEET_MIN_MAX | VIO UVLO | on≤1,7 В; off≥1 В; hys≥75 мВ | §6.3, p7; не задана единая типовая пара абсолютных порогов |
| DATASHEET_TYP | VIO UVLO hys | 125 мВ | §6.3, p7 |
| ESTIMATED | VIO UVLO on/off | 1,65/1,525 В | Выбор в пределах данных §6.3 с типовым hys125 мВ, не типовая пара TI |
| ESTIMATED | VISOIN UVLO | 2,8/2,55 В | Консервативный функциональный контроль отсутствующего вторичного питания; отдельные TI-пороги VISOIN не заданы |
| DATASHEET_TYP | VISOOUT | 3,3 /5 В | §6.9, p11; MODE=GND2 /VISOOUT; плавающий MODE=3,3 В, Table8-1 |
| DATASHEET_MIN_MAX | VISOOUT диапазон | 3,135…3,465 /4,75…5,25 В | §6.9, p11, DE=0, D/RE/IN floating, соответствующий MODE; модель номинальная, VISO_TRIM позволяет сценарий границ |
| ESTIMATED | MODE распознавание | on1,5/off0,1 В; pull-down1 МОм | Table8-1 задаёт состояния, не номинал подтяжки/порог; гистерезис нужен также для MODE=VISOOUT |
| DATASHEET_MIN_MAX | tpwrup | до5 мс | §6.3, §8.6.1, 10 мкФ, достижение90% и готовности |
| ESTIMATED | Soft-start | τ=1 мс, ready98,5%, VOUT>90% цели | Аппроксимация §8.6.1; внутренний C=1 мкФ — управляющее состояние, не конденсатор питания |
| ESTIMATED | DC/DC Rreg /Ilimit | 0,501 Ом /колено150 мА, далее1 кОм | Упрощённый Thevenin-регулятор и ограничение по §8.6.2; short153…155 мА. TI не даёт такого постоянного выходного предела. При OFF ключ1 ТОм, принудительного разряда нет; при ON возможно поглощение тока |
| ESTIMATED | Soft-start RC и сброс | R=TSS/1мкФ; C=1мкФ; reset10 Ом | Пассивная RC обеспечивает DC-состояние1; при OFF ключ10 Ом разряжает только внутреннее управляющее состояние сτ≈9,9мкс |
| DATASHEET_TYP | IDD/IIO converter disabled | 0,23/0,24 мА | §6.10 p13 и §6.11 p15: EN=GND1, D/DE/RE floating; дополнительно физические токи подтяжек при принудительном управлении |
| DATASHEET_TYP | IIO disabled /static both /dynamic both | 3,2/4,0/4,6 мА | §6.10 p14: VIO=3,3 В±10%, DE0 RE1 /DE1 RE0 D1 loopback /12Mbps square50% loopback |
| ESTIMATED | IIO режимная аппроксимация | 3,2+0,4·DE+0,4·!RE+0,6·DE·activity мА | По трём предыдущим строкам; отдельные вклады DE/RX в TI не заданы; внешний ток R/OUT учитывается отдельно |
| DATASHEET_TYP | IDD TXstatic 3,3В | 56 мА (VDD5),69 мА (VDD3,3) | §6.10 p13: DE=RE=VIO,D=VIO,RL120Ом,A/B floating |
| DATASHEET_TYP | IDD TXdynamic3,3В | 87/69/114 мА (VDD5),105/84/137 мА (VDD3,3) | §6.10 p13: ISOW1432,RL120/100/54Ом параллельно50пФ,D12Mbps square50%,DE=RE=VIO. Строка100Ом немонотонна; простая физическая аппроксимация всех строк одновременно не гарантируется |
| DATASHEET_TYP | IDD RXdynamic3,3В | 15/17 мА приVDD5/3,3 | §6.10 p13: DE0 RE0,D0,A-B12Mbps square50%,R15пФ |
| DATASHEET_TYP | IDD both dynamic3,3В | 90/109 мА приVDD5/3,3 | §6.10 p14: DE1 RE0,RL120Ом||50пФ,loopback,D12Mbps50%,R15пФ |
| DATASHEET_TYP | IDD TXstatic5В | 97 мА | §6.11 p15: VDD5,DE=RE=VIO,D=VIO,RL120Ом,A/B floating |
| DATASHEET_TYP | IDD TXdynamic5В | 146/202 мА | §6.11 p15: VDD5,ISOW1432,RL120/54Ом||50пФ,D12Mbps square50%,DE=RE=VIO |
| DATASHEET_TYP | IDD RXdynamic5В /both dynamic5В | 24/145 мА | §6.11 p15: RX DE0RE0,A-B12Mbps,R15пФ /both DE1RE0,RL120||50пФ loopback,R15пФ |
| ESTIMATED | DC/DC input loss | 24 мВт + Pout/η | Энергия Pout=VISOOUT·I(REG), вся внешняя и вторичная нагрузка учтена один раз |
| ESTIMATED | η | 0,36 приVDD5; линейно до0,45 приVDD3,3 | Калибровка по §6.10–6.11, не типовой КПД TI; clamp0,36…0,45 |
| ESTIMATED | Вторичный базовый ток | 5,5мА (3,3В) /6,912мА (5В) | Подбор по RX-строкам §6.10/6.11; для других состояний физически разумная оценка |
| ESTIMATED | TX static /dynamic добавка | static+3мА(3,3В)/−4,97мА(5В); dynamic15,7мА(3,3В)/17,67мА(5В)·activity | Подбор по TX-строкам; суммарный статический вторичный ток при5В остаётся положительным1,942мА. Фактический sourcing ток Y/Z добавляется отдельно, не фиксированная нагрузка терминатора |
| ESTIMATED | Both RX добавка | 1,6мА при3,3В и0при5В | Аппроксимация loopback-строк |
| ESTIMATED | Activity | τedge10нс,τaverage20мкс,норма0,11994,clamp0…1 | Аппроксимация заряда на фронт, 12Mbps=6MHz square (§6.5); не создаёт данные |
| DATASHEET_MIN_MAX | Driver VOD | ≥1,5В при3,3В,≥2,1В при5В | §6.9 p11: RL54Ом, также иные указанные RL/common-mode условия; модель R20Ом/плечо даёт приблизительно1,90/2,87В при54Ом и номинальном питании |
| DATASHEET_MIN_MAX | Driver IOS | 180мА max | §6.9 p11; выход−7…12В или Y-Z short; §8.6.2 дополнительно описывает защиту±250мАmax |
| ESTIMATED | Driver output R и колено защиты | 20,001 Ом/плечо; knee0,999·BUS_ILIMIT, далее1 МОм | Конечная Thevenin-характеристика; номинальный knee179,82мА остаётся ниже180мА в диапазоне выхода−7…12В. Не паспортный RON/форма защиты |
| DATASHEET_MIN_MAX | D/DE/RE логические уровни | VIH≥0,7VIO,VIL≤0,3VIO | §6.3 p7; гистерезис в промежутке — допущение |
| DATASHEET_TYP | D/DE/RE pulls | 500 кОм | §8.8 p36, D/RE вверх,DE вниз |
| ESTIMATED | EN/IN pulls | 250 кОм | Направления Table8-1/8-5, при5В ток20мкА не превышает±25мкА §6.9 |
| DATASHEET_TYP | RX VTH+/VTH−/hys | −78/−141/63 мВ | §6.9 p12,common-mode−7…12В |
| ESTIMATED | A/B input bias | 1 МОм кGISOIN | Малые локальные входные токи и детерминированный open failsafe; не точная входная характеристика |
| ESTIMATED | R/OUT output R | 60/40 Ом | Конечный линейный выход, уровни соответствуют ограничениям §6.9 при штатных нагрузках; специального токового ограничителя этих выходов нет |
| ESTIMATED | Hi-Z leakage | 1 ГОм локально;VISOIN100 МОм | Численная опора, не гальваническая связь между сторонами |
| DATASHEET_TYP | TX delay3,3/5В | 49/40 нс | §6.12 p16/§6.13 p17,RL54Ом,CL50пФ,VIO3,3/5В |
| DATASHEET_TYP | TX rise/fall3,3/5В | 15/10 нс | Те же таблицы/условия; Tdelay44/36,3нс + τ6,6/4,2нс и реальная внешняя нагрузка — ESTIMATED реализация |
| DATASHEET_TYP | TX enable3,3В | HIGH46/LOW36нс | §6.12 Figure7-5/7-6; модель использует симметричный46нс (ESTIMATED LOW),времяdisable35нс |
| DATASHEET_TYP | TX enable5В | HIGH34/LOW25нс | §6.13 Figure7-5/7-6; модель использует симметричный34нс (ESTIMATED LOW),времяdisable30нс |
| ESTIMATED | DE control RC | on66,4/49нс,off50,5/43,3нс | τ=delay/ln2,3,3/5В; контроль midpoint, точная динамика тестового ключа TI не воспроизводится |
| DATASHEET_TYP | RX delay3,3/5В | 59/55 нс | §6.12/6.13,CL15пФ; Tdelay58,4/54,4нс + реальная нагрузка |
| DATASHEET_TYP | RX enable/disable | 3,3В:6/7нс HIGH,5/6нс LOW;5В:4/5нс | §6.12/6.13; модельсимметричнаяRCτ8,65/6,5нс — ESTIMATED аппроксимация |
| DATASHEET_TYP | GPIO delay | 227 нс | §6.12/6.13 Figure7-11; Tdelay226,6нс+выходнаяRCнагрузка |
| DATASHEET_MIN_MAX | GPIO data rate | 2 Мбит/с | §6.3 и§6.12/6.13; модель не генерирует трафик |
| DATASHEET_MIN_MAX | EN/FLT fault thresholds | VDD<2,5В или>7В | §8.6.2; FORCE_FAULT отдельный внешнийсценарий |
| ESTIMATED | FLT pull-down | 100 Ом, опцияFAULT_OUTPUT | Функциональныйopen-drain; внешняяподтяжка≥5кОм поTable5-1 |
| ESTIMATED | Hysteresis state | SW RON1мОм,ROFF1ТОм,Rstate1кОм | Численнаяреализациялогики,0/1Ввнутреннийконтрольнефизическийвывод; VT/VH развёрнуты в константы для MixedSim |
| ESTIMATED | Transport delay | T Z0=1кОм,Rsource=Rload=1кОм,передача×1 | СтандартныйсогласованныйSPICEэлемент,обаокончаниявместномдомене,TDконстанта |
| ESTIMATED | Control RC caps | 1пФ,activitycap1нФ | Внутренниесостояния,нефизическиепаразитныеёмкостивыводов |
| NOT_MODELED | Thermal/EMC/isolation physics/ESD | отсутствуют | Не моделируются физические барьер,пробой,сертификация,температура,ESD,25MHzripple |
| ESTIMATED | Invalid MODE | VDD<4,5В иMODE=HIGH: выход≈3,3В,интерфейсHi-Z | Реакция на недопустимый поTable8-1 режим, не поведение TI; позволяет устойчивыйDC приMODE=VISOOUT |
| NOT_MODELED | Other protection/limits | отсутствуют | Нет реального thermal cycling,клампаVISOOUT4/6В,достоверногоOVLOгистерезиса,защитныхдиодовподпитки,поврежденияилиугловпроцесса |
