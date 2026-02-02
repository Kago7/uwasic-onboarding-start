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

    // CDC SPI Bus Sync and edge detection (SPI_MODE_0)
    reg sclk_ff, sclk, sclk_prev, mosi_ff, mosi, cs_n_ff, cs_n;
    reg sclk_posedge;
    always @(posedge clk) begin
        sclk_ff      <= sclk_raw;
        sclk         <= sclk_ff;
        sclk_prev    <= sclk;
        mosi_ff      <= mosi_raw;
        mosi         <= mosi_ff;
        cs_n_ff      <= cs_n_raw;
        cs_n         <= cs_n_ff;
        sclk_posedge <= (sclk==1 & sclk_prev==0) ? 1 : 0;
    end

    // Main Control Logic
    reg transaction_ready;
    reg [15:0]  shift_reg;
    reg [3:0]   bit_counter;
    always @(posedge clk or negedge rst_n) begin
        if (rst_n) begin
            // Only operate when csn is active low
            if (!cs_n) begin
                // Shift data in as per SPI_MODE_0
                if (sclk_posedge) begin
                    shift_reg[15 - bit_counter] <= mosi;
                    bit_counter <= bit_counter + 1;
                end

                // Transaction ready only after 2 bytes
                if (bit_counter == 15) begin
                    transaction_ready <= 1;
                    bit_counter       <= 0; 
                end else begin
                    transaction_ready <= 0;
                end
            end else begin
                // Update on transaction ready
                if (transaction_ready) begin
                    // Handle the transaction only if it's a WRITE and ADDRESS in range.
                    if (shift_reg[15] && (shift_reg[14:8] <= MAX_ADDRESS)) begin
                        // Write data to registers
                        case(shift_reg[14:8])
                            7'h00   : en_reg_out_7_0    <= shift_reg[7:0];        
                            7'h01   : en_reg_out_15_8   <= shift_reg[7:0];        
                            7'h02   : en_reg_pwm_7_0    <= shift_reg[7:0];        
                            7'h03   : en_reg_pwm_15_8   <= shift_reg[7:0];        
                            7'h04   : pwm_duty_cycle    <= shift_reg[7:0];        
                            default :                                    ;
                        endcase
                    end else begin
                        en_reg_out_7_0  <= en_reg_out_7_0;
                        en_reg_out_15_8 <= en_reg_out_15_8;
                        en_reg_pwm_7_0  <= en_reg_pwm_7_0;
                        en_reg_pwm_15_8 <= en_reg_pwm_15_8;
                        pwm_duty_cycle  <= pwm_duty_cycle;
                    end
                end else begin
                    en_reg_out_7_0  <= en_reg_out_7_0;
                    en_reg_out_15_8 <= en_reg_out_15_8;
                    en_reg_pwm_7_0  <= en_reg_pwm_7_0;
                    en_reg_pwm_15_8 <= en_reg_pwm_15_8;
                    pwm_duty_cycle  <= pwm_duty_cycle;
                end

                // Reset transaction variables
                shift_reg         <= 0;
                bit_counter       <= 0; 
                transaction_ready <= 0;
            end
        end else begin
            // Reset all registers
            en_reg_out_7_0  <= 0;
            en_reg_out_15_8 <= 0;
            en_reg_pwm_7_0  <= 0;
            en_reg_pwm_15_8 <= 0;
            pwm_duty_cycle  <= 0;

            transaction_ready <= 0;
            shift_reg         <= 0;
            bit_counter       <= 0;
        end
    end

endmodule
