module bpm_calculator (
    input clk,
    input rst,
    input start_calc,
    input [31:0] rr_interval, 
    output reg [15:0] rr_ms,  
    output reg [7:0] bpm 
);
    // 50,000 pulses = 1ms tai tan so he thong 50MHz
    parameter CLK_PER_MS = 32'd50_000; 

    // Bien tam luu ket qua mach to hop
    wire [15:0] calculated_rr_ms;
    
    // Phep chia to hop 1: Xac dinh khoang thoi gian RR theo ms
    assign calculated_rr_ms = rr_interval / CLK_PER_MS;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rr_ms <= 16'd0;
            bpm   <= 8'd0;
        end else if (start_calc) begin
            rr_ms <= calculated_rr_ms;

            // Kiem tra dieu kien bang rr_ms (giam do rong so sanh tu 32-bit xuong 16-bit)
            // Nguong sinh ly hop le: 240ms (~250 BPM) < rr_ms < 2000ms (~30 BPM)
            if (calculated_rr_ms > 16'd240 && calculated_rr_ms < 16'd2000) begin 
                // Phep chia to hop 2: Tinh toan BPM tu hang so thoi gian 1 phut (60,000 ms)
                bpm <= 16'd60_000 / calculated_rr_ms; 
            end else begin
                bpm <= 8'd0; // Canh bao tin hieu nhieu hoac khong hop le
            end
        end
    end
endmodule
