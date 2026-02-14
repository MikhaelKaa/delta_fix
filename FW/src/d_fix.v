`timescale 1ns / 1ps
// файл в кодировке cp-1251 - нативная для квартуса.
module d_fix #(
    // Константа для управления скважностью сигнала 8 МГц (1-7)
    parameter DUTY_8 = 4,      // По умолчанию 50% (4/8 = 50%)
    // Константа для задержки CPU_CLK сигнала (периодов CLK_64MHZ)
    parameter CPU_CLK_DELAY = 0,   // По умолчанию без задержки (0-8)
    // Константа для задержки RAS сигнала (периодов CLK_64MHZ)
    parameter RAS_DELAY = 1,   // По умолчанию без задержки (0-8)
    // Константа для задержки CAS1 сигнала (периодов CLK_64MHZ)
    parameter CAS0_DELAY = 1,  // По умолчанию без задержки (0-8)
    // Константа для задержки CAS2 сигнала (периодов CLK_64MHZ)
    parameter CAS1_DELAY = 1   // По умолчанию без задержки (0-8)
)(
    // Main Clock
    input   CLK_64MHZ,
    // reset
    input   reset_n,
    // Delta ULA clock
    output  CLK_8MHZ,

    // CPU
    input   CPU_CLK_in,
    output  CPU_CLK_out,
    
    input   RAS_in,
    output  RAS_out,

    input   CAS0_in,
    output  CAS0_out,

    input   CAS1_in,
    output  CAS1_out
    
);

    // Контроль границ параметров для тактирования паука
    localparam DUTY_8_VAL = (DUTY_8 >= 1 && DUTY_8 <= 7) ? DUTY_8 : 3;
 
    // Ограничение задержек для всех сигналов (0-8 периодов)
	 localparam CPU_CLK_DELAY_VAL = (CPU_CLK_DELAY >= 0 && CPU_CLK_DELAY <= 8) ? CPU_CLK_DELAY : 0;
    localparam RAS_DELAY_VAL     = (RAS_DELAY >= 0     && RAS_DELAY <= 8)     ? RAS_DELAY     : 0;
    localparam CAS0_DELAY_VAL    = (CAS0_DELAY >= 0    && CAS0_DELAY <= 8)    ? CAS0_DELAY    : 0;
    localparam CAS1_DELAY_VAL    = (CAS1_DELAY >= 0    && CAS1_DELAY <= 8)    ? CAS1_DELAY    : 0;

	// ========== ДЕЛИТЕЛЬ ЧАСТОТЫ ==========
	// Эта часть генерирует 8 МГц из 64 МГц
	reg [2:0] counter_8 = 3'b0;    // Счетчик для 8 МГц (0-7, период 8 тактов)
	reg clk_8 = 1'b0;

	// Счетчик для 8 МГц - 8 состояний (64/8 = 8)
	always @(negedge CLK_64MHZ or negedge reset_n) begin
		 if (!reset_n) begin
			  counter_8 <= 3'b0;
		 end else begin
			  if (counter_8 < 7) begin          // считаем 0..7, затем сброс
					counter_8 <= counter_8 + 1'b1;
			  end else begin
					counter_8 <= 3'b0;
			  end
		 end
	end

	// Генерация 8 МГц с регулируемой скважностью
	always @(negedge CLK_64MHZ or negedge reset_n) begin
		 if (!reset_n) begin
			  clk_8 <= 1'b0;
		 end else begin
			  // Установка скважности (DUTY_8_VAL должно быть в диапазоне 0..7)
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
        .DELAY(CPU_CLK_DELAY_VAL)
    ) cpu_clk_delay_inst (
        .clk(CLK_64MHZ),
        .reset_n(reset_n),
        .signal_in(CPU_CLK_in),
        .signal_out(CPU_CLK_out)
    );

    signal_delay #(
        .DELAY(RAS_DELAY_VAL)
    ) ras_delay_inst (
        .clk(CLK_64MHZ),
        .reset_n(reset_n),
        .signal_in(RAS_in),
        .signal_out(RAS_out)
    );

    signal_delay #(
        .DELAY(CAS0_DELAY_VAL)
    ) cas1_delay_inst (
        .clk(CLK_64MHZ),
        .reset_n(reset_n),
        .signal_in(CAS0_in),
        .signal_out(CAS0_out)
    );

    signal_delay #(
        .DELAY(CAS1_DELAY_VAL)
    ) cas2_delay_inst (
        .clk(CLK_64MHZ),
        .reset_n(reset_n),
        .signal_in(CAS1_in),
        .signal_out(CAS1_out)
    );

endmodule

// ========== МОДУЛЬ ЗАДЕРЖКИ СИГНАЛА ==========
// Общий модуль для задержки сигналов на заданное число тактов
// Параметр DELAY: 0-8 периодов CLK_64MHZ
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