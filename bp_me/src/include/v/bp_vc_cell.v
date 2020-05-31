/*
 * bp_vc_cell.v
 * 
 * This file represents a single entry of the victim cache
 * it contains the necessary logic to hold data, as well as
 * shift the data to the left or right units
 *
 * The total unit contains a parameterized number of these in a
 * structure similar to a linked list
 */

module bp_vc_cell 
  #(parameter block_width,
    parameter tag_width,
    parameter stat_width)
   (input logic				clk_i
   ,input logic				reset

   ,input logic [block_width-1:0]	data_l, data_r
   ,input logic [tag_width-1:0]		tag_l, tag_r
   ,input logic [stat_width-1:0]	stat_l, stat_r
   ,input logic				shift_r, shift_l, shift_r_int, shift_l_int

   ,output logic			shift_r_int_o, shift_l_int_o
   ,output logic [block_width-1:0]	data_o
   ,output logic [tag_width-1:0]	tag_o
   ,output logic [stat_width-1:0]	stat_o);

    always_comb begin
        if (shift_r || shift_r_int) begin
            shift_r_int_o = 1'b1;
        end
        else begin
            shift_r_int_o = 1'b0;
        end
        if (shift_l || shift_l_int) begin
            shift_l_int_o = 1'b1;
        end
        else begin
            shift_l_int_o = 1'b0;
        end
    end
    always_ff @(posedge clk_i) begin
        if (reset) begin
            data_o <= 0;
            tag_o <= 0;
            stat_o <= 0;
        end
        else begin
            if (shift_l_int_o) begin
                data_o <= data_r;
                tag_o <= tag_r;
                stat_o <= stat_r;
            end
            else if (shift_r_int_o) begin
                data_o <= data_l;
                tag_o <= tag_l;
                stat_o <= stat_l;
            end
            else begin
                data_o <= data_o;
                tag_o <= tag_o;
                stat_o <= stat_o;
            end
        end
    end
endmodule
