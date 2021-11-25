`include "constant.v"

module LSB (
    // ctrl
    input wire clk_in ,
    input wire rdy_in ,
    input wire rst_in ,
    input wire io_buffer_full ,

    // from register 
    input wire [`RegValBus] rs1_val , 
    input wire [`ROBTagBus] rs1_rely ,
    input wire [`RegValBus] rs2_val  ,
    input wire [`ROBTagBus] rs2_rely ,

    // from ROB (new tag)
    input wire [`ROBTagBus] next_tag ,
    input wire enable_write , // LSB 和 ROB 顶端同时为 S 操作时的 commit 请求
    input wire enable_IO ,
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
    input wire [`ImmediateBus] up_imme ,

    // from MEM 
    input wire [`ByteBus] mem_byte , // 默认时刻正确

    // to MEM 
    output reg[`AddrBus] req_addr ,
    output reg[`ByteBus] write_data ,
    output reg LSB_mem_in_need ,
    output reg mem_wr , // 0 -> read 1 -> write

    // to fetch 
    output wire LSB_FULL ,
    
    // to ROB & CDB
    output reg [`LMDOutputBus] to_lmd_output ,
    output reg [`ROBTagBus] to_tag_bus ,
    output reg lsb_rdy

);

reg [2:0] data_cnt ;
reg [`LMDOutputBus] LMDCollect ; // 用 mem_in_need 看工作状态 mem_wr 看工作种类

// 循环队列 0-base : head = 0 rear = 0

wire [4:0] lsb_size_cnt ;
reg [4:0] head ; // 执行结束弹出队首
wire [4:0] rear ; // 采用组合方法实时计算 rear

wire [4:0] commit_size_cnt ;
wire [4:0] next_commit ;

assign LSB_FULL = lsb_size_cnt >= `LSB_SIZE - 3 ;


reg [`InstBus] lsb_inst[`LSB_SIZE:0] ; // inst type
reg [`ROBTagBus] lsb_tag[`LSB_SIZE:0] ;
reg [2:0] lsb_status[`LSB_SIZE:0] ; // 0 -> empty 1 -> valid 2 -> invalid 3 -> write commit
reg [`ImmediateBus] lsb_imme[`LSB_SIZE:0] ;

reg [`RegValBus] lsb_rs1_val[`LSB_SIZE:0] ;
reg [`ROBTagBus] lsb_rs1_rely[`LSB_SIZE-1:0] ;
reg [`RegValBus] lsb_rs2_val[`LSB_SIZE-1:0] ;
reg [`ROBTagBus] lsb_rs2_rely[`LSB_SIZE:0] ;

reg last_full ;
reg last_write ;

assign lsb_size_cnt = (lsb_status[0] > 0) + (lsb_status[1] > 0) + (lsb_status[2] > 0) + (lsb_status[3]>0) + (lsb_status[4]>0) + (lsb_status[5] > 0) + (lsb_status[6] > 0) + (lsb_status[7] > 0) + (lsb_status[8]>0) + (lsb_status[9]>0) + (lsb_status[10] > 0) + (lsb_status[11] > 0) + (lsb_status[12] > 0) + (lsb_status[13]>0) + (lsb_status[14]>0) + (lsb_status[15]>0) ;
assign commit_size_cnt = (lsb_status[0] == 3) + (lsb_status[1] == 3) + (lsb_status[2] == 3) + (lsb_status[3]== 3) + (lsb_status[4]== 3) + (lsb_status[5] == 3) + (lsb_status[6] == 3) + (lsb_status[7]== 3) + (lsb_status[8]== 3) + (lsb_status[9]== 3) + (lsb_status[10] == 3) + (lsb_status[11] == 3) + (lsb_status[12]== 3) + (lsb_status[13]== 3) + (lsb_status[14]== 3) + (lsb_status[15]== 3) ;
assign rear = ( head + lsb_size_cnt ) % 16 ; 
assign next_commit = ( head + commit_size_cnt ) % 16 ;

wire [`ROBTagBus] ROB_real_head_tag = ROB_head_tag - 1 == 0 ? 16 : ROB_head_tag - 1 ;

integer i = 0 ;

`ifdef debug_show

integer lsb_log ;

initial begin
    lsb_log = $fopen("lsb_log.txt") ;
end

`endif

always @(posedge clk_in) begin

    req_addr <= 0 ;
    write_data <= 0 ;
    LSB_mem_in_need <= 0 ;
    mem_wr <= 0 ;
    lsb_rdy <= 0 ;
    to_tag_bus <= 0 ;
    to_lmd_output <= 0 ;
    last_write <= 0 ;

`ifdef debug_show


    $fdisplay(lsb_log,"<------------------------------->") ;
    $fdisplay(lsb_log,"time: %d",$time) ;
    $fdisplay(lsb_log,"head: %d rear: %d req_addr: %d LMDCollect: %d data_cnt: %d",head,rear,req_addr,LMDCollect,data_cnt) ;

    for ( i = 0 ; i < 16 ; i = i + 1 ) begin
        $fdisplay(lsb_log,"i: %d inst: %d status: %d tag: %d rs1_rely: %d rs1_val: %d rs2_rely: %d rs2_val: %d imme: %d",i,lsb_inst[i],lsb_status[i],lsb_tag[i],lsb_rs1_rely[i],lsb_rs1_val[i],lsb_rs2_rely[i],lsb_rs2_val[i],lsb_imme[i]) ;
    end
    $fdisplay(lsb_log,"<------------------------------->") ;


`endif

    if ( rst_in == 1) begin
        for ( i = 0 ; i < `LSB_SIZE ; i = i + 1) begin

            lsb_inst[i] <= 0 ;
            lsb_tag[i] <= 0 ;
            lsb_status[i] <= 0 ;
            lsb_imme[i] <= 0 ;
            lsb_rs1_val[i] <= 0 ;
            lsb_rs1_rely[i] <= 0 ;
            lsb_rs2_val[i] <= 0 ;
            lsb_rs2_rely[i] <= 0 ;

        end

        data_cnt <= 0 ; // 指需要等待的 byte 数
        LMDCollect <= 0 ;
        head <= 0 ;
        last_full <= 0 ;

    end else if( rdy_in == 1 ) begin
        if ( clear == 1 ) begin
            if ( lsb_status[head] != 3 ) begin
                data_cnt <= 0 ;
                LMDCollect <= 0 ;
                LSB_mem_in_need <= 0 ;
                mem_wr <= 0 ;
            end
            for ( i = 0 ; i < `LSB_SIZE ; i = i + 1 ) begin
                if ( lsb_status[i] != 3 ) begin
                    lsb_status[i] <= 0 ; // 非 commit 写入全部清空 
                end
            end
        end else if( enable_write == 1 ) begin
            lsb_status[next_commit] <= 3 ; // 使下一位标号
        end else if ( enable_IO == 1 && lsb_rs1_val[next_commit] + lsb_imme[next_commit] >= 196608 ) begin
            lsb_status[next_commit] <= 3 ; 
        end
        if ( clear == 0 || lsb_status[head] == 3 ) begin

            if ( io_buffer_full == 0 ) begin
            last_full <= 0 ;
            if ( data_cnt > 0 ) begin // 执行结束停一个 clk 简化电路 (有提升空间)
                case (lsb_inst[head])
                    `Instlb: begin
                        case(data_cnt)
                            1:begin
                                to_lmd_output <= {{25{mem_byte[7:7]}},mem_byte[6:0]} ;
                                lsb_rdy <= 1 ;
                                to_tag_bus <= lsb_tag[head] ;
                                data_cnt <= 0 ;
                                head <= ( head + 1 ) % 16 ;
                                lsb_status[head] <= 0 ;
                                LSB_mem_in_need <= 0 ;
                            end
                            2:begin
                                LSB_mem_in_need <= 0 ;
                                data_cnt <= 1 ;
                            end
                        endcase
                    end 
                    `Instlh: begin
                        case(data_cnt)
                        1: begin
                            to_lmd_output <= {{17{mem_byte[7:7]}},mem_byte[6:0],LMDCollect[7:0]} ;
                            lsb_rdy <= 1 ;
                            to_tag_bus <= lsb_tag[head] ;
                            data_cnt <= 0 ;
                            head <= ( head + 1 ) % 16 ;
                            lsb_status[head] <= 0 ;
                            LSB_mem_in_need <= 0 ;
                        end
                        2:begin
                            LMDCollect[7:0] <= mem_byte ;
                            data_cnt <= 1 ;
                            LSB_mem_in_need <= 0 ;
                        end
                        3:begin
                            data_cnt <= 2 ;
                            req_addr <= req_addr + 1 ;
                            mem_wr <= 0 ;
                            LSB_mem_in_need <= 1 ;
                        end
                        endcase
                    end
                    `Instlw: begin
                        case (data_cnt)
                            1: begin
                                to_lmd_output <= {mem_byte,LMDCollect[23:0]} ;
                                lsb_rdy <= 1 ;
                                to_tag_bus <= lsb_tag[head] ;
                                data_cnt <= 0 ;
                                head <= ( head + 1 ) % 16 ;
                                lsb_status[head] <= 0 ;
                                LSB_mem_in_need <= 0 ;
                            end 
                            2: begin
                                LMDCollect[23:16] <= mem_byte ;
                                data_cnt <= 1 ;
                                LSB_mem_in_need <= 0 ;
                                mem_wr <= 0 ;
                            end
                            3: begin
                                LMDCollect[15:8] <= mem_byte ;
                                data_cnt <= 2 ;
                                req_addr <= req_addr + 1 ;
                                LSB_mem_in_need <= 1 ;
                                mem_wr <= 0 ;
                            end
                            4: begin
                                LMDCollect[7:0] <= mem_byte ;
                                data_cnt <= 3 ;
                                req_addr <= req_addr + 1 ;
                                LSB_mem_in_need <= 1 ;
                                mem_wr <= 0 ;
                            end
                            5: begin
                                data_cnt <= 4 ;
                                req_addr <= req_addr + 1 ;
                                LSB_mem_in_need <= 1 ;
                                mem_wr <= 0 ;
                            end
                        endcase
                    end
                    `Instlbu: begin
                        case(data_cnt)
                            1:begin
                                to_lmd_output <= {{24{1'b0}},mem_byte} ;
                                lsb_rdy <= 1 ;
                                to_tag_bus <= lsb_tag[head] ;
                                data_cnt <= 0 ;
                                head <= ( head + 1 ) % 16 ;
                                lsb_status[head] <= 0 ;
                                LSB_mem_in_need <= 0 ;
                            end
                            2:begin
                                LSB_mem_in_need <= 0 ;
                                data_cnt <= 1 ;
                            end
                        endcase
                    end
                    `Instlhu: begin
                        case(data_cnt)
                        1: begin
                            to_lmd_output <= {{16{1'b0}},mem_byte,LMDCollect[7:0]} ;
                            lsb_rdy <= 1 ;
                            to_tag_bus <= lsb_tag[head] ;
                            data_cnt <= 0 ;
                            head <= ( head + 1 ) % 16 ;
                            lsb_status[head] <= 0 ;
                            LSB_mem_in_need <= 0 ;
                        end
                        2:begin
                            LMDCollect[7:0] <= mem_byte ;
                            data_cnt <= 1 ;
                            LSB_mem_in_need <= 0 ;
                        end
                        3:begin
                            data_cnt <= 2 ;
                            req_addr <= req_addr + 1 ;
                            LSB_mem_in_need <= 1 ;
                            mem_wr <= 0 ;
                        end
                        endcase
                    end
                    `Instsb: begin
                        lsb_rdy <= 0 ;
                        lsb_status[head] <= 0 ;
                        data_cnt <= 0 ; // 1 -> 0
                        LSB_mem_in_need <= 0 ;
                        head <= ( head + 1 ) % 16 ;
                        mem_wr <= 0 ;
                    end
                    `Instsh: begin
                        case (data_cnt)
                        1: begin
                            lsb_rdy <= 0 ;
                            lsb_status[head] <= 0 ;
                            data_cnt <= 0 ;
                            LSB_mem_in_need <= 0 ;
                            head <= ( head + 1 ) % 16 ;
                            mem_wr <= 0 ;
                        end
                        2: begin
                            data_cnt <= 1 ;
                            write_data <= LMDCollect[15:8] ;
                            LSB_mem_in_need <= 1 ;
                            mem_wr <= 1 ;
                            req_addr <= req_addr + 1 ;
                        end
                        endcase
                    end
                    `Instsw: begin
                        case (data_cnt)
                        1: begin
                            lsb_rdy <= 0 ;
                            lsb_status[head] <= 0 ;
                            data_cnt <= 0 ;
                            LSB_mem_in_need <= 0 ;
                            head <= ( head + 1 ) % 16 ;
                            mem_wr <= 0 ;
                        end
                        2: begin
                            data_cnt <= 1 ;
                            write_data <= LMDCollect[31:24] ;
                            LSB_mem_in_need <= 1 ;
                            mem_wr <= 1 ;
                            req_addr <= req_addr + 1 ;
                        end
                        3: begin
                            data_cnt <= 2 ;
                            write_data <= LMDCollect[23:16] ;
                            LSB_mem_in_need <= 1 ;
                            mem_wr <= 1 ;
                            req_addr <= req_addr + 1 ;
                        end
                        4: begin
                            data_cnt <= 3 ;
                            write_data <= LMDCollect[15:8] ;
                            LSB_mem_in_need <= 1 ;
                            mem_wr <= 1 ;
                            req_addr <= req_addr + 1 ;
                        end
                        endcase
                    end
                    default: $display("error: LSB instruction overflow") ;
                endcase 
            end else begin // issue

                if ( lsb_status[head] == 1 ) begin                   
                   
                   if ((lsb_inst[head] == `Instlb || lsb_inst[head] == `Instlh || lsb_inst[head] == `Instlw || lsb_inst[head] == `Instlbu || lsb_inst[head] == `Instlhu) && lsb_rs1_val[head] + lsb_imme[head] < 196608 ) begin
                        mem_wr <= 0 ;
                        LSB_mem_in_need <= 1 ;
                        req_addr <= lsb_rs1_val[head] + lsb_imme[head] ;
                        case (lsb_inst[head])
                            `Instlb: data_cnt <= 2 ;
                            `Instlh: data_cnt <= 3 ;
                            `Instlw: data_cnt <= 5 ;
                            `Instlbu: data_cnt <= 2 ;
                            `Instlhu: data_cnt <= 3 ;
                            default: ;
                        endcase

                   end 
                end
                if ( lsb_status[head] == 3 ) begin // settle IO here
                    mem_wr <= 0 ;
                    LSB_mem_in_need <= 1 ;
                    req_addr <= lsb_rs1_val[head] + lsb_imme[head] ;
                    LMDCollect <= lsb_rs2_val[head] ;
                    case (lsb_inst[head])
                        // IO read
                        `Instlb: data_cnt <= 2 ;
                        `Instlh: data_cnt <= 3 ;
                        `Instlw: data_cnt <= 5 ;
                        `Instlbu: data_cnt <= 2 ;
                        `Instlhu: data_cnt <= 3 ;
                        // write
                        `Instsb: begin 
                            mem_wr <= 1 ;
                            data_cnt <= 1 ;
                            write_data <= lsb_rs2_val[head][7:0] ;
                            last_write <= 1 ;
                        end
                        `Instsh: begin
                            mem_wr <= 1 ;
                            data_cnt <= 2 ;
                            write_data <= lsb_rs2_val[head][7:0] ;
                        end
                        `Instsw: begin
                            mem_wr <= 1 ;
                            data_cnt <= 4 ;
                            write_data <= lsb_rs2_val[head][7:0] ;
                        end
                    endcase
                end
            end
            end else begin
                last_full <= 1 ;
                if ( last_full == 0 && last_write == 1 ) begin
                    lsb_rdy <= 0 ;
                    lsb_status[(head+15)%16] <= 3 ;
                    head <= ( head + 15 ) % 16 ;
                end
            end

            // clear tag
            for ( i = 0 ; i < `LSB_SIZE ; i = i + 1 ) begin
            if ( lsb_status[i] == 2 ) begin
                if ( ROB_write_reg_rdy == 1  ) begin
                    if ( lsb_rs1_rely[i] == ROB_real_head_tag && lsb_rs1_rely[i] != 0) begin
                        lsb_rs1_rely[i] <= 0 ;
                        lsb_rs1_val[i] <= ROB_write_val ;
                    end
                    if ( lsb_rs2_rely[i] == ROB_real_head_tag && lsb_rs2_rely[i] != 0) begin
                        lsb_rs2_rely[i] <= 0 ;
                        lsb_rs2_val[i] <= ROB_write_val ;
                    end
                end
                if ( (lsb_rs1_rely[i] == 0 || ( ROB_write_reg_rdy == 1 && lsb_rs1_rely[i] == ROB_real_head_tag)) && (lsb_rs2_rely[i] == 0 || ( ROB_write_reg_rdy == 1 && lsb_rs2_rely[i] == ROB_real_head_tag)) ) begin
                    lsb_status[i] <= 1 ; // 表示 rs1 和 rs2 都清除了依赖关系
                end
            end

            // settle dispatch
            if ( dispatch_rdy == 1 && clear == 0) begin
                lsb_inst[rear] <= up_inst ; 
                lsb_tag[rear] <= next_tag ;
                lsb_imme[rear] <= up_imme ;
                lsb_rs1_val[rear] <= rs1_val ;
                lsb_rs1_rely[rear] <= rs1_rely ;
                lsb_rs2_val[rear] <= rs2_val ;
                lsb_rs2_rely[rear] <= rs2_rely ;
                lsb_status[rear] <= 2 ;
            if ( rs1_rely != 0 ) begin
                // ROB request
                if ( ROB_rs1_valid == 1 ) begin
                    lsb_rs1_val[rear] <= ROB_rs1_ans_output ;
                end
            end
            if ( rs2_rely != 0 ) begin
                // ROB request
                if ( ROB_rs2_valid == 1 ) begin
                    lsb_rs2_val[rear] <= ROB_rs2_ans_output ;
                end
            end
            if ( rs1_rely == 0 && rs2_rely == 0 ) begin
                lsb_status[rear] <= 1 ;
            end
            // 改进空间: 如果依赖在 CDB 和 ROB 中被改写了, 部分情况可以让 status 置 valid 快一个 clk
        end

        end

        end
    end

end


    
endmodule