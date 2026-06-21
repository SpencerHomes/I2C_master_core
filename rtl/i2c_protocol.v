module i2c_protocol(
    input wire clk,                 
    input wire reset,               
    input wire [6:0] address,
    input wire rw,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    input wire start,
    input wire stop_en,
    input wire stop,
    output reg busy,
    output reg done,
    output reg ack_error,
    output reg scl_out,
    output reg sda_out,
    input wire scl_clk_en,
    input wire sda_in
);


localparam [3:0]
    S_IDLE              =4'd0,
    S_START             =4'd1,
    S_ADDR              =4'd2,
    S_RW                =4'd3,
    S_ACK_ADDR          =4'd4,
    S_READ              =4'd5,
    S_ACK_READ          =4'd6,
    S_WRITE             =4'd7,
    S_ACK_WRITE         =4'd8,
    S_STOP              =4'd9,
    S_REP_STOP          =4'd10;

reg[7:0] shift_reg;
reg[3:0] state;
reg[1:0] phase;      //4 phases 
reg[2:0] counter;



//to solve metastability of sda
reg sda_meta , sda_sync;
always @(posedge clk) begin
    sda_meta<=sda_in;
    sda_sync<=sda_meta;
end

//state transition
always @(posedge clk or negedge reset) begin          //50Mhz = clk 
    if(!reset) begin
    state               <=S_IDLE;
    phase               <=2'd0;
    shift_reg           <=8'b0;
    scl_out             <=1'b1;                       //tells what scl will do(output explicitly)
    sda_out             <=1'b1;                       //tells what sda will do(output explicitly)
    busy                <=1'b0;
    ack_error           <=1'b0;
    data_out            <=1'b0;
    busy                <=1'b0;
    counter             <=3'd7;
    done                <=1'b0;
