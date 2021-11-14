`include "constant.v"

module cpu_ctrl (
    // ctrl
    input wire clk_in ,
    input wire rdy_in ,
    input wire rst_in ,
    input wire stall_in ,

    // layer status

    input wire [`LayerStatusBus] IF_ans_status ,
    input wire [`LayerStatusBus] ID_ans_status ,    
    input wire [`LayerStatusBus] EX_ans_status ,    
    input wire [`LayerStatusBus] MEM_ans_status ,

    // data dependence

    input wire [`RegBus] EX_rd ,
    input wire [`RegBus] MEM_rd ,

    input wire [`RegBus] ID_rs1 ,
    input wire [`RegBus] ID_rs2 ,

    // time hazard

    input wire [`AddrBus] IF_npc ,
    input wire [`AddrBus] ID_npc ,
    input wire [`AddrBus] EX_npc ,
    input wire [`AddrBus] real_pc ,

    // data to pc_reg

    output reg [`AddrBus] next_pc ,

    // stall to layer

    output reg [`LayerStatusBus] IF_ID_stall_in ,
    output reg [`LayerStatusBus] ID_EX_stall_in ,
    output reg [`LayerStatusBus] EX_MEM_stall_in ,
    output reg [`LayerStatusBus] MEM_WB_stall_in ,
    
    // pulse to module

    output reg IF_stall_in ,    // 发送取反信号刺激他们工作
    output reg ID_stall_in ,
    output reg EX_stall_in ,
    output reg MEM_stall_in ,
    output reg WB_stall_in ,


    output reg IF_ans_clear , // 0 -> keep 1 -> clear
    output reg ID_ans_clear ,
    output reg EX_ans_clear ,
    output reg MEM_ans_clear 

);

// todo 判 rd 是否相同小心 0 寄存器

// 此处收集数据尝试使用 negedge

always @(negedge clk_in) begin // data hazard
    if ( rst_in == 1 ) begin
        next_pc <= 0 ;
        IF_ID_stall_in <= 0 ;
        ID_EX_stall_in <= 0 ;
        EX_MEM_stall_in <= 0 ;
        MEM_WB_stall_in <= 0 ;
        IF_stall_in <= 0 ;
        ID_stall_in <= 0 ;
        EX_stall_in <= 0 ;
        MEM_stall_in <= 0 ;
        WB_stall_in <= 0 ;
        IF_ans_clear <= 0 ;
        ID_ans_clear <= 0 ;
        EX_ans_clear <= 0 ;
        MEM_ans_clear <= 0 ;
    end else if (rdy_in == 1) begin
        if ( ID_ans_status != 0 ) begin // data hazard
            if ( EX_ans_status != 0 && EX_rd != 0 && ( EX_rd == ID_rs1 || EX_rd == ID_rs2 ) ) begin
                IF_ID_stall_in <= 2 ; // stall
                ID_ans_clear <= 1 ;
            end
            else if( MEM_ans_status != 0 && MEM_rd != 0 && ( MEM_rd == ID_rs1 || MEM_rd == ID_rs2) ) begin
                IF_ID_stall_in <= 2 ;
                ID_ans_clear <= 1 ;
            end else begin
                IF_ans_clear <= 0 ;
                ID_ans_clear <= 0 ;
                EX_ans_clear <= 0 ;
                MEM_ans_clear <= 0 ;
                IF_ID_stall_in <= 0 ;
                ID_EX_stall_in <= 0 ;
                EX_MEM_stall_in <= 0 ;
                MEM_WB_stall_in <= 0 ;
            end
        end
        if ( EX_ans_status != 0 ) begin // time hazard
            if ( ID_ans_status != 0 && ID_npc != EX_npc - 4 ) begin
                IF_ans_clear <= 1 ;
                IF_ID_stall_in <= 3 ; // err_msg
                ID_ans_clear <= 1 ;
                next_pc <= EX_npc ;
            end else if ( ID_ans_status == 0 && IF_ans_status != 0 && IF_npc != EX_npc - 4 ) begin
                IF_ans_clear <= 1 ;
                next_pc <= EX_npc ;
            end else begin
                IF_ans_clear <= 0 ;
                ID_ans_clear <= 0 ;
                EX_ans_clear <= 0 ;
                MEM_ans_clear <= 0 ;
                IF_ID_stall_in <= 0 ;
                ID_EX_stall_in <= 0 ;
                EX_MEM_stall_in <= 0 ;
                MEM_WB_stall_in <= 0 ;
            end
        end
    end
end
    
endmodule