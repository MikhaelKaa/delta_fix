# Для тестирования модуля неодходимо чтобы тест назывался %имя_модуля%_tb

TARGET ?= d_fix
ICARUS = iverilog

all: 
	rm -f $(TARGET)
	$(ICARUS) -g2012 -o $(TARGET)  $(TARGET).v $(TARGET)_tb.v
	vvp $(TARGET)
	rm -f $(TARGET)
clean:
	rm -f $(TARGET) $(TARGET).vcd

.PHONY: all clean