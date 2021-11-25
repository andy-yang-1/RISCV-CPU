`include "constant.v"

module predictor (
    // ctrl
    input wire clk_in ,
    input wire rdy_in ,
    input wire rst_in ,

    // from dispatch
    input wire[`AddrBus] up_npc ,

    // from ROB 
    input wire[`AddrBus] rob_npc ,
    input wire[1:0] jump_failed , // 0 -> not jump 1 -> jump_failed 2 -> jump_succeed

    // to fetch 
    output wire predict_jump 

);

reg [`PredictorBus] predict_table[`I_cache_size-1:0] ;

assign predict_jump = predict_table[up_npc[5:0]][1] ;

integer i ;

always @(posedge clk_in) begin
    if ( rst_in == 1) begin
        for ( i = 0; i < `I_cache_size ; i = i + 1 ) begin
            predict_table[i] <= 0 ;
        end
    end else if ( rdy_in == 1) begin
        if ( jump_failed == 1 ) begin
            predict_table[rob_npc[5:0]] <= predict_table[rob_npc[5:0]] == 0 ? 0 : predict_table[rob_npc[5:0]] - 1 ;
        end else if ( jump_failed == 2 ) begin
            predict_table[rob_npc[5:0]] <= predict_table[rob_npc[5:0]] == 3 ? 3 : predict_table[rob_npc[5:0]] + 1 ;
        end
    end  
end
    
endmodule