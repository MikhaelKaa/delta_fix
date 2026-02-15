`timescale 1ns / 1ps

module d_fix_tb;

    // Параметры тестбенча (время)
    localparam CLK_64MHZ_PERIOD = 15.625; // 64 МГц -> 15.625 нс
    localparam RESET_DELAY = 1000;        // Длительность сброса = 1000 нс 
    localparam SIM_TIME = 160_000;        // Общее время симуляции = 160 мкс

    // Параметр фазовой задержки CPU_CLK_in (в тактах 64 МГц, 0..8)
    localparam CPU_CLK_PHASE_DELAY = 5;   // 0 - без задержки, 1..8 - задержка на N тактов

    // Сигналы для подключения к тестируемому модулю (DUT)
    reg  CLK_64MHZ;
    reg  reset_n;
    wire CLK_8MHZ;

    wire CPU_CLK_in;    // Входной сигнал CPU_CLK (генерируется отдельно)
    wire CPU_CLK_out;   // Выходной сигнал CPU_CLK (с задержкой)
    reg  RAS_in;        // Входной сигнал RAS
    wire RAS_out;       // Выходной сигнал RAS (с задержкой)
    reg  CAS0_in;       // Входной сигнал CAS0
    wire CAS0_out;      // Выходной сигнал CAS0 (с задержкой)
    reg  CAS1_in;       // Входной сигнал CAS1
    wire CAS1_out;      // Выходной сигнал CAS1 (с задержкой)
    
    // Внутренние сигналы для генерации CPU_CLK_in
    reg  cpu_base;              // базовая частота 4 МГц (без фазового сдвига)
    wire cpu_phase_shifted;     // после задержки

    // 1. Инстанцирование тестируемого модуля (DUT)
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

    // 3. Генерация сигналов RAS, CAS в соответствии с заданной последовательностью
    initial begin
        // Инициализация
        RAS_in      = 1'b0;
        CAS0_in     = 1'b0;
        CAS1_in     = 1'b0;

        // Ждем снятия сброса
        #RESET_DELAY;
        
        // --- Часть 1 ---
        #460;  // низкий уровень (460 нс)
        RAS_in      = 1'b1;
        CAS0_in     = 1'b1;
        CAS1_in     = 1'b1;
        #170;  // высокий уровень (170 нс)
        RAS_in      = 1'b0;
        CAS0_in     = 1'b0;
        CAS1_in     = 1'b0;
        #60;   // низкий уровень (60 нс)
        RAS_in      = 1'b1;
        CAS0_in     = 1'b1;
        CAS1_in     = 1'b1;
        #25;   // высокий уровень (25 нс) <--- иголка
        RAS_in      = 1'b0;
        CAS0_in     = 1'b0;
        CAS1_in     = 1'b0;
        #460;  // низкий уровень (460 нс)
        RAS_in      = 1'b1;
        CAS0_in     = 1'b1;
        CAS1_in     = 1'b1;
        #170;  // высокий уровень (170 нс)
        RAS_in      = 1'b0;
        CAS0_in     = 1'b0;
        CAS1_in     = 1'b0;

        // Пауза 2000 нс (низкий уровень)
        #2000;

        // --- Часть 2 ---
        #460;  // низкий уровень (460 нс)
        RAS_in      = 1'b1;
        CAS0_in     = 1'b1;
        CAS1_in     = 1'b1;
        #170;  // высокий уровень (170 нс)
        RAS_in      = 1'b0;
        CAS0_in     = 1'b0;
        CAS1_in     = 1'b0;
        #530;  // низкий уровень (530 нс)
        RAS_in      = 1'b1;
        CAS0_in     = 1'b1;
        CAS1_in     = 1'b1;
        #170;  // высокий уровень (170 нс)
        RAS_in      = 1'b0;
        CAS0_in     = 1'b0;
        CAS1_in     = 1'b0;

        // Далее сигналы остаются низкими до конца симуляции
    end

    // 4. Генерация CPU_CLK_in с частотой 4 МГц и дискретной фазой
    // Формируем базовый сигнал делением CLK_8MHZ на 2
    always @(posedge CLK_8MHZ or negedge reset_n) begin
        if (!reset_n)
            cpu_base <= 1'b0;
        else
            cpu_base <= ~cpu_base;
    end

    // Модуль задержки для создания фазового сдвига (используется signal_delay из d_fix.v)
    signal_delay #(
        .DELAY(CPU_CLK_PHASE_DELAY)
    ) cpu_phase_delay (
        .clk        (CLK_64MHZ),
        .reset_n    (reset_n),
        .signal_in  (cpu_base),
        .signal_out (cpu_phase_shifted)
    );

    // Подключаем сдвинутый сигнал ко входу DUT
    assign CPU_CLK_in = cpu_phase_shifted;

    // 5. Последовательность сброса и управление симуляцией
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