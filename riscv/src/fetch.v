`include "constant.v"

module fetch (
    // ctrl
    input wire clk_in ,
    input wire rdy_in ,
    input wire rst_in ,

    // from ROB
    input wire change_pc ,
    input wire[`AddrBus] next_pc ,
    input wire ROB_FULL ,

    // from RS
    input wire RS_FULL ,

    // from LSB
    input wire LSB_FULL ,
    input wire IO_is_writing ,

    // from MEM
    input wire mem_rdy ,
    input wire [`ByteBus] mem_byte ,

    // to MEM
    output reg[`AddrBus] req_addr ,

    // to decode & dispatch
    output reg fetch_rdy ,
    output reg [`InstBus] inst ,
    output reg [`AddrBus] npc  

);

reg[2:0] inst_cnt ; 

reg[`AddrBus] pc ;

reg [`InstBus] InstCollect ;

reg last_valid ; // 记录上一个周期请求是否成功，成功就写入 Collect , mem_rdy 若成功就 addr + 1

reg[`AddrBus] cache_addr[`I_cache_size-1:0] ;
reg[`InstBus] I_cache_Inst[`I_cache_size-1:0] ;

always @(posedge clk_in) begin
    if ( rst_in == 1 ) begin
        req_addr <= 0 ;
        fetch_rdy <= 0 ;
        inst <= 0 ;
        npc <= 0 ;
        inst_cnt <= 0 ;
        pc <= 0 ;
        InstCollect <= 0 ;
        last_valid <= 0 ; // cache addr 不应该清 0 将他当成 dirty

    end else if ( rdy_in == 1 ) begin
        fetch_rdy <= 0 ;
        if ( change_pc == 1 ) begin
            inst_cnt <= 0 ;
            pc <= next_pc ;
            req_addr <= next_pc ;
            InstCollect <= 0 ;
            last_valid <= 0 ;
        end else if ( ROB_FULL == 0 && RS_FULL == 0 && LSB_FULL == 0 ) begin 
        
`ifdef I_cache_added
            if ( inst_cnt == 0 && pc == cache_addr[pc[6:0]] && pc != 0 ) begin
                inst <= I_cache_Inst[pc[6:0]] ;
                fetch_rdy <= 1 ;
                pc <= pc + 4 ;
                npc <= pc + 4 ;
                req_addr <= pc + 4 ;
                last_valid <= 0 ;
            end else begin
`endif
                last_valid <= mem_rdy ;
                if ( last_valid == 1 && IO_is_writing == 0 ) begin
                    case(inst_cnt)
                        0:begin
                            InstCollect[7:0] <= mem_byte ;
                            inst_cnt <= 1 ;
                            pc <= pc + 1 ;
                        end
                        1: begin
                            InstCollect[15:8] <= mem_byte ;
                            inst_cnt <= 2 ;
                            pc <= pc + 1 ;
                        end
                        2:begin
                            InstCollect[23:16] <= mem_byte ;
                            inst_cnt <= 3 ;
                            pc <= pc + 1 ;
                        end
                        3:begin
                            inst <= {mem_byte,InstCollect[23:0]} ;
`ifdef I_cache_added
                            cache_addr[pc[6:0]-3] <= pc - 3 ;
                            I_cache_Inst[pc[6:0]-3] <= {mem_byte,InstCollect[23:0]} ;
`endif
`ifdef debug_show
                            if ( pc == 5215 ) begin
                                $display("first meet:%d",$time) ;
                            end
`endif
                            inst_cnt <= 0 ;
                            fetch_rdy <= 1 ;
                            pc <= pc + 1 ;
                            npc <= pc + 1 ;
                        end
                        default: $display("error: fetch cnt overflow") ;
                    endcase
                end
                if ( mem_rdy == 1 ) begin
                    req_addr <= req_addr + 1 ;
                end

                if ( IO_is_writing == 1) begin
                    req_addr <= pc ; 
                    last_valid <= 0 ;
                end
`ifdef I_cache_added
            end
`endif 
        end else begin
            req_addr <= pc ;
            last_valid <= 0 ;
        end

    end
    
end
    
endmodule