

module bp_softcore
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_fe_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_me_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   )
  (input                                               clk_i
   , input                                             reset_i

   // Outgoing I/O
   , output [cce_mem_msg_width_lp-1:0]                 io_cmd_o
   , output                                            io_cmd_v_o
   , input                                             io_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]                  io_resp_i
   , input                                             io_resp_v_i
   , output                                            io_resp_yumi_o

   // Incoming I/O
   , input [cce_mem_msg_width_lp-1:0]                  io_cmd_i
   , input                                             io_cmd_v_i
   , output                                            io_cmd_yumi_o

   , output [cce_mem_msg_width_lp-1:0]                 io_resp_o
   , output                                            io_resp_v_o
   , input                                             io_resp_ready_i

   // Memory Requests
   , output [cce_mem_msg_width_lp-1:0]                 mem_cmd_o
   , output                                            mem_cmd_v_o
   , input                                             mem_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]                  mem_resp_i
   , input                                             mem_resp_v_i
   , output                                            mem_resp_yumi_o
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);

  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache);
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache);
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  `declare_bp_cache_stat_info_s(dcache_assoc_p, dcache);
  `declare_bp_cache_stat_info_s(icache_assoc_p, icache);

  `bp_cast_o(bp_cce_mem_msg_s, mem_cmd);
  `bp_cast_o(bp_cce_mem_msg_s, io_cmd);
  `bp_cast_i(bp_cce_mem_msg_s, mem_resp);
  `bp_cast_i(bp_cce_mem_msg_s, io_resp);

  bp_dcache_req_s dcache_req_lo, dcache_req_lop;
  bp_icache_req_s icache_req_lo;
  logic dcache_req_v_lo, dcache_req_v_lop, dcache_req_ready_li, dcache_req_ready_lip;
  logic icache_req_v_lo, icache_req_ready_li;

  bp_dcache_req_metadata_s dcache_req_metadata_lo, dcache_req_metadata_lop;
  bp_icache_req_metadata_s icache_req_metadata_lo;
  logic dcache_req_metadata_v_lo, dcache_req_metadata_v_lop, icache_req_metadata_v_lo;

  bp_dcache_tag_mem_pkt_s dcache_tag_mem_pkt_li, dcache_tag_mem_pkt_lip;
  bp_icache_tag_mem_pkt_s icache_tag_mem_pkt_li;
  logic dcache_tag_mem_pkt_v_li, dcache_tag_mem_pkt_v_lip, dcache_tag_mem_pkt_yumi_lo, dcache_tag_mem_pkt_yumi_lop;
  logic icache_tag_mem_pkt_v_li, icache_tag_mem_pkt_yumi_lo;
  logic [ptag_width_p-1:0] dcache_tag_mem_lo, dcache_tag_mem_lop, icache_tag_mem_lo;

  bp_dcache_data_mem_pkt_s dcache_data_mem_pkt_li, dcache_data_mem_pkt_lip;
  bp_icache_data_mem_pkt_s icache_data_mem_pkt_li;
  logic dcache_data_mem_pkt_v_li, dcache_data_mem_pkt_v_lip, dcache_data_mem_pkt_yumi_lo, dcache_data_mem_pkt_yumi_lop;
  logic icache_data_mem_pkt_v_li, icache_data_mem_pkt_yumi_lo;
  logic [dcache_block_width_p-1:0] dcache_data_mem_lo, dcache_data_mem_lop;
  logic [icache_block_width_p-1:0] icache_data_mem_lo;

  bp_dcache_stat_mem_pkt_s dcache_stat_mem_pkt_li, dcache_stat_mem_pkt_lip;
  bp_icache_stat_mem_pkt_s icache_stat_mem_pkt_li;
  logic dcache_stat_mem_pkt_v_li, dcache_stat_mem_pkt_v_lip, dcache_stat_mem_pkt_yumi_lo, dcache_stat_mem_pkt_yumi_lop;
  logic icache_stat_mem_pkt_v_li, icache_stat_mem_pkt_yumi_lo;
  bp_dcache_stat_info_s dcache_stat_mem_lo, dcache_stat_mem_lop;
  bp_icache_stat_info_s icache_stat_mem_lo;

  logic dcache_req_complete_li, dcache_req_complete_lip, icache_req_complete_li;

  logic [1:0] credits_full_li, credits_empty_li, credits_empty_lip, credits_full_lip;
  logic timer_irq_li, software_irq_li, external_irq_li;

  bp_cce_mem_msg_s [2:0] proc_cmd_lo, proc_cmd_lop;
  logic [2:0] proc_cmd_v_lo, proc_cmd_v_lop, proc_cmd_ready_li, proc_cmd_ready_lip;
  bp_cce_mem_msg_s [2:0] proc_resp_li, proc_resp_lip;
  logic [2:0] proc_resp_v_li, proc_resp_v_lip, proc_resp_yumi_lo, proc_resp_yumi_lop;

  bp_cce_mem_msg_s cfg_cmd_li;
  logic cfg_cmd_v_li, cfg_cmd_ready_lo;
  bp_cce_mem_msg_s cfg_resp_lo;
  logic cfg_resp_v_lo, cfg_resp_yumi_li;

  bp_cce_mem_msg_s clint_cmd_li;
  logic clint_cmd_v_li, clint_cmd_ready_lo;
  bp_cce_mem_msg_s clint_resp_lo;
  logic clint_resp_v_lo, clint_resp_yumi_li;

  bp_cce_mem_msg_s cache_cmd_li;
  logic cache_cmd_v_li, cache_cmd_ready_lo;
  bp_cce_mem_msg_s cache_resp_lo;
  logic cache_resp_v_lo, cache_resp_yumi_li;

  bp_cfg_bus_s cfg_bus_lo;
  logic [dword_width_p-1:0] cfg_irf_data_li;
  logic [vaddr_width_p-1:0] cfg_npc_data_li;
  logic [dword_width_p-1:0] cfg_csr_data_li;
  logic [1:0]               cfg_priv_data_li;
  logic [cce_instr_width_p-1:0] cfg_cce_ucode_data_li;

  bp_core_minimal
   #(.bp_params_p(bp_params_p))
   core
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_lo)
     ,.cfg_npc_data_o(cfg_npc_data_li)
     ,.cfg_irf_data_o(cfg_irf_data_li)
     ,.cfg_csr_data_o(cfg_csr_data_li)
     ,.cfg_priv_data_o(cfg_priv_data_li)

     ,.dcache_req_o(dcache_req_lo)
     ,.dcache_req_v_o(dcache_req_v_lo)
     ,.dcache_req_ready_i(dcache_req_ready_lip)
     ,.dcache_req_metadata_o(dcache_req_metadata_lo)
     ,.dcache_req_metadata_v_o(dcache_req_metadata_v_lo)
     ,.dcache_req_complete_i(dcache_req_complete_lip)

     ,.icache_req_o(icache_req_lo)
     ,.icache_req_v_o(icache_req_v_lo)
     ,.icache_req_ready_i(icache_req_ready_li)
     ,.icache_req_metadata_o(icache_req_metadata_lo)
     ,.icache_req_metadata_v_o(icache_req_metadata_v_lo)
     ,.icache_req_complete_i(icache_req_complete_li)

     ,.dcache_tag_mem_pkt_i(dcache_tag_mem_pkt_lip)
     ,.dcache_tag_mem_pkt_v_i(dcache_tag_mem_pkt_v_lip)
     ,.dcache_tag_mem_pkt_yumi_o(dcache_tag_mem_pkt_yumi_lo)
     ,.dcache_tag_mem_o(dcache_tag_mem_lo)

     ,.dcache_data_mem_pkt_i(dcache_data_mem_pkt_lip)
     ,.dcache_data_mem_pkt_v_i(dcache_data_mem_pkt_v_lip)
     ,.dcache_data_mem_pkt_yumi_o(dcache_data_mem_pkt_yumi_lo)
     ,.dcache_data_mem_o(dcache_data_mem_lo)

     ,.dcache_stat_mem_pkt_i(dcache_stat_mem_pkt_lip)
     ,.dcache_stat_mem_pkt_v_i(dcache_stat_mem_pkt_v_lip)
     ,.dcache_stat_mem_pkt_yumi_o(dcache_stat_mem_pkt_yumi_lo)
     ,.dcache_stat_mem_o(dcache_stat_mem_lo)

     ,.icache_tag_mem_pkt_i(icache_tag_mem_pkt_li)
     ,.icache_tag_mem_pkt_v_i(icache_tag_mem_pkt_v_li)
     ,.icache_tag_mem_pkt_yumi_o(icache_tag_mem_pkt_yumi_lo)
     ,.icache_tag_mem_o(icache_tag_mem_lo)

     ,.icache_data_mem_pkt_i(icache_data_mem_pkt_li)
     ,.icache_data_mem_pkt_v_i(icache_data_mem_pkt_v_li)
     ,.icache_data_mem_pkt_yumi_o(icache_data_mem_pkt_yumi_lo)
     ,.icache_data_mem_o(icache_data_mem_lo)

     ,.icache_stat_mem_pkt_i(icache_stat_mem_pkt_li)
     ,.icache_stat_mem_pkt_v_i(icache_stat_mem_pkt_v_li)
     ,.icache_stat_mem_pkt_yumi_o(icache_stat_mem_pkt_yumi_lo)
     ,.icache_stat_mem_o(icache_stat_mem_lo)

     ,.credits_full_i(|credits_full_li)
     ,.credits_empty_i(&credits_empty_li)

     ,.timer_irq_i(timer_irq_li)
     ,.software_irq_i(software_irq_li)
     ,.external_irq_i(external_irq_li)
     );

  wire [1:0][lce_id_width_p-1:0] lce_id_li = {cfg_bus_lo.dcache_id, cfg_bus_lo.icache_id};

  bp_vcache
    #(.bp_params_p(bp_params_p)
     ,.assoc_p(dcache_assoc_p)
     ,.sets_p(dcache_sets_p)
     ,.block_width_p(dcache_block_width_p))
    dcache_vcache
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.cache_req_i(dcache_req_lo)
    ,.cache_req_ip(dcache_req_lop)
    ,.cache_req_v_i(dcache_req_v_lo)
    ,.cache_req_v_ip(dcache_req_v_lop)
    ,.cache_req_ready_o(dcache_req_ready_lip)
    ,.cache_req_ready_op(dcache_req_ready_li)
    ,.cache_req_metadata_i(dcache_req_metadata_lo)
    ,.cache_req_metadata_ip(dcache_req_metadata_lop)
    ,.cache_req_metadata_v_i(dcache_req_metadata_v_lo)
    ,.cache_req_metadata_v_ip(dcache_req_metadata_v_lop)

    ,.tag_mem_pkt_o(dcache_tag_mem_pkt_lip)
    ,.tag_mem_pkt_op(dcache_tag_mem_pkt_li)
    ,.tag_mem_pkt_v_o(dcache_tag_mem_pkt_v_lip)
    ,.tag_mem_pkt_v_op(dcache_tag_mem_pkt_v_li)
    ,.tag_mem_pkt_yumi_i(dcache_tag_mem_pkt_yumi_lo)
    ,.tag_mem_pkt_yumi_ip(dcache_tag_mem_pkt_yumi_lop)
    ,.tag_mem_i(dcache_tag_mem_lo)
    ,.tag_mem_ip(dcache_tag_mem_lop)

    ,.data_mem_pkt_o(dcache_data_mem_pkt_lip)
    ,.data_mem_pkt_op(dcache_data_mem_pkt_li)
    ,.data_mem_pkt_v_o(dcache_data_mem_pkt_v_lip)
    ,.data_mem_pkt_v_op(dcache_data_mem_pkt_v_li)
    ,.data_mem_pkt_yumi_i(dcache_data_mem_pkt_yumi_lo)
    ,.data_mem_pkt_yumi_ip(dcache_data_mem_pkt_yumi_lop)
    ,.data_mem_i(dcache_data_mem_lo)
    ,.data_mem_ip(dcache_data_mem_lop)

    ,.stat_mem_pkt_o(dcache_stat_mem_pkt_lip)
    ,.stat_mem_pkt_op(dcache_stat_mem_pkt_li)
    ,.stat_mem_pkt_v_o(dcache_stat_mem_pkt_v_lip)
    ,.stat_mem_pkt_v_op(dcache_stat_mem_pkt_v_li)
    ,.stat_mem_pkt_yumi_i(dcache_stat_mem_pkt_yumi_lo)
    ,.stat_mem_pkt_yumi_ip(dcache_stat_mem_pkt_yumi_lop)
    ,.stat_mem_i(dcache_stat_mem_lo)
    ,.stat_mem_ip(dcache_stat_mem_lop)

    ,.cache_req_complete_o(dcache_req_complete_lip)
    ,.cache_req_complete_op(dcache_req_complete_li)

    ,.credits_full_o(credits_full_li[1])
    ,.credits_full_op(credits_full_lip[1])
    ,.credits_empty_o(credits_empty_li[1])
    ,.credits_empty_op(credits_empty_lip[1])

    ,.mem_cmd_o(proc_cmd_lo[1])
    ,.mem_cmd_op(proc_cmd_lop[1])
    ,.mem_cmd_v_o(proc_cmd_v_lo[1])
    ,.mem_cmd_v_op(proc_cmd_v_lop[1])
    ,.mem_cmd_ready_i(proc_cmd_ready_li[1])
    ,.mem_cmd_ready_ip(proc_cmd_ready_lip[1])

    ,.mem_resp_i(proc_resp_li[1])
    ,.mem_resp_ip(proc_resp_lip[1])
    ,.mem_resp_v_i(proc_resp_v_li[1])
    ,.mem_resp_v_ip(proc_resp_v_lip[1])
    ,.mem_resp_yumi_o(proc_resp_yumi_lo[1])
    ,.mem_resp_yumi_op(proc_resp_yumi_lop[1])
    );

  bp_uce
    #(.bp_params_p(bp_params_p)
     ,.assoc_p(dcache_assoc_p)
     ,.sets_p(dcache_sets_p)
     ,.block_width_p(dcache_block_width_p))
    dcache_uce
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_id_i(lce_id_li[1])

    ,.cache_req_i(dcache_req_lop)
    ,.cache_req_v_i(dcache_req_v_lop)
    ,.cache_req_ready_o(dcache_req_ready_li)
    ,.cache_req_metadata_i(dcache_req_metadata_lop)
    ,.cache_req_metadata_v_i(dcache_req_metadata_v_lop)

    ,.tag_mem_pkt_o(dcache_tag_mem_pkt_li)
    ,.tag_mem_pkt_v_o(dcache_tag_mem_pkt_v_li)
    ,.tag_mem_pkt_yumi_i(dcache_tag_mem_pkt_yumi_lop)
    ,.tag_mem_i(dcache_tag_mem_lop)

    ,.data_mem_pkt_o(dcache_data_mem_pkt_li)
    ,.data_mem_pkt_v_o(dcache_data_mem_pkt_v_li)
    ,.data_mem_pkt_yumi_i(dcache_data_mem_pkt_yumi_lop)
    ,.data_mem_i(dcache_data_mem_lop)

    ,.stat_mem_pkt_o(dcache_stat_mem_pkt_li)
    ,.stat_mem_pkt_v_o(dcache_stat_mem_pkt_v_li)
    ,.stat_mem_pkt_yumi_i(dcache_stat_mem_pkt_yumi_lop)
    ,.stat_mem_i(dcache_stat_mem_lop)

    ,.cache_req_complete_o(dcache_req_complete_li)

    ,.credits_full_o(credits_full_lip[1])
    ,.credits_empty_o(credits_empty_lip[1])

    ,.mem_cmd_o(proc_cmd_lop[1])
    ,.mem_cmd_v_o(proc_cmd_v_lop[1])
    ,.mem_cmd_ready_i(proc_cmd_ready_lip[1])

    ,.mem_resp_i(proc_resp_lip[1])
    ,.mem_resp_v_i(proc_resp_v_lip[1])
    ,.mem_resp_yumi_o(proc_resp_yumi_lop[1])
    );

  bp_uce
    #(.bp_params_p(bp_params_p)
     ,.assoc_p(icache_assoc_p)
     ,.sets_p(icache_sets_p)
     ,.block_width_p(icache_block_width_p))
    icache_uce
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_id_i(lce_id_li[0])

    ,.cache_req_i(icache_req_lo)
    ,.cache_req_v_i(icache_req_v_lo)
    ,.cache_req_ready_o(icache_req_ready_li)
    ,.cache_req_metadata_i(icache_req_metadata_lo)
    ,.cache_req_metadata_v_i(icache_req_metadata_v_lo)

    ,.tag_mem_pkt_o(icache_tag_mem_pkt_li)
    ,.tag_mem_pkt_v_o(icache_tag_mem_pkt_v_li)
    ,.tag_mem_pkt_yumi_i(icache_tag_mem_pkt_yumi_lo)
    ,.tag_mem_i(icache_tag_mem_lo)

    ,.data_mem_pkt_o(icache_data_mem_pkt_li)
    ,.data_mem_pkt_v_o(icache_data_mem_pkt_v_li)
    ,.data_mem_pkt_yumi_i(icache_data_mem_pkt_yumi_lo)
    ,.data_mem_i(icache_data_mem_lo)

    ,.stat_mem_pkt_o(icache_stat_mem_pkt_li)
    ,.stat_mem_pkt_v_o(icache_stat_mem_pkt_v_li)
    ,.stat_mem_pkt_yumi_i(icache_stat_mem_pkt_yumi_lo)
    ,.stat_mem_i(icache_stat_mem_lo)

    ,.cache_req_complete_o(icache_req_complete_li)

    ,.credits_full_o(credits_full_li[0])
    ,.credits_empty_o(credits_empty_li[0])

    ,.mem_cmd_o(proc_cmd_lo[0])
    ,.mem_cmd_v_o(proc_cmd_v_lo[0])
    ,.mem_cmd_ready_i(proc_cmd_ready_li[0])

    ,.mem_resp_i(proc_resp_li[0])
    ,.mem_resp_v_i(proc_resp_v_li[0])
    ,.mem_resp_yumi_o(proc_resp_yumi_lo[0])
    );

  bp_clint_slice
   #(.bp_params_p(bp_params_p))
   clint
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(clint_cmd_li)
     ,.mem_cmd_v_i(clint_cmd_v_li)
     ,.mem_cmd_ready_o(clint_cmd_ready_lo)

     ,.mem_resp_o(clint_resp_lo)
     ,.mem_resp_v_o(clint_resp_v_lo)
     ,.mem_resp_yumi_i(clint_resp_yumi_li)

     ,.timer_irq_o(timer_irq_li)
     ,.software_irq_o(software_irq_li)
     ,.external_irq_o(external_irq_li)
     );

  bp_cfg
   #(.bp_params_p(bp_params_p))
   cfg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(cfg_cmd_li)
     ,.mem_cmd_v_i(cfg_cmd_v_li)
     ,.mem_cmd_ready_o(cfg_cmd_ready_lo)

     ,.mem_resp_o(cfg_resp_lo)
     ,.mem_resp_v_o(cfg_resp_v_lo)
     ,.mem_resp_yumi_i(cfg_resp_yumi_li)

     ,.cfg_bus_o(cfg_bus_lo)
     ,.did_i('0)
     ,.host_did_i('0)
     ,.cord_i({coh_noc_y_cord_width_p'(1), coh_noc_x_cord_width_p'(0)})
     ,.irf_data_i(cfg_irf_data_li)
     ,.npc_data_i(cfg_npc_data_li)
     ,.csr_data_i(cfg_csr_data_li)
     ,.priv_data_i(cfg_priv_data_li)
     ,.cce_ucode_data_i('0)
     );

  // Assign incoming I/O as basically another UCE interface
  assign proc_cmd_lo[2] = io_cmd_i;
  assign proc_cmd_v_lo[2] = io_cmd_v_i;
  assign io_cmd_yumi_o = proc_cmd_ready_li[2] & proc_cmd_v_lo[2];

  assign io_resp_o = proc_resp_li[2];
  assign io_resp_v_o = proc_resp_v_li[2];
  assign proc_resp_yumi_lo[2] = io_resp_ready_i & io_resp_v_o;

  // Command/response FIFOs for timing and helpfulness
  bp_cce_mem_msg_s [2:0] cmd_fifo_lo;
  logic [2:0] cmd_fifo_v_lo, cmd_fifo_yumi_li;
  
  bp_cce_mem_msg_s [2:0] resp_fifo_li;
  logic [2:0] resp_fifo_v_li, resp_fifo_ready_lo;

  for (genvar i = 0; i < 3; i++)
    begin : fifo
      bsg_two_fifo
       #(.width_p($bits(bp_cce_mem_msg_s)))
       cmd_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(proc_cmd_lo[i])
         ,.v_i(proc_cmd_v_lo[i])
         ,.ready_o(proc_cmd_ready_li[i])

         ,.data_o(cmd_fifo_lo[i])
         ,.v_o(cmd_fifo_v_lo[i])
         ,.yumi_i(cmd_fifo_yumi_li[i])
         );

      bsg_two_fifo
       #(.width_p($bits(bp_cce_mem_msg_s)))
       resp_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(resp_fifo_li[i])
         ,.v_i(resp_fifo_v_li[i])
         ,.ready_o(resp_fifo_ready_lo[i])

         ,.data_o(proc_resp_li[i])
         ,.v_o(proc_resp_v_li[i])
         ,.yumi_i(proc_resp_yumi_lo[i])
         );
    end

  // Command arbitration logic
  // This is suboptimal for performance, because a blocked I/O channel will put backpressure on the
  //   cache.
  wire cmd_arb_ready_li = &{cfg_cmd_ready_lo, clint_cmd_ready_lo, io_cmd_ready_i, cache_cmd_ready_lo};
  bsg_arb_fixed
   #(.inputs_p(3), .lo_to_hi_p(0))
   cmd_arbiter
    (.ready_i(cmd_arb_ready_li)
     ,.reqs_i(cmd_fifo_v_lo)
     ,.grants_o(cmd_fifo_yumi_li)
     );

  bp_cce_mem_msg_s cmd_fifo_selected_lo;
  bsg_mux_one_hot
   #(.width_p($bits(bp_cce_mem_msg_s)), .els_p(3))
   cmd_select
    (.data_i(cmd_fifo_lo)
     ,.sel_one_hot_i(cmd_fifo_yumi_li)
     ,.data_o(cmd_fifo_selected_lo)
     );
  assign {cache_cmd_li, io_cmd_cast_o, clint_cmd_li, cfg_cmd_li} = {4{cmd_fifo_selected_lo}};

  // Response arbitration logic
  // UCEs may send two commands as part of a writeback routine. Responses can come back in
  //   arbitrary orders, especially when considering CLINT or I/O responses
  // This is also suboptimal. Theoretically, we could dequeue into each fifo at once, but this
  //   would require more complex arbitration logic
  wire resp_arb_ready_li = &resp_fifo_ready_lo;
  bsg_arb_fixed
   #(.inputs_p(4), .lo_to_hi_p(0))
   resp_arbiter
    (.ready_i(resp_arb_ready_li)
     ,.reqs_i({cache_resp_v_lo, io_resp_v_i, clint_resp_v_lo, cfg_resp_v_lo})
     ,.grants_o({cache_resp_yumi_li, io_resp_yumi_o, clint_resp_yumi_li, cfg_resp_yumi_li})
     );
    
  for (genvar i = 0; i < 3; i++)
    begin : resp_match
      bp_cce_mem_msg_s resp_fifo_selected_li;
      bsg_mux_one_hot
       #(.width_p($bits(bp_cce_mem_msg_s)), .els_p(4))
       resp_select
        (.data_i({cache_resp_lo, io_resp_i, clint_resp_lo, cfg_resp_lo})
         ,.sel_one_hot_i({cache_resp_yumi_li, io_resp_yumi_o, clint_resp_yumi_li, cfg_resp_yumi_li})
         ,.data_o(resp_fifo_selected_li)
         );
      wire resp_selected_v_li = |{cache_resp_yumi_li, io_resp_yumi_o, clint_resp_yumi_li, cfg_resp_yumi_li};

      assign resp_fifo_v_li[i] = resp_selected_v_li & (resp_fifo_selected_li.header.payload.lce_id == i);
      assign resp_fifo_li[i] = resp_fifo_selected_li;
    end

  /* TODO: Extract local memory map to module */
  wire local_cmd_li        = (cmd_fifo_selected_lo.header.addr < dram_base_addr_gp);
  wire [3:0] device_cmd_li = cmd_fifo_selected_lo.header.addr[20+:4];
  wire is_cfg_cmd          = local_cmd_li & (device_cmd_li == cfg_dev_gp);
  wire is_clint_cmd        = local_cmd_li & (device_cmd_li == clint_dev_gp);
  wire is_io_cmd           = local_cmd_li & (device_cmd_li == host_dev_gp);
  wire is_cache_cmd        = ~local_cmd_li || (local_cmd_li & (device_cmd_li == cache_dev_gp));

  assign cfg_cmd_v_li   = is_cfg_cmd   & |cmd_fifo_yumi_li;
  assign clint_cmd_v_li = is_clint_cmd & |cmd_fifo_yumi_li;
  assign io_cmd_v_o     = is_io_cmd    & |cmd_fifo_yumi_li;
  assign cache_cmd_v_li = is_cache_cmd & |cmd_fifo_yumi_li;

  if (l2_en_p)
    begin : l2
      logic mem_resp_ready_lo;
      bp_me_cache_slice
       #(.bp_params_p(bp_params_p))
       l2s
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.mem_cmd_i(cache_cmd_li)
         ,.mem_cmd_v_i(cache_cmd_v_li)
         ,.mem_cmd_ready_o(cache_cmd_ready_lo)

         ,.mem_resp_o(cache_resp_lo)
         ,.mem_resp_v_o(cache_resp_v_lo)
         ,.mem_resp_yumi_i(cache_resp_yumi_li)

         ,.mem_cmd_o(mem_cmd_cast_o)
         ,.mem_cmd_v_o(mem_cmd_v_o)
         ,.mem_cmd_yumi_i(mem_cmd_ready_i & mem_cmd_v_o)

         ,.mem_resp_i(mem_resp_cast_i)
         ,.mem_resp_v_i(mem_resp_v_i)
         ,.mem_resp_ready_o(mem_resp_ready_lo)
         );
      assign mem_resp_yumi_o = mem_resp_ready_lo & mem_resp_v_i;
    end
  else
    begin : no_l2
      assign mem_cmd_cast_o = cache_cmd_li;
      assign mem_cmd_v_o = cache_cmd_v_li;
      assign cache_cmd_ready_lo = mem_cmd_ready_i;

      assign cache_resp_lo = mem_resp_cast_i;
      assign cache_resp_v_lo = mem_resp_v_i;
      assign mem_resp_yumi_o = cache_resp_yumi_li;
    end

endmodule

