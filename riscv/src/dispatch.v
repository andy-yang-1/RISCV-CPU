`include "constant.v"

module dispatch (
    // ctrl
    input wire clk_in ,
    input wire rdy_in ,
    input wire rst_in ,

    // from fetch
    input wire fetch_rdy ,

    // from decode 
    input wire[`InstBus] up_inst ,
    input wire[`AddrBus] up_npc ,
    input wire [`RegBus] up_rs1 , 
    input wire up_rs1_in_need ,
    input wire [`RegBus] up_rs2 ,
    input wire up_rs2_in_need , 
    input wire [`RegBus] up_rd ,
    input wire up_rd_in_need ,
    input wire mem_in_need ,
    input wire [`ImmediateBus] up_imme ,

    // from ROB 
    input wire clear , // clear 时不可以 dispatch

    // to register & ROB
    output reg [`RegBus] to_rs1 , 
    output reg to_rs1_in_need ,
    output reg [`RegBus] to_rs2 ,
    output reg to_rs2_in_need ,
    output reg [`RegBus] to_rd ,
    output reg to_rd_in_need ,

    // to RS & LSB & ROB
    output reg[`InstBus] to_inst ,
    output reg[`AddrBus] to_npc ,
    output reg [`ImmediateBus] to_imme ,

    // to RS
    output reg dispatch_rs_rdy ,

    // to LSB
    output reg dispatch_lsb_rdy ,

    // to ROB
    output reg dispatch_rob_rdy

);

always @(posedge clk_in) begin
        to_rs1 <= 0 ;
        to_rs1_in_need <= 0 ;
        to_rs2 <= 0 ;
        to_rs2_in_need <= 0 ;
        to_rd <= 0 ;
        to_rd_in_need <= 0 ;
        to_inst <= 0 ;
        to_npc <= 0 ;
        to_imme <= 0 ;
        dispatch_rs_rdy <= 0;
        dispatch_lsb_rdy <= 0 ;
        dispatch_rob_rdy <= 0 ;
    if ( rst_in == 1 || clear == 1 ) begin
        ; 
    end else if ( rdy_in == 1 ) begin
        if (fetch_rdy == 1) begin
            to_rs1 <= up_rs1 ;
            to_rs2 <= up_rs2 ;
            if ( up_rd_in_need == 1 )
                to_rd <= up_rd ;
            else
                to_rd <= 0 ;
            to_rs1_in_need <= up_rs1_in_need ;
            to_rs2_in_need <= up_rs2_in_need ;
            to_rd_in_need <= up_rd_in_need ;
            to_inst <= up_inst ;            
            to_npc <= up_npc ;
            to_imme <= up_imme ;
            if ( mem_in_need == 1) begin
                dispatch_lsb_rdy <= 1 ;
            end else begin
                dispatch_rs_rdy <= 1 ;
            end
            dispatch_rob_rdy <= 1 ;
        end
    end
end

    
endmodule