`include "constant.v"

module regFile (
    // ctrl
    input wire clk_in ,
    input wire rdy_in ,
    input wire rst_in ,

    // from dispatch
    input wire [`RegBus] rs1 , 
    input wire rs1_read_rdy , 
    input wire [`RegBus] rs2 , 
    input wire rs2_read_rdy , 
    input wire [`RegBus] dispatch_rd , 
    input wire dispatch_rd_in_need ,

    // from ROB 
    input wire [`ROBTagBus] next_tag , // empty pos 
    input wire [`ROBTagBus] now_tag , // commit pos
    input wire clear , // change pc 
    input wire [`RegValBus] write_val ,
    input wire [`RegBus] rd , 
    input wire write_rdy , 

`ifdef debug_show    

    // ROB debug pulse 
    input wire commit_pulse ,
    input wire [`AddrBus] commit_pc ,

`endif

    // to RS & LSB & ROB
    output reg [`RegValBus] rs1_val , 
    output reg [`ROBTagBus] rs1_rely ,
    output reg [`RegValBus] rs2_val  ,
    output reg [`ROBTagBus] rs2_rely

);

reg [`RegValBus] all_reg [`RegBitSize-1:0] ;
reg [`ROBTagBus] all_rely [`RegBitSize-1:0] ;

integer i = 0 ;

always @(posedge clk_in) begin
    if ( rst_in == 1 ) begin
        for ( i = 0 ; i < 32 ; i = i + 1 ) begin
            all_reg[i] <= 0 ; 
            all_rely[i] <= 0 ;
        end
    end else if ( rdy_in == 1 ) begin
        if ( clear == 1 ) begin
            for ( i = 0 ; i < 32 ; i = i + 1) begin
                all_rely[i] <= 0 ;
            end
        end 
        if ( write_rdy == 1 ) begin
            if ( all_rely[rd] == now_tag - 1 || all_rely[rd] == now_tag + 15 )
                all_rely[rd] <= 0 ;
            all_reg[rd] <= write_val ;
            all_reg[0] <= 0 ;
        end
        if ( dispatch_rd_in_need == 1 && clear == 0 ) begin
            all_rely[dispatch_rd] <= next_tag ;
            all_rely[0] <= 0 ;
        end
        
    end
end

always @(*) begin  
    rs1_val = 0 ;
    rs1_rely = 0 ;  
    rs2_val = 0 ;
    rs2_rely = 0 ;
    if ( rdy_in == 1 && rst_in == 0 ) begin
        if ( rs1_read_rdy == 1 ) begin
            rs1_rely = all_rely[rs1] ; // 读自己写自己是不会依赖错误的
            if ( write_rdy == 1 && rd == rs1 ) begin
                rs1_val = write_val ;
                if ( all_rely[rs1] == now_tag - 1 || all_rely[rs1] == now_tag + 15 ) 
                    rs1_rely = 0 ;
            end else begin
                rs1_val = all_reg[rs1] ;
            end
        end
        if ( rs2_read_rdy == 1 ) begin
            rs2_rely = all_rely[rs2] ; // 读自己写自己是不会依赖错误的
            if ( write_rdy == 1 && rd == rs2 ) begin
                rs2_val = write_val ;
                if ( all_rely[rs2] == now_tag - 1 || all_rely[rs2] == now_tag + 15 ) 
                    rs2_rely = 0 ;
            end else begin
                rs2_val = all_reg[rs2] ;
            end
        end
    end 
end


`ifdef debug_show


reg [31:0] cycle_cnt = 0 ;

integer out_file ;


initial begin
    out_file = $fopen("out.txt") ;
end

always @(posedge clk_in) begin
    if ( commit_pulse == 1 ) begin
    $fdisplay(out_file,"<------------------------------->") ;
    $fdisplay(out_file,"pc: %d",commit_pc) ;
    for (i = 0 ; i < 32 ; i = i + 1 ) begin
        if ( write_rdy == 1 && i == rd  )
            $fdisplay(out_file,"register  %d : %d",i,write_val) ;
        else    
            $fdisplay(out_file,"register  %d : %d",i,all_reg[i]) ;
    end
    $fdisplay(out_file,"<------------------------------->") ;
    end
    
end

`endif
    
endmodule