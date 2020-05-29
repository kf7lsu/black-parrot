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
  ,output			hit
  ,output [block_width-1:0]	data_o
  ,output [stat_width-1:0]	stat_o

  //interface to send evictions to UCE (some work done in pipe stage)
  ,output 			evict
  ,output [block_width-1:0]	data_o_evict
  ,output [tag_width-1:0]	tag_o_evict
  ,output [stat_width-1:0]	stat_o_evict);

    logic [num_entries:0][block_width-1:0]	block_lines;
    logic [num_entries:0][tag_width-1:0]	tag_lines;
    logic [num_entries:0][block_width-1:0]	block_lines;
    logic [num_entries:0][block_width-1:0]	block_lines;
endmodule
