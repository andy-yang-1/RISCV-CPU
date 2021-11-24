// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "constant.v"

`timescale 1ns/1ps

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

wire RS_FULL ;
wire LSB_FULL ;
wire ROB_FULL ;

wire [`ROBTagBus] next_tag ;  // rob empty pos
wire [`ROBTagBus] now_tag ; // rob head pos

wire clear ;

wire rs_rdy ;
wire lsb_rdy ;

wire ROB_LSB_enable_write ;
wire ROB_LSB_enable_IO ;


wire [`AddrBus] fetch_mem_addr ;
wire mem_fetch_rdy ;
wire [`ByteBus] mem_byte ;
wire [`AddrBus] ROB_fetch_next_pc ;
wire [`InstBus] fetch_decode_inst ;
wire [`AddrBus] fetch_decode_npc ;
wire fetch_dispatch_rdy ;

wire [`ByteBus] LSB_mem_write_data ;
wire LSB_mem_wr ;
wire LSB_mem_in_need ;
wire [`AddrBus] LSB_mem_req_addr ;
wire IO_is_writing ;

fetch fetch_part(

  .clk_in(clk_in),
  .rdy_in(rdy_in),
  .rst_in(rst_in),

  .change_pc(clear),
  .next_pc(ROB_fetch_next_pc),

  .ROB_FULL(ROB_FULL),
  .RS_FULL(RS_FULL),
  .IO_is_writing(IO_is_writing) ,
  .LSB_FULL(LSB_FULL),

  .mem_rdy(mem_fetch_rdy),
  .mem_byte(mem_byte),
  .req_addr(fetch_mem_addr),

  .fetch_rdy(fetch_dispatch_rdy),
  .inst(fetch_decode_inst),
  .npc(fetch_decode_npc)

);


mem_ctrl mem_ctrl_part( 

  .clk_in(clk_in),
  .rdy_in(rdy_in),
  .rst_in(rst_in),

  .fetch_req_addr(fetch_mem_addr),

  .LSB_mem_in_need(LSB_mem_in_need),
  .LSB_req_addr(LSB_mem_req_addr),
  .LSB_mem_wr(LSB_mem_wr),
  .LSB_write_data(LSB_mem_write_data),

  .mem_din(mem_din),
  
  .mem_a(mem_a),
  .mem_dout(mem_dout),
  .mem_wr(mem_wr),

  .fetch_mem_rdy(mem_fetch_rdy),
  .IO_is_writing(IO_is_writing),
  .mem_byte(mem_byte)

);

wire [`InstBus]       decode_dispatch_inst ;        
wire [`AddrBus]       decode_dispatch_npc ;         
wire  [`RegBus]       decode_dispatch_rs1 ;         
wire                  decode_dispatch_rs1_in_need ;
wire  [`RegBus]       decode_dispatch_rs2 ;
wire                  decode_dispatch_rs2_in_need ; 
wire  [`RegBus]       decode_dispatch_rd ;
wire                  decode_dispatch_rd_in_need ;
wire                  decode_dispatch_mem_in_need ;
wire  [`ImmediateBus] decode_dispatch_imme ;

decode decode_part(
  .clk_in      (clk_in      ),
  .rdy_in      (rdy_in      ),
  .rst_in      (rst_in      ),
  .up_inst     (  fetch_decode_inst   ),
  .up_npc      (  fetch_decode_npc ),
  .to_inst     (decode_dispatch_inst     ),
  .to_npc      (decode_dispatch_npc     ),
  .to_rs1      (decode_dispatch_rs1      ),
  .rs1_in_need (decode_dispatch_rs1_in_need ),
  .to_rs2      (decode_dispatch_rs2      ),
  .rs2_in_need (decode_dispatch_rs2_in_need ),
  .to_rd       (decode_dispatch_rd       ),
  .rd_in_need  (decode_dispatch_rd_in_need  ),
  .mem_in_need (decode_dispatch_mem_in_need ),
  .to_imme     (decode_dispatch_imme     )
);

wire [`RegBus] dispatch_reg_rs1 ; 
wire dispatch_reg_rs1_in_need ;
wire [`RegBus] dispatch_reg_rs2 ;
wire dispatch_reg_rs2_in_need ;
wire [`RegBus] dispatch_down_rd ;
wire dispatch_down_rd_in_need ;
wire[`InstBus] dispatch_down_inst ;
wire[`AddrBus] dispatch_down_npc ;
wire [`ImmediateBus] dispatch_down_imme ;
wire dispatch_rs_rdy ;
wire dispatch_lsb_rdy ;
wire dispatch_rob_rdy ;

