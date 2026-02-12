`default_nettype none

module spi_peripheral #(
    // PARAMETERS
    parameter MAX_ADDRESS = 7'h04
)(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            sclk_raw,
    input   wire            mosi_raw,
    input   wire            cs_n_raw,
    output  reg     [7:0]   en_reg_out_7_0,
    output  reg     [7:0]   en_reg_out_15_8,
    output  reg     [7:0]   en_reg_pwm_7_0,
    output  reg     [7:0]   en_reg_pwm_15_8,
    output  reg     [7:0]   pwm_duty_cycle
);

    // CDC SPI Bus Sync and edge detection registers (SPI_MODE_0)
    reg sclk_ff, sclk, sclk_prev, mosi_ff, mosi, cs_n_ff, cs_n;
    reg sclk_posedge;
    assign sclk_posedge = (sclk & ~sclk_prev);

    // Main Control Logic
    reg [15:0]  shift_reg;
    reg [3:0]   bit_counter;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            en_reg_out_7_0    <= 0;
            en_reg_out_15_8   <= 0;
            en_reg_pwm_7_0    <= 0;
            en_reg_pwm_15_8   <= 0;
            pwm_duty_cycle    <= 0;

            sclk_ff           <= 0;
            sclk              <= 0; 
            sclk_prev         <= 0; 
            mosi_ff           <= 0; 
            mosi              <= 0; 
            cs_n_ff           <= 1; 
            cs_n              <= 1;

            shift_reg         <= 0;
            bit_counter       <= 0;

        end else begin
            // CDC SPI Bus Sync
            sclk_ff      <= sclk_raw;
            sclk         <= sclk_ff;
            sclk_prev    <= sclk;
            mosi_ff      <= mosi_raw;
            mosi         <= mosi_ff;
            cs_n_ff      <= cs_n_raw;
            cs_n         <= cs_n_ff;

            // Only operate SPI when csn is active low
            if (!cs_n) begin
                // Shift data in as per SPI_MODE_0
                if (sclk_posedge) begin
                    shift_reg[15 - bit_counter] <= mosi;
                    bit_counter <= bit_counter + 1;
                end

            end else begin
                // Update on after transaction is done (16bits)
                if (bit_counter==0) begin
                    // Handle the transaction only if it's a WRITE and ADDRESS in range.
                    if (shift_reg[15] && (shift_reg[14:8] <= MAX_ADDRESS)) begin
                        // Write data to registers
                        case(shift_reg[10:8])
                            3'h0   : en_reg_out_7_0    <= shift_reg[7:0];        
                            3'h1   : en_reg_out_15_8   <= shift_reg[7:0];        
                            3'h2   : en_reg_pwm_7_0    <= shift_reg[7:0];        
                            3'h3   : en_reg_pwm_15_8   <= shift_reg[7:0];        
                            3'h4   : pwm_duty_cycle    <= shift_reg[7:0];        
                            default :                                    ;
                        endcase
                    end
                end

                // Reset transaction variables
                bit_counter       <= 0; 
                shift_reg         <= 0; 
            end
        end
    end

endmodule
