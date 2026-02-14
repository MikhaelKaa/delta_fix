`timescale 1ns / 1ps

module d_fix_tb;

    // Параметры тестбенча (время)
    localparam CLK_64MHZ_PERIOD = 15.625; // 64 МГц -> 15.625 нс
    localparam RESET_DELAY = 1000;        // Длительность сброса = 1000 нс 
    localparam SIM_TIME = 160_000;        // Общее время симуляции = 160 мкс
    
    // Параметры для RAS сигналов
    localparam RAS_SHORT_DURATION = 4;    // 4 периода CLK_64MHZ (короткий импульс)
    localparam RAS_LONG_DURATION = 16;    // 16 периодов CLK_64MHZ (длинный импульс)
    localparam RAS_SHORT_START = 1320;    // Начало короткого импульса
    localparam RAS_LONG_START = 1640;     // Начало длинного импульса 

    // Сигналы для подключения к тестируемому модулю (DUT)
    reg  CLK_64MHZ;
    reg  reset_n;
    wire CLK_8MHZ;

    reg  CPU_CLK_in;    // Входной сигнал CPU_CLK
    wire CPU_CLK_out;   // Выходной сигнал CPU_CLK (с задержкой)
    reg  RAS_in;        // Входной сигнал RAS
    wire RAS_out;       // Выходной сигнал RAS (с задержкой)
    reg  CAS0_in;       // Входной сигнал CAS0
    wire CAS0_out;      // Выходной сигнал CAS0 (с задержкой)
    reg  CAS1_in;       // Входной сигнал CAS1
    wire CAS1_out;      // Выходной сигнал CAS1 (с задержкой)
    

    // 1. Инстанцирование тестируемого модуля (DUT)
    // Устанавливаем задержку RAS, например, на 2 периода CLK_64MHZ
    d_fix dut (
        .CLK_64MHZ      (CLK_64MHZ),
        .reset_n        (reset_n),
        .CLK_8MHZ       (CLK_8MHZ),
        
        .CPU_CLK_in     (CPU_CLK_in),
        .CPU_CLK_out    (CPU_CLK_out),
        .RAS_in         (RAS_in),
        .RAS_out        (RAS_out),
        .CAS0_in        (CAS0_in),
        .CAS0_out       (CAS0_out),
        .CAS1_in        (CAS1_in),
        .CAS1_out       (CAS1_out)        
    );

    // 2. Генерация тактового сигнала 64 МГц
    initial begin
        CLK_64MHZ = 1'b0;
        forever #(CLK_64MHZ_PERIOD / 2) CLK_64MHZ = ~CLK_64MHZ;
    end

    // 3. Генерация сигналов RAS
    initial begin
        // Инициализация
        RAS_in      = 1'b0;
        CAS0_in     = 1'b0;
        CAS1_in     = 1'b0;
        CPU_CLK_in  = 1'b0;

        // Ждем снятия сброса
        #RESET_DELAY;
        
        // Короткий импульс (4 периода CLK_64MHZ)
        #(RAS_SHORT_START - RESET_DELAY);
        RAS_in      = 1'b1;
        CAS0_in     = 1'b1;
        CAS1_in     = 1'b1;
        CPU_CLK_in  = 1'b1;
        #(RAS_SHORT_DURATION * CLK_64MHZ_PERIOD);
        RAS_in      = 1'b0;
        CAS0_in     = 1'b0;
        CAS1_in     = 1'b0;
        CPU_CLK_in  = 1'b0;
        
        // Длинный импульс (16 периодов CLK_64MHZ)
        #(RAS_LONG_START - RAS_SHORT_START - RAS_SHORT_DURATION * CLK_64MHZ_PERIOD);
        RAS_in      = 1'b1;
        CAS0_in     = 1'b1;
        CAS1_in     = 1'b1;
        CPU_CLK_in  = 1'b1;
        #(RAS_LONG_DURATION * CLK_64MHZ_PERIOD);
        RAS_in      = 1'b0;
        CAS0_in     = 1'b0;
        CAS1_in     = 1'b0;
        CPU_CLK_in  = 1'b0;

    end

    // 4. Последовательность сброса и управление симуляцией
    initial begin
        // Инициализация сигналов
        reset_n = 1'b0; // Активный низкий уровень - модуль в сбросе

        // Создание VCD файла для анализа сигналов
        $dumpfile("d_fix.vcd");
        // Дамп всех переменных, включая RAS сигналы
        $dumpvars(0, d_fix_tb);

        // Удерживаем сброс
        #RESET_DELAY;
        reset_n = 1'b1; // Снимаем сброс

        // Запускаем симуляцию
        #(SIM_TIME - RESET_DELAY);

        // Завершаем симуляцию
        $display("Симуляция завершена в момент времени %t нс", $time);
        $finish;
    end

endmodule