dispatch dispatch_part(
  .clk_in           (clk_in           ),
  .rdy_in           (rdy_in           ),
  .rst_in           (rst_in           ),
  .fetch_rdy        (fetch_dispatch_rdy        ),
  .up_inst          (decode_dispatch_inst          ),
  .up_npc           (decode_dispatch_npc           ),
  .up_rs1           (decode_dispatch_rs1           ),
  .up_rs1_in_need   (decode_dispatch_rs1_in_need   ),
  .up_rs2           (decode_dispatch_rs2           ),
  .up_rs2_in_need   (decode_dispatch_rs2_in_need   ),
  .up_rd            (decode_dispatch_rd            ),
  .up_rd_in_need    (decode_dispatch_rd_in_need    ),
  .mem_in_need      (decode_dispatch_mem_in_need     ),
  .up_imme          (decode_dispatch_imme          ),
  .clear (clear),
  .to_rs1           (dispatch_reg_rs1           ),
  .to_rs1_in_need   (dispatch_reg_rs1_in_need   ),
  .to_rs2           (dispatch_reg_rs2          ),
  .to_rs2_in_need   (dispatch_reg_rs2_in_need  ),
  .to_rd            (dispatch_down_rd            ),
  .to_rd_in_need    (dispatch_down_rd_in_need    ),
  .to_inst          (dispatch_down_inst          ),
  .to_npc           (dispatch_down_npc          ),
  .to_imme          (dispatch_down_imme          ),
  .dispatch_rs_rdy  (dispatch_rs_rdy  ),
  .dispatch_lsb_rdy (dispatch_lsb_rdy ),
  .dispatch_rob_rdy (dispatch_rob_rdy )
);
 
wire [`RegValBus] ROB_reg_write_val ;
wire [`RegBus] ROB_reg_rd ; 
wire ROB_reg_write_rdy ; 
wire commit_pulse ;
wire [`RegValBus] rs1_val ; 
wire [`ROBTagBus] rs1_rely ;
wire [`RegValBus] rs2_val  ;
wire [`ROBTagBus] rs2_rely ;

regFile regFile_part(
  .clk_in              (clk_in              ),
  .rdy_in              (rdy_in              ),
  .rst_in              (rst_in              ),
  .rs1                 (dispatch_reg_rs1                 ),
  .rs1_read_rdy        (dispatch_reg_rs1_in_need        ),
  .rs2                 (dispatch_reg_rs2                 ),
  .rs2_read_rdy        (dispatch_reg_rs2_in_need        ),
  .dispatch_rd         (dispatch_down_rd         ),
  .dispatch_rd_in_need (dispatch_down_rd_in_need ),
  .next_tag            (next_tag            ),
  .now_tag             (now_tag             ),
  .clear               (clear               ),
  .write_val           (ROB_reg_write_val           ),
  .rd                  (ROB_reg_rd                   ),
  .write_rdy           (ROB_reg_write_rdy           ),

`ifdef debug_show  
  .commit_pulse        (commit_pulse        ),
  .commit_pc            ( ROB_fetch_next_pc ) ,
`endif  

  .rs1_val             (rs1_val             ),
  .rs1_rely            (rs1_rely            ),
  .rs2_val             (rs2_val             ),
  .rs2_rely            (rs2_rely            )
);

// CDB
wire ROB_rs1_valid ;
wire ROB_rs1_mem_in_need ;
wire [`ALUOutputBus] ROB_rs1_ans_output ;
wire ROB_rs2_valid ;
wire [`ALUOutputBus] ROB_rs2_ans_output ;
   
wire [`ALUOutputBus] CDB_RS_alu_output ;
wire [`ROBTagBus] CDB_RS_tag ;
wire [`ROBTagBus] CDB_LSB_tag ;
wire [`LMDOutputBus] CDB_LSB_lmd_output ;


wire [`InstBus]       RS_alu_inst ;
wire [`AddrBus]       RS_alu_npc ;
wire [`RegValBus]     RS_alu_rs1_val ;
wire [`RegValBus]     RS_alu_rs2_val ; 
wire [`ImmediateBus]  RS_alu_imme ;
wire [`ROBTagBus]     RS_alu_tag_bus ;

RS RS_part(
  .clk_in              (clk_in              ),
  .rdy_in              (rdy_in              ),
  .rst_in              (rst_in              ),
  .rs1_val             (rs1_val             ),
  .rs1_rely            (rs1_rely            ),
  .rs2_val             (rs2_val             ),
  .rs2_rely            (rs2_rely            ),
  .next_tag            (next_tag            ),
  .clear               (clear               ),
  .ROB_rs1_valid       (ROB_rs1_valid       ),
  .ROB_rs1_ans_output  (ROB_rs1_ans_output  ),
  .ROB_rs2_valid       (ROB_rs2_valid       ),
  .ROB_rs2_ans_output  (ROB_rs2_ans_output  ),
  .ROB_write_reg_rdy(ROB_reg_write_rdy),
  .ROB_write_val(ROB_reg_write_val),
  .ROB_head_tag(now_tag),
  .dispatch_rdy        (dispatch_rs_rdy        ),
  .up_inst             (dispatch_down_inst             ),
  .up_npc              (dispatch_down_npc             ),
  .up_imme             (dispatch_down_imme             ),
  .to_inst             (RS_alu_inst             ),
  .to_npc              (RS_alu_npc              ),
  .to_rs1_val          (RS_alu_rs1_val          ),
  .to_rs2_val          (RS_alu_rs2_val          ),
  .to_imme             (RS_alu_imme             ),
  .to_tag_bus          (RS_alu_tag_bus          ),
  .RS_FULL             (RS_FULL             ),
  .rs_rdy              (rs_rdy              )
);


