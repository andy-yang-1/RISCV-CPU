`include "constant.v"

module ROB (
    // ctrl
    input wire clk_in ,
    input wire rdy_in ,
    input wire rst_in ,

    // from register 
    input wire [`ROBTagBus] rs1_rely ,
    input wire [`ROBTagBus] rs2_rely ,

    // from RS 
    input wire rs_rdy ,

    // from alu 
    input wire[`ROBTagBus] rs_tag_bus ,
    input wire[`ALUOutputBus] up_alu_output ,
    input wire[`AddrBus] alu_npc ,

    // from LSB 
    input wire lsb_rdy ,
    input wire[`ROBTagBus] lsb_tag_bus ,
    input wire[`LMDOutputBus] up_lmd_output ,

    // from dispatch
    input wire dispatch_rdy ,
    input wire[`InstBus] up_inst ,
    input wire[`AddrBus] up_npc ,
    input wire[`RegBus] up_rd , // 0 就不需要 rd

    // to RS & LSB & register & fetch (change pc)
    output wire[`ROBTagBus] ROB_next_tag ,
    output reg clear ,
    output reg enable_write , // 传给 LSB 允许写入
    output reg enable_IO , // 允许 IO 读入

    // to RS & LSB tag1
    output wire ROB_rs1_valid ,
    output wire [`ALUOutputBus] ROB_rs1_ans_output ,

    // to RS & LSB tag2
    output wire ROB_rs2_valid ,
    output wire [`ALUOutputBus] ROB_rs2_ans_output ,

    // to register & RS & LSB 
    output reg[`RegValBus] write_val ,
    output reg write_rdy ,
    output wire[`ROBTagBus] head_tag ,
    output reg[`RegBus] to_rd ,

    // debug pulse 
    output reg commit_pulse ,

    // to fetch 
    output reg[`AddrBus] to_pc ,
    output wire ROB_FULL

);

// 循环队列 1-base : head = 1 rear = 1

wire [4:0] rob_size_cnt ;
reg [4:0] head ; // 执行结束弹出队首
wire [4:0] rear ; // 采用组合方法实时计算 rear

assign ROB_FULL = rob_size_cnt >= `ROB_SIZE - 3 ;

reg [`InstBus] rob_inst[`ROB_SIZE:0] ; // inst type
reg [2:0] rob_status[`ROB_SIZE:0] ; // 0 -> empty 1 -> valid 2 -> invalid 
reg [`AddrBus] rob_npc[`ROB_SIZE:0] ;
reg [`AddrBus] rob_new_npc[`ROB_SIZE:0] ;

reg [`RegBus] rob_rd[`ROB_SIZE:0] ;
// reg [`ALUOutputBus] rob_alu_output[`ROB_SIZE:0] ;
// reg [`LMDOutputBus] rob_lmd_output[`ROB_SIZE:0] ;
reg [`ALUOutputBus] rob_ans_output[`ROB_SIZE:0] ;

reg IO_wait ;

assign rob_size_cnt = (rob_status[1] > 0) + (rob_status[2] > 0) + (rob_status[3]>0) + (rob_status[4]>0) + (rob_status[5] > 0) + (rob_status[6] > 0) + (rob_status[7] > 0) + (rob_status[8]>0) + (rob_status[9]>0) + (rob_status[10] > 0) + (rob_status[11] > 0) + (rob_status[12] > 0) + (rob_status[13]>0) + (rob_status[14]>0) + (rob_status[15]>0) + (rob_status[16] > 0)  ;
assign rear = (( head + rob_size_cnt ) <= 16) ? head + rob_size_cnt : head + rob_size_cnt - 16 ; 

assign head_tag = head ;
assign ROB_next_tag = rear ;

assign ROB_rs1_valid = ( rs1_rely == 0 || rob_status[rs1_rely] == 1  ) ? 1 : 0 ;
assign ROB_rs1_ans_output = rob_ans_output[rs1_rely] ;
assign ROB_rs2_valid = ( rs2_rely == 0 || rob_status[rs2_rely] == 1  ) ? 1 : 0 ;
assign ROB_rs2_ans_output = rob_ans_output[rs2_rely] ;


integer i = 0 ;

