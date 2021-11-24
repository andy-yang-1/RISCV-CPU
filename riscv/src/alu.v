`include "constant.v" 

module alu (
    // ctrl
    input wire clk_in ,
    input wire rdy_in ,
    input wire rst_in ,

    // from RS 
    input wire[`InstBus] up_inst ,
    input wire[`AddrBus] up_npc ,
    input wire[`RegValBus] up_rs1_val ,
    input wire[`RegValBus] up_rs2_val , 
    input wire [`ImmediateBus] up_imme ,
    input wire [`ROBTagBus] up_tag_bus ,

    // to CDB 
    output reg[`ROBTagBus] rs_tag_bus ,
    output reg[`ALUOutputBus] to_alu_output ,
    output reg[`AddrBus] to_npc  // to_npc 和 ROB 中的 npc 不一样时就给其打上跳转标记


);

always @(*) begin

    rs_tag_bus = 0 ;
    to_alu_output = 0 ;
    to_npc = 0 ;

    if (rst_in == 1) begin
        ;
    end else if ( rdy_in == 1 ) begin
        rs_tag_bus = up_tag_bus ;
        to_npc = up_npc ;
        case (up_inst)
            `Instlui:   to_alu_output = up_imme ;
            `Instauipc: to_alu_output = up_npc - 4 + up_imme ;
            `Instjal:   begin
                to_alu_output = up_npc ;
                to_npc = up_npc + up_imme - 4 ;
            end
            `Instjalr: begin
                to_npc = (up_rs1_val+up_imme) & ~1 ;
                to_alu_output = up_npc ;
            end
            `Instbeq: if ( up_rs1_val == up_rs2_val ) to_npc = up_npc + up_imme - 4 ;
            `Instbne: if ( up_rs1_val != up_rs2_val ) to_npc = up_npc + up_imme - 4 ;
            `Instblt: if ( $signed(up_rs1_val) < $signed(up_rs2_val) ) to_npc = up_npc + up_imme - 4 ; // 有符号位
            `Instbge: if ( $signed(up_rs1_val) >= $signed(up_rs2_val) ) to_npc = up_npc + up_imme - 4 ;
            `Instbltu: if ( up_rs1_val < up_rs2_val ) to_npc = up_npc + up_imme - 4 ; 
            `Instbgeu: if ( up_rs1_val >= up_rs2_val ) to_npc = up_npc + up_imme - 4 ;
            `Instaddi: to_alu_output = up_rs1_val + up_imme ;
            `Instslti: to_alu_output = $signed(up_rs1_val) < $signed(up_imme) ;
            `Instsltiu: to_alu_output = $signed(up_rs1_val) < up_imme ; 
            `Instxori: to_alu_output = up_rs1_val ^ up_imme ;
            `Instori: to_alu_output = up_rs1_val | up_imme ;
            `Instandi: to_alu_output = up_rs1_val & up_imme ;
            `Instslli: to_alu_output = up_rs1_val << up_imme ;
            `Instsrli: to_alu_output = up_rs1_val >> up_imme ;
            `Instsrai: to_alu_output = $signed(up_rs1_val) >> up_imme ;
            `Instadd: to_alu_output = up_rs1_val + up_rs2_val ;
            `Instsub: to_alu_output = up_rs1_val - up_rs2_val ;
            `Instsll: to_alu_output = up_rs1_val << up_rs2_val ;
            `Instslt: to_alu_output = $signed(up_rs1_val) < $signed(up_rs2_val) ;
            `Instsltu: to_alu_output = $signed(up_rs1_val) < up_rs2_val ;
            `Instxor: to_alu_output = up_rs1_val ^ up_rs2_val ;
            `Instsrl: to_alu_output = $signed(up_rs1_val) >> up_rs2_val ; // todo 不知道这里有没有 signed 的必要
            `Instsra: to_alu_output = $signed(up_rs1_val) >> $signed(up_rs2_val) ;
            `Instor: to_alu_output = up_rs1_val | up_rs2_val ;
            `Instand: to_alu_output = up_rs1_val & up_rs2_val ;
//            default: $display("error: alu instruction overflow") ;

        endcase
    end
    
end
    
endmodule