LSB LSB_part(
  .clk_in              (clk_in              ),
  .rdy_in              (rdy_in              ),
  .rst_in              (rst_in              ),
  .io_buffer_full      (io_buffer_full      ),
  .rs1_val             (rs1_val             ),
  .rs1_rely            (rs1_rely            ),
  .rs2_val             (rs2_val             ),
  .rs2_rely            (rs2_rely            ),
  .next_tag            (next_tag            ),
  .enable_write        (ROB_LSB_enable_write        ),
  .enable_IO           (ROB_LSB_enable_IO),
  .clear               (clear               ),
  .ROB_rs1_valid       (ROB_rs1_valid       ),
  .ROB_rs1_ans_output  (ROB_rs1_ans_output  ),
  .ROB_rs2_valid       (ROB_rs2_valid       ),
  .ROB_rs2_ans_output  (ROB_rs2_ans_output  ),
  .ROB_write_reg_rdy(ROB_reg_write_rdy),
  .ROB_write_val(ROB_reg_write_val),
  .ROB_head_tag(now_tag),
  .dispatch_rdy        (dispatch_lsb_rdy        ),
  .up_inst             (dispatch_down_inst             ),
  .up_imme             (dispatch_down_imme             ),
  .mem_byte            (mem_byte            ),
  .req_addr            (LSB_mem_req_addr            ),
  .write_data          (LSB_mem_write_data          ),
  .LSB_mem_in_need     (LSB_mem_in_need     ),
  .mem_wr              (LSB_mem_wr              ),
  .LSB_FULL            (LSB_FULL            ),
  .to_lmd_output       (CDB_LSB_lmd_output       ),
  .to_tag_bus          (CDB_LSB_tag          ),
  .lsb_rdy             (lsb_rdy             )
);

wire [`AddrBus] alu_npc ;

alu alu_part(
  .clk_in        (clk_in        ),
  .rdy_in        (rdy_in        ),
  .rst_in        (rst_in        ),
  .up_inst       (RS_alu_inst       ),
  .up_npc        (RS_alu_npc        ),
  .up_rs1_val    (RS_alu_rs1_val    ),
  .up_rs2_val    (RS_alu_rs2_val    ),
  .up_imme       (RS_alu_imme       ),
  .up_tag_bus    (RS_alu_tag_bus    ),
  .rs_tag_bus    (CDB_RS_tag    ),
  .to_alu_output (CDB_RS_alu_output ),
  .to_npc        (alu_npc        )
);

ROB ROB_part(
  .clk_in              (clk_in              ),
  .rdy_in              (rdy_in              ),
  .rst_in              (rst_in              ),
  .rs1_rely            (rs1_rely            ),
  .rs2_rely            (rs2_rely            ),
  .rs_rdy              (rs_rdy              ),
  .rs_tag_bus          (CDB_RS_tag          ),
  .up_alu_output       (CDB_RS_alu_output       ),
  .alu_npc             (alu_npc             ),
  .lsb_rdy             (lsb_rdy             ),
  .lsb_tag_bus         (CDB_LSB_tag         ),
  .up_lmd_output       (CDB_LSB_lmd_output       ),
  .dispatch_rdy        (dispatch_rob_rdy        ),
  .up_inst             (dispatch_down_inst             ),
  .up_npc              (dispatch_down_npc              ),
  .up_rd               (dispatch_down_rd               ),
  .ROB_next_tag        (next_tag        ),
  .clear               (clear               ),
  .enable_write        (ROB_LSB_enable_write        ),
  .enable_IO           (ROB_LSB_enable_IO),
  .ROB_rs1_valid       (ROB_rs1_valid       ),
  .ROB_rs1_ans_output  (ROB_rs1_ans_output  ),
  .ROB_rs2_valid       (ROB_rs2_valid       ),
  .ROB_rs2_ans_output  (ROB_rs2_ans_output  ),
  .write_val           (ROB_reg_write_val           ),
  .write_rdy           (ROB_reg_write_rdy           ),
  .head_tag            (now_tag            ),
  .to_rd               (ROB_reg_rd               ),
  .commit_pulse        (commit_pulse        ),
  .to_pc               (ROB_fetch_next_pc               ),
  .ROB_FULL            (ROB_FULL            )
);


`ifdef partial_show

always @(posedge clk_in) begin

  if ( $time > `partial_show )
    $finish ;
  // if ( ($time % `partial_show) == 1 ) begin
  //   $display("time: %d",$time);
  // end
  
end

`endif



endmodule