`ifdef debug_show

integer rob_log ;

initial begin
    rob_log = $fopen("rob_log.txt") ;
end

`endif

always @(posedge clk_in) begin

    clear <= 0 ;
    write_val <= 0 ;
    write_rdy <= 0 ;
    to_rd <= 0 ;
    to_pc <= 0 ;
    enable_write <= 0 ;
    enable_IO <= 0 ;
    commit_pulse <= 0 ;

`ifdef debug_show


    $fdisplay(rob_log,"<------------------------------->") ;
    $fdisplay(rob_log,"time: %d",$time) ;
    $fdisplay(rob_log,"head: %d rear: %d",head,rear) ;

    for ( i = 1 ; i <= 16 ; i = i + 1 ) begin
        $fdisplay(rob_log,"i: %d inst: %d npc: %d status: %d new npc: %d rd: %d ans: %d",i,rob_inst[i],rob_npc[i],rob_status[i],rob_new_npc[i],rob_rd[i],rob_ans_output[i]) ;
    end
    $fdisplay(rob_log,"<------------------------------->") ;


`endif

    if ( rst_in == 1 || clear == 1 ) begin

        head <= 1 ;
        commit_pulse <= 0 ;
        IO_wait <= 0 ;
        
        for ( i = 0 ; i <= `ROB_SIZE ; i = i + 1 ) begin
            rob_inst[i] <= 0 ;
            rob_status[i] <= 0 ;
            rob_npc[i] <= 0 ;
            rob_new_npc[i] <= 0 ;
            rob_ans_output[i] <= 0 ;
            rob_rd[i] <= 0 ;
        end

    end else if ( rdy_in == 1 ) begin

        // commit 
        if ( rob_status[head] == 1 ) begin

            commit_pulse <= 1 ;
            IO_wait <= 0 ;

            if ( rob_rd[head] != 0 ) begin
                write_rdy <= 1 ;
                to_rd <= rob_rd[head] ;
                write_val <= rob_ans_output[head] ;
            end


            if ( rob_npc[head] != rob_new_npc[head] ) begin // jump
                clear <= 1 ;
            end

            head <= (head + 1 <= 16) ?  head + 1 : head - 15 ;
            rob_status[head] <= 0 ;
            to_pc <= rob_new_npc[head] ;

`ifdef debug_show     
             if (  rob_npc[head] == 5216  ) begin
                $display("time: %d",$time) ;
             end      
`endif

        end

        if ( (rob_inst[head] == `Instsb || rob_inst[head] == `Instsh || rob_inst[head] == `Instsw) && rob_status[head] == 2 ) begin
                enable_write <= 1 ;
                head <= (head + 1 <= 16) ?  head + 1 : head - 15 ;
                rob_status[head] <= 0 ;
                to_pc <= rob_new_npc[head] ;
                commit_pulse <= 1 ;
        end // 不需要状态就可以 commit 

        // todo settle IO read here
        if ( ( rob_inst[head] == `Instlb || rob_inst[head] == `Instlh || rob_inst[head] == `Instlw || rob_inst[head] == `Instlbu || rob_inst[head] == `Instlhu) && rob_status[head] == 2 && lsb_rdy == 0 && IO_wait == 0 ) begin
            IO_wait <= 1 ; 
            enable_IO <= 1 ; 
        end

        // clear tag 
        if ( rs_rdy == 1) begin
            rob_ans_output[rs_tag_bus] <= up_alu_output ;
            rob_new_npc[rs_tag_bus] <= alu_npc ;
            rob_status[rs_tag_bus] <= 1 ;
        end

        if ( lsb_rdy == 1) begin
            rob_ans_output[lsb_tag_bus] <= up_lmd_output ;
            rob_status[lsb_tag_bus] <= 1 ;
        end

        

        // settle dispatch
        if ( dispatch_rdy == 1 && clear == 0 ) begin
            rob_inst[rear] <= up_inst ;
            rob_npc[rear] <= up_npc ;
            rob_rd[rear] <= up_rd ;
            rob_status[rear] <= 2 ;
            rob_new_npc[rear] <= up_npc ; // 防止为清空同时是 ls 操作导致跳转
        end

    end
end



    
endmodule