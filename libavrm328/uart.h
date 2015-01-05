#ifndef UART_H
#define UART_H

void usart_init(int baud_rate);
char usart_read_char(void);
void usart_write_char(char data);
void usart_write_string(const char* data);

#endif /* UART_H */ 
