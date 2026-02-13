`timescale 1ns / 1ps

module d_fix #(
    // Константа для управления скважностью сигнала 8 МГц (1-5)
    parameter DUTY_8 = 2,      // По умолчанию 50% (3/6 = 50%)
    // Константа для задержки CPU_CLK сигнала (периодов CLK_48MHZ)
    parameter CPU_CLK_DELAY = 3,   // По умолчанию без задержки (0-8)
    // Константа для задержки RAS сигнала (периодов CLK_48MHZ)
    parameter RAS_DELAY = 1,   // По умолчанию без задержки (0-8)
    // Константа для задержки CAS1 сигнала (периодов CLK_48MHZ)
    parameter CAS1_DELAY = 2,  // По умолчанию без задержки (0-8)
    // Константа для задержки CAS2 сигнала (периодов CLK_48MHZ)
    parameter CAS2_DELAY = 3   // По умолчанию без задержки (0-8)
)(
    // Main Clock
    input   CLK_48MHZ,
    // reset
    input   reset_n,
    // Delta ULA clock
    output  CLK_8MHZ,

    // CPU
    input   CPU_CLK_in,
    output  CPU_CLK_out,
    
    input   RAS_in,
    output  RAS_out,

    input   CAS1_in,
    output  CAS1_out,

    input   CAS2_in,
    output  CAS2_out
    
);

    // Контроль границ параметров для тактирования паука
    localparam DUTY_8_VAL = (DUTY_8 >= 1 && DUTY_8 <= 5) ? DUTY_8 : 3;
 
    // Ограничение задержек для всех трех сигналов (0-8 периодов)
    localparam RAS_DELAY_VAL = (RAS_DELAY >= 0 && RAS_DELAY <= 8) ? RAS_DELAY : 0;
    localparam CAS1_DELAY_VAL = (CAS1_DELAY >= 0 && CAS1_DELAY <= 8) ? CAS1_DELAY : 0;
    localparam CAS2_DELAY_VAL = (CAS2_DELAY >= 0 && CAS2_DELAY <= 8) ? CAS2_DELAY : 0;

    // ========== ДЕЛИТЕЛЬ ЧАСТОТЫ ==========
    // Эта часть генерирует 8 МГц из 48 МГц
    reg [5:0] counter_8 = 6'b0;    // Счетчик для 8 МГц (0-5, период 6 тактов)
    reg clk_8 = 1'b0;

    // Счетчик для 8 МГц - 6 состояний (48/8 = 6)
    always @(negedge CLK_48MHZ or negedge reset_n) begin
        if (!reset_n) begin
            counter_8 <= 6'b0;
        end else begin
            if (counter_8 < 5) begin
                counter_8 <= counter_8 + 1'b1;
            end else begin
                counter_8 <= 6'b0;
            end
        end
    end

    // Генерация 8 МГц с регулируемой скважностью
    always @(negedge CLK_48MHZ or negedge reset_n) begin
        if (!reset_n) begin
            clk_8 <= 1'b0;
        end else begin
            // Установка скважности
            if (counter_8 < DUTY_8_VAL) begin
                clk_8 <= 1'b1;
            end else begin
                clk_8 <= 1'b0;
            end
        end
    end

    assign CLK_8MHZ = clk_8;
    // ========== КОНЕЦ ДЕЛИТЕЛЯ ЧАСТОТЫ ==========

    // ========== МОДУЛИ ЗАДЕРЖКИ СИГНАЛОВ ==========
    // Используем вынесенный модуль signal_delay для каждого сигнала

    signal_delay #(
        .DELAY(CPU_CLK_DELAY)
    ) cpu_clk_delay_inst (
        .clk(CLK_48MHZ),
        .reset_n(reset_n),
        .signal_in(CPU_CLK_in),
        .signal_out(CPU_CLK_out)
    );

    signal_delay #(
        .DELAY(RAS_DELAY_VAL)
    ) ras_delay_inst (
        .clk(CLK_48MHZ),
        .reset_n(reset_n),
        .signal_in(RAS_in),
        .signal_out(RAS_out)
    );

    signal_delay #(
        .DELAY(CAS1_DELAY_VAL)
    ) cas1_delay_inst (
        .clk(CLK_48MHZ),
        .reset_n(reset_n),
        .signal_in(CAS1_in),
        .signal_out(CAS1_out)
    );

    signal_delay #(
        .DELAY(CAS2_DELAY_VAL)
    ) cas2_delay_inst (
        .clk(CLK_48MHZ),
        .reset_n(reset_n),
        .signal_in(CAS2_in),
        .signal_out(CAS2_out)
    );

endmodule

// ========== МОДУЛЬ ЗАДЕРЖКИ СИГНАЛА ==========
// Общий модуль для задержки сигналов на заданное число тактов
// Параметр DELAY: 0-8 периодов CLK_48MHZ
// Особенности:
// - DELAY=0: задержка 0
// - DELAY=1: задержка 1 такт
// - DELAY=2: задержка 2 такта
// - DELAY=3-8: задержка 3-8 тактов из сдвигового регистра
module signal_delay #(
    parameter DELAY = 0
)(
    input clk,         // Тактовый сигнал (используется negedge)
    input reset_n,     // Асинхронный сброс, активный низкий
    input signal_in,   // Входной сигнал
    output signal_out  // Выходной сигнал с задержкой
);
    
    // Синхронизация входного сигнала
    reg sync1, sync2;
    // Сдвиговый регистр для задержки (0-5: задержки 3-8 тактов)
    reg [5:0] delay_chain = 6'b0;
    // Выходной регистр
    reg delayed_signal;
    
    always @(negedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
            delay_chain <= 6'b0;
        end else begin
            // Цепочка синхронизации
            sync1 <= signal_in;
            sync2 <= sync1;
            // Сдвиговый регистр, младший бит - самый свежий
            delay_chain <= {delay_chain[4:0], sync2};
        end
    end
    
    // Выбор выхода с нужной задержкой
    always @(*) begin
        case (DELAY)
            0: delayed_signal = signal_in;  // Задержка 0 
            1: delayed_signal = sync1;      // Задержка 1 такт
            2: delayed_signal = sync2;      // Задержка 2 такта
            3: delayed_signal = delay_chain[0]; // 3 такта
            4: delayed_signal = delay_chain[1]; // 4 такта
            5: delayed_signal = delay_chain[2]; // 5 тактов
            6: delayed_signal = delay_chain[3]; // 6 тактов
            7: delayed_signal = delay_chain[4]; // 7 тактов
            8: delayed_signal = delay_chain[5]; // 8 тактов
            default: delayed_signal = signal_in;    // По умолчанию 0
        endcase
    end
    
    assign signal_out = delayed_signal;
    
endmodule