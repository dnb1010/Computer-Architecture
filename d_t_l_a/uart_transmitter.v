module uart_transmitter (
    input  wire       clk,        // 50 MHz
    input  wire       rst,        // Tích cực cao
    input  wire [7:0] data_in,    // Dữ liệu 8-bit BPM
    input  wire       start_tx,   // Xung kích hoạt gửi (có thể nối với ready_strobe)
    output reg        tx_out      // Chân truyền dữ liệu UART
);

    // Tham số cho Baudrate 9600 tại 50MHz
    parameter CLKS_PER_BIT = 5208;

    // Trạng thái FSM
    localparam IDLE   = 2'b00;
    localparam START  = 2'b01;
    localparam DATA   = 2'b10;
    localparam STOP   = 2'b11;

    reg [1:0]  state;
    reg [12:0] clk_cnt;
    reg [2:0]  bit_index;
    reg [7:0]  tx_data;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_out <= 1'b1; // UART IDLE mức cao
            clk_cnt <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_out <= 1'b1;
                    clk_cnt <= 0;
                    bit_index <= 0;
                    if (start_tx) begin
                        tx_data <= data_in; // Chốt dữ liệu
                        state <= START;
                    end
                end

                START: begin
                    tx_out <= 1'b0; // Start bit = 0
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        state <= DATA;
                    end
                end

                DATA: begin
                    tx_out <= tx_data[bit_index]; // Gửi từng bit từ LSB đến MSB
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx_out <= 1'b1; // Stop bit = 1
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
