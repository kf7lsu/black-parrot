/**
 * bp_vcache.v
 *
 * Implements a victim cache used between the D$ and UCE in the softcore.
 * Parameterizable to varying sizes.
 */

module bp_vcache
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   ,parameter assoc_p = 4
   ,parameter sets_p = 64
   ,parameter block_width_p = 512
   ,parameter vcache_size=16
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   , localparam cache_req_width_lp = `bp_cache_req_width(dword_width_p, paddr_width_p) 
   , localparam cache_req_metadata_width_lp = `bp_cache_req_metadata_width(assoc_p)
   , localparam cache_tag_mem_pkt_width_lp = `bp_cache_tag_mem_pkt_width(sets_p, assoc_p, ptag_width_p)
   , localparam cache_data_mem_pkt_width_lp = `bp_cache_data_mem_pkt_width(sets_p, assoc_p, block_width_p)
   , localparam cache_stat_mem_pkt_width_lp = `bp_cache_stat_mem_pkt_width(sets_p, assoc_p)
   , localparam stat_info_width_lp = `bp_cache_stat_info_width(assoc_p)
    )
   (input                                            clk_i
    , input                                          reset_i

    , input [cache_req_width_lp-1:0]                 cache_req_i
    , output [cache_req_width_lp-1:0]                cache_req_ip //passthrough
    , input                                          cache_req_v_i
    , output                                         cache_req_v_ip //passthrough
    , output logic                                   cache_req_ready_o
    , input logic                                    cache_req_ready_op //passthrough
    , input [cache_req_metadata_width_lp-1:0]        cache_req_metadata_i
    , output [cache_req_metadata_width_lp-1:0]       cache_req_metadata_ip //passthrough
    , input                                          cache_req_metadata_v_i
    , output                                         cache_req_metadata_v_ip //passthrough
    , output logic                                   cache_req_complete_o
    , input logic                                    cache_req_complete_op //passthrough

    , output logic [cache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
    , input logic [cache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_op //passthrough
    , output logic                                   tag_mem_pkt_v_o
    , input logic                                   tag_mem_pkt_v_op //passthrough
    , input                                          tag_mem_pkt_yumi_i
    , output                                          tag_mem_pkt_yumi_ip //passthrough
    , input [ptag_width_p-1:0]                       tag_mem_i
    , output [ptag_width_p-1:0]                       tag_mem_ip //passthrough

    , output logic [cache_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input logic [cache_data_mem_pkt_width_lp-1:0] data_mem_pkt_op //passthrough
    , output logic                                   data_mem_pkt_v_o
    , input logic                                   data_mem_pkt_v_op //passthrough
    , input                                          data_mem_pkt_yumi_i
    , output                                          data_mem_pkt_yumi_ip //passthrough
    , input [block_width_p-1:0]                      data_mem_i
    , output [block_width_p-1:0]                      data_mem_ip //passthrough

    , output logic [cache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , input logic [cache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_op //passthrough
    , output logic                                   stat_mem_pkt_v_o
    , input logic                                   stat_mem_pkt_v_op //passthrough
    , input                                          stat_mem_pkt_yumi_i
    , output                                          stat_mem_pkt_yumi_ip //passthrough
    , input [stat_info_width_lp-1:0]                 stat_mem_i
    , output [stat_info_width_lp-1:0]                 stat_mem_ip //passthrough

    , output logic                                   credits_full_o
    , input logic                                   credits_full_op //passthrough
    , output logic                                   credits_empty_o
    , input logic                                   credits_empty_op //passthrough

    , output [cce_mem_msg_width_lp-1:0]              mem_cmd_o
    , input [cce_mem_msg_width_lp-1:0]              mem_cmd_op //passthrough
    , output logic                                   mem_cmd_v_o
    , input logic                                   mem_cmd_v_op //passthrough
    , input                                          mem_cmd_ready_i
    , output                                          mem_cmd_ready_ip //passthrough

    , input [cce_mem_msg_width_lp-1:0]               mem_resp_i
    , output [cce_mem_msg_width_lp-1:0]               mem_resp_ip //passthrough
    , input                                          mem_resp_v_i
    , output                                          mem_resp_v_ip //passthrough
    , output logic                                   mem_resp_yumi_o
    , input logic                                   mem_resp_yumi_op //passthrough
    );

    logic [cache_req_width_lp-1:0] cache_req_ip_log;
    logic cache_req_v_ip_log;

    assign cache_req_ip = cache_req_ip_log;
    assign cache_req_v_ip = cache_req_v_ip_log;

    always_comb begin
      cache_req_ip_log = cache_req_i;
      cache_req_v_ip_log = cache_req_v_i;
      cache_req_metadata_ip = cache_req_metadata_i;
      cache_req_metadata_v_ip = cache_req_metadata_v_i;
      cache_req_ready_o = cache_req_ready_op;
      cache_req_complete_o = cache_req_complete_op;

      tag_mem_pkt_yumi_ip = tag_mem_pkt_yumi_i;
      tag_mem_ip = tag_mem_i;
      tag_mem_pkt_o = tag_mem_pkt_op;
      tag_mem_pkt_v_o = tag_mem_pkt_v_op;

      data_mem_pkt_yumi_ip = data_mem_pkt_yumi_i;
      data_mem_ip = data_mem_i;
      data_mem_pkt_o = data_mem_pkt_op;
      data_mem_pkt_v_o = data_mem_pkt_v_op;

      stat_mem_pkt_yumi_ip = stat_mem_pkt_yumi_i;
      stat_mem_ip = stat_mem_i;
      stat_mem_pkt_o = stat_mem_pkt_op;
      stat_mem_pkt_v_o = stat_mem_pkt_v_op;

      credits_full_o = credits_full_op;
      credits_empty_o = credits_empty_op;

      mem_cmd_ready_ip = mem_cmd_ready_i;
      mem_cmd_o = mem_cmd_op;
      mem_cmd_v_o = mem_cmd_v_op;

      mem_resp_ip = mem_resp_i;
      mem_resp_v_ip = mem_resp_v_i;
      mem_resp_yumi_o = mem_resp_yumi_op;
    end

    always_ff @(posedge clk_i) begin
    end
endmodule