end else begin
    if(scl_clk_en) begin                              //scl_clk_en ticks at 31th clk pulse
        case(state)
        S_IDLE: begin
            scl_out<=1'b1;
            sda_out<=1'b1;
            busy   <=1'b0;
            phase  <=2'd0;
            done   <=1'b0;
            if(start) begin
            busy            <= 1'b1;
            ack_error       <=1'b0;
            shift_reg       <={address , rw};
            counter         <=3'd7;
            state           <=S_START;
            end
        end

        S_START: begin
            case(phase)
            2'd0 : begin scl_out <= 1'b1; sda_out <= 1'b1; end
            2'd1 : begin sda_out <= 1'b0; scl_out <= 1'b1; end
            2'd2 : begin sda_out <= 1'b0; scl_out <= 1'b0; end
            2'd3 : begin 
                state <= S_ADDR;
                counter <= 3'd7;
             end
            endcase
            phase <= phase + 1'b1;
        end

        S_ADDR: begin
            done <= 1'b0;                  //again initializing as during Repeated Start "idle" state is ebeing bypassed so done remains high due to previous state and machine goes to deadlock.  
            case(phase)
            2'd0: begin
                scl_out<=1'b0;
                sda_out<=shift_reg[7];
            end
            2'd1: scl_out<=1'b1;
            2'd2: ;
            2'd3:begin
                    scl_out     <=1'b0;
                if(counter == 3'd1)begin
                    shift_reg   <=shift_reg << 1;
                    state       <=S_RW;
                    counter     <=3'd0;
                end else begin
                shift_reg   <=shift_reg << 1;
                counter     <=counter - 1'b1;
            end
            end
            endcase
            phase <= phase + 1'b1;
        end

        S_RW: begin
            case(phase)
            2'd0:begin
                scl_out     <=1'b0;
                sda_out     <=rw;
            end
            2'd1:scl_out<=1'b1;
            2'd2:;
            2'd3:begin
                scl_out<=1'b0;
                sda_out<=1'b1;  //opening sda line for slave acknowledge
                state  <=S_ACK_ADDR;
            end
            endcase
            phase <= phase + 1'b1;
        end

        S_ACK_ADDR:begin
            case(phase)
            2'd0: begin
                scl_out         <=1'b0;                     //written again to avoid deadlock caused by state jumping
                sda_out         <=1'b1;                        
            end
            2'd1: scl_out       <=1'b1;
            2'd2:begin
                if(sda_sync===1'b1)begin
                    ack_error<=1'b1;
                end
            end
            2'd3:begin
                scl_out <=1'b0;
                if(!ack_error)begin
                    if(rw == 1'b0) begin
                        shift_reg   <= data_in;
                        counter     <=3'd7;
                        state       <=S_WRITE;
                    end else begin
                        counter     <=3'd7;
                        shift_reg <= 8'h00;
                        state       <=S_READ;
                    end
                end     else begin
                    state  <=  S_STOP;
                end
            end
            endcase
            phase<=phase+1'b1;
        end
        
        S_READ:begin
            case(phase)
            2'd0:begin
                scl_out     <=1'b0;
                sda_out     <=1'b1;
            end

            2'd1:scl_out    <=1'b1;
            2'd2: begin
                if(counter == 3'd7)
        $display("MASTER FIRST READ SAMPLE");

    $display("RX counter=%0d bit=%b", counter, sda_sync);

                shift_reg <= {shift_reg[6:0], sda_sync};
            end
            2'd3:begin
                scl_out <=1'b0;
                if(counter==3'd0)begin
                    $display("FINAL data_out candidate = %h", shift_reg);
                    data_out <= shift_reg;
                    state   <=S_ACK_READ;
                end else begin
                    counter <=counter - 1'b1;
                end
            end
            endcase
            phase   <=  phase+1'b1;
        end

        S_ACK_READ: begin
            case(phase)
            2'd0:begin
                scl_out <=1'b0;
                sda_out<=1'b1;
            end
            2'd1: scl_out   <=1'b1;
            2'd2:;
            2'd3:begin
                scl_out <=1'b0;
                state   <=(stop_en) ?   S_STOP : S_REP_STOP;
            end
            endcase
            phase   <=  phase+1'b1;
            end
        
        S_WRITE:    begin
            case(phase)
            2'd0:begin
            scl_out <= 1'b0;
            sda_out <= shift_reg[7];
            end
            2'd1:
                scl_out<=1'b1;
            2'd2:;
            2'd3: begin
                scl_out <= 1'b0;
                shift_reg   <=  shift_reg   <<  1;
                if(counter==3'd0)begin
                    sda_out <=  1'b1;
                    state   <=  S_ACK_WRITE;
                end else begin
                    counter <= counter - 1'b1;
                end
            end
            endcase
            phase<= phase + 1'b1;
        end

        S_ACK_WRITE:begin
            case(phase)
            2'd0: begin 
                scl_out<=1'b0; sda_out<=1'b1; end
            2'd1: scl_out<=1'b1;
            2'd2: begin
                if(sda_sync==1'b1)begin
                    ack_error<=1'b1;
                end
            end
            2'd3: begin
                scl_out<=1'b0;
                if(stop_en||ack_error)begin
                    state<=S_STOP;
                end else begin
                    state<=S_REP_STOP;
                end
            end
            endcase
            phase <= phase + 1'b1;
        end

        S_STOP:begin
            case(phase)
            2'd0 : begin scl_out <= 1'b0; sda_out <= 1'b0; end
            2'd1 : begin sda_out <= 1'b0; scl_out <= 1'b1; end
            2'd2 : begin sda_out <= 1'b1; scl_out <= 1'b1; end
            2'd3 : begin
                done    <=1'b1;
                busy    <=1'b0;
                state   <=S_IDLE;
            end
            endcase
            phase   <=  phase+1'b1;
        end
        

        S_REP_STOP:begin
            case(phase)
            2'd0 : begin scl_out <= 1'b0; sda_out <= 1'b1; end
            2'd1 : begin sda_out <= 1'b1; scl_out <= 1'b1; end
            2'd2 : begin sda_out <= 1'b0; scl_out <= 1'b1; end
            2'd3 : begin
                done      <= 1'b1;
                scl_out         <=  1'b0;
                shift_reg       <=  {address,rw};
                counter         <=  3'd7;
                state           <=  S_ADDR;
            end
            endcase
            phase   <=  phase   +1'b1;
        end
        endcase
    end
end            
end
endmodule





    
    
    

