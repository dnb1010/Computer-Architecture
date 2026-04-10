module emergency_fsm (
    input clk,
    input rst,
    input ready_strobe,       // MỚI: Xung báo hiệu có nhịp tim mới từ d_n_b
    input [1:0] risk_in,      // Từ risk_classifier
    output reg [1:0] risk_out, // Đến alarm_controller
    output reg alarm_trigger
);

    // One-hot encoding cho các trạng thái
    parameter IDLE       = 6'b000001;
    parameter MEASURING  = 6'b000010;
    parameter ANALYZING  = 6'b000100;
    parameter COUNTING   = 6'b001000;
    parameter COMPARE    = 6'b010000;
    parameter DISPLAY    = 6'b100000;

    reg [5:0] current_state, next_state;
    reg [2:0] error_count;
    reg [1:0] temp_risk;

    // 1. Chuyển đổi trạng thái đồng bộ
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // 2. Logic tính toán trạng thái tiếp theo
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE:      next_state = MEASURING;
            
            MEASURING: begin
                if (ready_strobe) // Chỉ phân tích khi d_n_b báo đã tính xong BPM
                    next_state = ANALYZING;
            end

            ANALYZING: begin
                if (risk_in != 2'b00) 
                    next_state = COUNTING;
                else 
                    next_state = MEASURING;
            end

            COUNTING:  next_state = COMPARE;

            COMPARE: begin
                if (error_count >= 3'd3) // 4 lần bất thường liên tiếp (0, 1, 2, 3)
                    next_state = DISPLAY;
                else 
                    next_state = MEASURING;
            end

            DISPLAY:   next_state = MEASURING;
            
            default:   next_state = IDLE;
        endcase
    end

    // 3. Logic điều khiển thanh ghi (đồng bộ)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            error_count <= 0;
            risk_out <= 2'b00;
            temp_risk <= 2'b00;
        end else begin
            case (current_state)
                IDLE: begin
                    error_count <= 0;
                    risk_out <= 2'b00;
                end
                
                ANALYZING: begin
                    if (risk_in == 2'b00) begin
                        error_count <= 0; // Reset bộ đếm nếu nhịp tim về bình thường
                        risk_out <= 2'b00;
                    end else begin
                        temp_risk <= risk_in;
                    end
                end
                
                COUNTING: begin
                    error_count <= error_count + 1'b1;
                end
                
                DISPLAY: begin
                    risk_out <= temp_risk;
                end
                
                MEASURING: begin
                    // Giữ nguyên trạng thái cũ cho đến khi có kết quả mới
                    if (ready_strobe && risk_in == 2'b00) risk_out <= 2'b00;
                end
            endcase
        end
    end

    // 4. Đầu ra tổ hợp
    always @(*) begin
        alarm_trigger = (current_state == DISPLAY);
    end

endmodule
