`include "constant.v"

module RS (
    // ctrl
    input wire clk_in ,
    input wire rdy_in ,
    input wire rst_in ,

    // from register 
    input wire [`RegValBus] rs1_val , 
    input wire [`ROBTagBus] rs1_rely ,
    input wire [`RegValBus] rs2_val  ,
    input wire [`ROBTagBus] rs2_rely ,

    // from ROB (new tag)
    input wire [`ROBTagBus] next_tag ,
    input wire clear ,
    
    // from ROB (tag rs1)
    input wire ROB_rs1_valid ,
    input wire [`ALUOutputBus] ROB_rs1_ans_output ,

    // from ROB (tag rs2)
    input wire ROB_rs2_valid ,
    input wire [`ALUOutputBus] ROB_rs2_ans_output ,

    // from ROB (new commit line)
    input wire ROB_write_reg_rdy ,
    input wire [`RegValBus] ROB_write_val ,
    input wire [`ROBTagBus] ROB_head_tag ,

    // from dispatch
    input wire dispatch_rdy ,
    input wire[`InstBus] up_inst ,
    input wire[`AddrBus] up_npc ,
    input wire [`ImmediateBus] up_imme ,

    // to alu 
    output reg [`InstBus] to_inst ,
    output reg [`AddrBus] to_npc ,
    output reg [`RegValBus] to_rs1_val ,
    output reg [`RegValBus] to_rs2_val , 
    output reg [`ImmediateBus] to_imme ,
    output reg [`ROBTagBus] to_tag_bus ,

    // to fetch 
    output wire RS_FULL ,

    // to ROB & CBD
    output reg rs_rdy 


);
    
reg [`InstBus] rs_inst[`RS_SIZE:0] ; // inst type
reg [`ROBTagBus] rs_tag[`RS_SIZE:0] ;
reg [2:0] rs_status[`RS_SIZE:0] ; // 0 -> empty 1 -> valid 2 -> invalid
reg [`AddrBus] rs_npc[`RS_SIZE:0] ;
reg [`ImmediateBus] rs_imme[`RS_SIZE:0] ;

reg [`RegValBus] rs_rs1_val[`RS_SIZE:0] ;
reg [`ROBTagBus] rs_rs1_rely[`RS_SIZE:0] ;
reg [`RegValBus] rs_rs2_val[`RS_SIZE:0] ;
reg [`ROBTagBus] rs_rs2_rely[`RS_SIZE:0] ;

wire [4:0] rs_size_cnt ;

wire [4:0] empty_pos = rs_status[1] == 0 ? 1 
                    : rs_status[2] == 0 ? 2
                        : rs_status[3] == 0 ? 3
                            : rs_status[4] == 0 ? 4
                                : rs_status[5] == 0 ? 5
                                    : rs_status[6] == 0 ? 6
                                        : rs_status[7] == 0 ? 7
                                            : rs_status[8] == 0 ? 8
                                                : rs_status[9] == 0 ? 9
                                                    : rs_status[10] == 0 ? 10
                                                        : rs_status[11] == 0 ? 11
                                                            : rs_status[12] == 0 ? 12
                                                                : rs_status[13] == 0 ? 13
                                                                    : rs_status[14] == 0 ? 14
                                                                        : rs_status[15] == 0 ? 15
                                                                            : rs_status[16] == 0 ? 16 
                                                                                : 0 ;
// 0 ?????????


wire [4:0] valid_pos = rs_status[1] == 1 ? 1
                    : rs_status[2] == 1 ? 2
                        : rs_status[3] == 1 ? 3
                            : rs_status[4] == 1 ? 4
                                : rs_status[5] == 1 ? 5
                                    : rs_status[6] == 1 ? 6
                                        : rs_status[7] == 1 ? 7
                                            : rs_status[8] == 1 ? 8
                                                : rs_status[9] == 1 ? 9
                                                    : rs_status[10] == 1 ? 10
                                                        : rs_status[11] == 1 ? 11
                                                            : rs_status[12] == 1 ? 12
                                                                : rs_status[13] == 1 ? 13
                                                                    : rs_status[14] == 1 ? 14
                                                                        : rs_status[15] == 1 ? 15
                                                                            : rs_status[16] == 1 ? 16
                                                                                : 0 ;
// 0 ???????????? issue


assign RS_FULL = rs_size_cnt >= `RS_SIZE - 3 ;

assign rs_size_cnt = (rs_status[1] > 0) + (rs_status[2] > 0) + (rs_status[3]>0) + (rs_status[4]>0) + (rs_status[5] > 0) + (rs_status[6] > 0) + (rs_status[7] > 0) + (rs_status[8]>0) + (rs_status[9]>0) + (rs_status[10] > 0) + (rs_status[11] > 0) + (rs_status[12] > 0) + (rs_status[13]>0) + (rs_status[14]>0) + (rs_status[15]>0) + (rs_status[16] > 0)  ;

wire [`ROBTagBus] ROB_real_head_tag = ROB_head_tag - 1 == 0 ? 16 : ROB_head_tag - 1 ;

