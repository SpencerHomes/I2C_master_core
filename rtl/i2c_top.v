module i2c_top #(
    parameter CLK_FREQ = 50_000_000,
    parameter I2C_FREQ = 100_000
)(
    input  wire       clk,
    input  wire       reset,
    input  wire [6:0] address,
    input  wire       rw,
    input  wire [7:0] data_in,
    output wire [7:0] data_out,
    input  wire       start,
    input  wire       stop,
    input  wire       stop_en,
    output wire       busy,
    output wire       done,
    output wire       ack_error,
    inout  wire       scl,      // Physical I2C SCL pin
    inout  wire       sda       // Physical I2C SDA pin
);

wire scl_clk_en;
wire scl_out_w, sda_out_w;
wire sda_in_w;  

i2c_prescaler #(
    .CLK_FREQ (CLK_FREQ),
    .I2C_FREQ (I2C_FREQ)
) u_prescaler (
    .clk       (clk),
    .reset     (reset),
    .scl_clk_en(scl_clk_en)
);

i2c_protocol u_protocol (
    .clk       (clk),
    .reset     (reset),
    .scl_clk_en(scl_clk_en),
    .address   (address),
    .rw        (rw),
    .data_in   (data_in),
    .data_out  (data_out),
    .start     (start),
    .stop_en   (stop_en),
    .stop      (stop),
    .busy      (busy),
    .done      (done),
    .ack_error (ack_error),
    .scl_out   (scl_out_w),
    .sda_out   (sda_out_w),
    .sda_in    (sda_in_w)   // Feed the physical bus state into the synchronizer
);

// Open-drain: only drive LOW, release to pull-up for HIGH
// NEVER drive SCL/SDA high from FPGA output
assign scl = scl_out_w ? 1'bz : 1'b0;
assign sda = sda_out_w ? 1'bz : 1'b0;

// The Input Reader (Listening to the bus)
// Continuously read the actual voltage on the physical SDA wire
assign sda_in_w = sda;

endmodule