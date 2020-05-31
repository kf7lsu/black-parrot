module bp_vc_generic
  #(parameter block_width
   ,parameter tag_width
   ,parameter stat_width
   ,parameter num_entries)
  (input			clk_i
  ,input			reset
  
  //interface for data evicted from D$
  ,input			evict_in
  ,input [block_width-1:0]	evict_data_in
  ,input [tag_width-1:0]	evict_tag_in
  ,input [stat_width-1:0]	evict_stat_in

  //interface to provide data to D$ (some management done in pipe stage)
  ,input [tag_width-1:0]	tag_r
  ,input			remove
  ,output logic			hit
  ,output [block_width-1:0]	data_o
  ,output [stat_width-1:0]	stat_o

  //interface to send evictions to UCE (some work done in pipe stage)
  ,output logic			evict
  ,output [block_width-1:0]	data_o_evict
  ,output [tag_width-1:0]	tag_o_evict
  ,output [stat_width-1:0]	stat_o_evict);

    logic [num_entries+1:0][block_width-1:0]	block_lines;
    logic [num_entries+1:0][tag_width-1:0]	tag_lines;
    logic [num_entries+1:0][stat_width-1:0]	stat_lines;
    logic [num_entries+1:0]			shift_l_ints, shift_r_ints;
    logic [num_entries-1:0]			tag_match_lines, shift_l_exts, shift_r_exts;

    //defining the edges
    assign block_lines[0] = evict_data_in;
    assign tag_lines[0] = evict_tag_in;
    assign stat_lines[0] = evict_stat_in;
    assign block_lines[num_entries+1] = 0;
    assign tag_lines[num_entries+1] = 0;
    assign stat_lines[num_entries+1] = 0;
    assign shift_l_ints[0] = 0;
    assign shift_r_ints[0] = 0;
    assign shift_l_ints[num_entries+1] = 0;
    assign shift_r_ints[num_entries+1] = 0;
    assign shift_r_exts[num_entries-1:1] = 0;
    assign shift_r_exts[0] = evict_in;
    assign data_o_evict = block_lines[num_entries];
    assign tag_o_evict = tag_lines[num_entries];
    assign stat_o_evict = stat_lines[num_entries];
    
    genvar i;
    generate
        for (i = 1; i <= num_entries; i++) begin
            always_comb begin
                tag_match_lines[i-1] = tag_r == tag_lines[i-1]; //one of these max should be true
		if (tag_match_lines[i-1]) begin
		    data_o = block_lines[i];
		    stat_o = stat_lines[i];
		    shift_l_exts[i-1] = remove;
		end
		else begin
		    shift_l_exts[i-1] = 0;
		end
            end
            bp_vc_cell 
              #(.block_width(block_width), 
                .tag_width(tag_width), 
                .stat_width(stat_width)) 
	    unit(  						     .clk_i, 
                                                                     .reset, 
                                                                     .data_l(block_lines[i-1]),
                                                                     .data_r(block_lines[i+1]),
                                                                     .tag_l(tag_lines[i-1]),
                                                                     .tag_r(tag_lines[i+1]),
                                                                     .stat_l(stat_lines[i-1]),
                                                                     .stat_r(stat_lines[i+1]),
                                                                     .shift_r(shift_r_exts[i-1]),
                                                                     .shift_l(shift_l_exts[i-1]),
                                                                     .shift_r_int(shift_r_ints[i-1]),
                                                                     .shift_l_int(shift_l_ints[i+1]),
                                                                     .shift_r_int_o(shift_r_ints[i]),
								     .shift_l_int_o(shift_l_ints[i]),
								     .data_o(block_lines[i]),
								     .tag_o(tag_lines[i]),
                                                                     .stat_o(stat_lines[i]));
        end
    endgenerate
    
    always_comb begin
        hit = tag_match_lines != 0;
	evict = stat_lines[num_entries] != 0 && evict_in;
    end
endmodule
