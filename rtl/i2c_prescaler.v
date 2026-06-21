module i2c_prescaler #(
    parameter CLK_FREQ = 50_000_000,
    parameter I2C_FREQ = 100_000
)(
    input wire clk,
    input wire reset,
    output reg scl_clk_en
);

localparam DIVIDER = CLK_FREQ/(4*I2C_FREQ);
localparam CLICKER = $clog2(DIVIDER);
reg [CLICKER-1:0] click;

always @(posedge clk or negedge reset)begin
    if(!reset) begin
        click       <= '0;
        scl_clk_en  <= 1'b0;
    end else begin
        if(click == DIVIDER-1) begin
            click <= '0;
            scl_clk_en <=1'b1;
        end else begin 
            click <= click + 1'b1;
            scl_clk_en <= 1'b0;
        end
    end
end
endmodule