integer i = 0 ;

`ifdef debug_show

integer rs_log ;

initial begin
    rs_log = $fopen("rs_log.txt") ;
end

`endif

always @(posedge clk_in) begin

    rs_rdy <= 0 ;
    to_inst <= 0 ;
    to_npc <= 0 ;
    to_rs1_val <= 0 ;
    to_rs2_val <= 0 ; 
    to_imme <= 0 ;
    to_tag_bus <= 0 ;

    if ( rst_in == 1 || clear == 1 ) begin
        
        for ( i = 0 ; i <= `RS_SIZE ; i = i + 1 ) begin
            rs_inst[i] <= 0 ;            
            rs_tag[i] <= 0 ;            
            rs_status[i] <= 0 ;            
            rs_npc[i] <= 0 ;            
            rs_imme[i] <= 0 ;    
            rs_rs1_val[i] <= 0 ;
            rs_rs1_rely[i] <= 0 ;
            rs_rs2_val[i] <= 0 ;           
            rs_rs2_rely[i] <= 0 ;                     
        end
   

    end else if ( rdy_in == 1 ) begin

`ifdef debug_show


    $fdisplay(rs_log,"<------------------------------->") ;
    $fdisplay(rs_log,"time: %d",$time) ;
    $fdisplay(rs_log,"size: %d ",rs_size_cnt) ;

    for ( i = 1 ; i <= 16 ; i = i + 1 ) begin
        $fdisplay(rs_log,"i: %d inst: %d npc: %d status: %d tag: %d rs1_rely: %d rs2_rely: %d",i,rs_inst[i],rs_npc[i],rs_status[i],rs_tag[i],rs_rs1_rely[i],rs_rs2_rely[i]) ;
    end
    $fdisplay(rs_log,"<------------------------------->") ;


`endif
        
        // issue
        if ( valid_pos != 0 ) begin
            rs_rdy <= 1 ;
            rs_status[valid_pos] <= 0 ; // ?????? empty
            to_inst <= rs_inst[valid_pos] ;
            to_npc <= rs_npc[valid_pos] ;
            to_rs1_val <= rs_rs1_val[valid_pos] ;
            to_rs2_val <= rs_rs2_val[valid_pos] ; 
            to_imme <= rs_imme[valid_pos] ;
            to_tag_bus <= rs_tag[valid_pos] ;
        end

        // clear tag
        for ( i = 1 ; i <= `RS_SIZE ; i = i + 1 ) begin
            if ( rs_status[i] == 2 ) begin
                if ( ROB_write_reg_rdy == 1  ) begin
                    if ( rs_rs1_rely[i] == ROB_real_head_tag && rs_rs1_rely[i] != 0) begin
                        rs_rs1_rely[i] <= 0 ;
                        rs_rs1_val[i] <= ROB_write_val ;
                    end
                    if ( rs_rs2_rely[i] == ROB_real_head_tag && rs_rs2_rely[i] != 0) begin
                        rs_rs2_rely[i] <= 0 ;
                        rs_rs2_val[i] <= ROB_write_val ;
                    end
                end
                if ( (rs_rs1_rely[i] == 0 || (ROB_write_reg_rdy == 1 && rs_rs1_rely[i] == ROB_real_head_tag)) && (rs_rs2_rely[i] == 0 || (ROB_write_reg_rdy == 1 && rs_rs2_rely[i] == ROB_real_head_tag)) ) begin
                    rs_status[i] <= 1 ; // ?????? rs1 ??? rs2 ????????????????????????
                end
            end

        end
        
        // settle dispatch
        if ( dispatch_rdy == 1 ) begin
            rs_inst[empty_pos] <= up_inst ; 
            rs_tag[empty_pos] <= next_tag ;
            rs_npc[empty_pos] <= up_npc ;
            rs_imme[empty_pos] <= up_imme ;
            rs_rs1_val[empty_pos] <= rs1_val ;
            rs_rs1_rely[empty_pos] <= rs1_rely ;
            rs_rs2_val[empty_pos] <= rs2_val ;
            rs_rs2_rely[empty_pos] <= rs2_rely ;
            rs_status[empty_pos] <= 2 ;
            if ( rs1_rely != 0 ) begin
                // ROB request
                if ( ROB_rs1_valid == 1 ) begin
                    rs_rs1_val[empty_pos] <= ROB_rs1_ans_output ;
                end
            end
            if ( rs2_rely != 0 ) begin
                // ROB request
                if ( ROB_rs2_valid == 1 ) begin
                    rs_rs2_val[empty_pos] <= ROB_rs2_ans_output ;
                end
            end
            if ( rs1_rely == 0 && rs2_rely == 0 ) begin
                rs_status[empty_pos] <= 1 ;
            end
            // ????????????: ??????????????? CDB ??? ROB ???????????????, ????????????????????? status ??? valid ????????? clk
        end

    end
end

endmodule