`include "constant.v" 

module decode (
    // ctrl
    input wire clk_in ,
    input wire rdy_in ,
    input wire rst_in ,

    // from fetch
    input wire[`InstBus] up_inst ,
    input wire[`AddrBus] up_npc ,

    // to dispatch
    output reg[`InstBus] to_inst ,
    output reg[`AddrBus] to_npc ,
    output reg [`RegBus] to_rs1 , 
    output reg rs1_in_need ,
    output reg [`RegBus] to_rs2 ,
    output reg rs2_in_need , 
    output reg [`RegBus] to_rd ,
    output reg rd_in_need ,
    output reg mem_in_need ,
    output reg [`ImmediateBus] to_imme 

);

wire [6:0] opcode = up_inst[6:0] ; 

wire [31:0] U_Immediate = {up_inst[31:12],{(12){1'b0}}} ;
wire [31:0] J_Immediate = {{12{up_inst[31:31]}},up_inst[19:12],up_inst[20:20],up_inst[30:21],1'b0} ;
wire [31:0] I_Immediate = {{21{up_inst[31:31]}},up_inst[30:20]} ;
wire [31:0] B_Immediate = {{20{up_inst[31:31]}},up_inst[7:7],up_inst[30:25],up_inst[11:8],1'b0} ;
wire [31:0] S_Immediate = {{21{up_inst[31:31]}},up_inst[30:25],up_inst[11:7]} ;

always @(*) begin
    
    to_inst = 0 ;
    to_npc = 0 ;
    to_rs1 = 0 ;
    rs1_in_need = 0 ;
    to_rs2 = 0 ;
    rs2_in_need = 0 ;
    to_rd = 0 ;
    rd_in_need = 0 ;
    mem_in_need = 0 ;
    to_imme = 0 ;
    
    if ( rst_in == 1 ) begin
        ;
    end else if (rdy_in == 1) begin

        to_npc = up_npc ;
        to_rd[4:0] = up_inst[11:7] ;
        to_rs1[4:0] = up_inst[19:15] ;
        to_rs2[4:0] = up_inst[24:20] ;

        case (opcode)
            7'b0110111: begin
                to_imme = U_Immediate ; // U 型立即数
                rs1_in_need = 0 ;
                rs2_in_need = 0 ;
                rd_in_need = 1 ;
                to_inst = `Instlui ;
            end

            7'b0010111: begin
                to_imme = U_Immediate ; // U 型立即数
                rs1_in_need = 0 ;
                rs2_in_need = 0 ;
                rd_in_need = 1 ;
                to_inst = `Instauipc ;
            end

            7'b1101111: begin
                to_imme = J_Immediate ; // J 型立即数
                rs1_in_need = 0 ;
                rs2_in_need = 0 ;
                rd_in_need = 1 ;
                to_inst = `Instjal ;
            end

            7'b1100111: begin
                to_imme = I_Immediate ; // I 型立即数
                rs1_in_need = 1 ;
                rs2_in_need = 0 ;
                rd_in_need = 1 ;
                to_inst = `Instjalr ;
            end

            7'b1100011: begin
                to_imme = B_Immediate ; // B 型立即数
                rs1_in_need = 1 ;
                rs2_in_need = 1 ;
                rd_in_need = 0 ;
                case (up_inst[14:12]) // func 3
                    3'b000: to_inst = `Instbeq ;
                    3'b001: to_inst = `Instbne ;
                    3'b100: to_inst = `Instblt ;
                    3'b101: to_inst = `Instbge ;
                    3'b110: to_inst = `Instbltu ;
                    3'b111: to_inst = `Instbgeu ; 
//                    default: $display("error: B option overflow") ;
                endcase
            end

            7'b0000011: begin
                to_imme = I_Immediate  ; // I 型立即数
                rs1_in_need = 1 ;
                rs2_in_need = 0 ;
                rd_in_need = 1 ;
                mem_in_need = 1 ;
                case (up_inst[14:12]) // func 3
                    3'b000: to_inst = `Instlb ;
                    3'b001: to_inst = `Instlh ;
                    3'b010: to_inst = `Instlw ;
                    3'b100: to_inst = `Instlbu ;
                    3'b101: to_inst = `Instlhu ; 
 //                   default: $display("error: I option overflow") ;
                endcase
            end

            // todo shamt 好像和 immediate 取值结果相同(因此无影响)

            7'b0100011: begin
                to_imme = S_Immediate  ; // S 型立即数
                rs1_in_need = 1 ;
                rs2_in_need = 1 ;
                rd_in_need = 0 ;
                mem_in_need = 1 ;
                case (up_inst[14:12]) // func 3
                    3'b000: to_inst = `Instsb ;
                    3'b001: to_inst = `Instsh ;
                    3'b010: to_inst = `Instsw ;
 //                   default: $display("error: S option overflow %d",up_inst[14:12]) ;
                endcase
            end

            7'b0010011: begin
                to_imme = I_Immediate  ; // I 型立即数
                rs1_in_need = 1 ;
                rs2_in_need = 0 ;
                rd_in_need = 1 ;
                case (up_inst[14:12]) // func 3
                    3'b000: to_inst = `Instaddi ;
                    3'b010: to_inst = `Instslti ;
                    3'b011: to_inst = `Instsltiu ;
                    3'b100: to_inst = `Instxori ;
                    3'b110: to_inst = `Instori ;
                    3'b111: to_inst = `Instandi ;
                    3'b001: to_inst = `Instslli ;
                    3'b101: begin
                        to_imme = {{7{1'b0}},up_inst[24:20]} ;
                        case(up_inst[31:25])  // func7
                            7'b0000000: to_inst = `Instsrli ;
                            7'b0100000: to_inst = `Instsrai ;
 //                           default: $display("error I func7 option overflow") ;
                        endcase
                    end
                    default: $display("error: I option overflow") ;
                endcase
            end

            7'b0110011: begin
                to_imme = 0  ; // R 无立即数
                rs1_in_need = 1 ;
                rs2_in_need = 1 ;
                rd_in_need = 1 ;
                case (up_inst[14:12]) // func 3
                    3'b000: begin
                        case (up_inst[31:25])
                            7'b0000000: to_inst = `Instadd ;
                            7'b0100000: to_inst = `Instsub ;
//                            default: $display("error: R func7 option overflow") ;
                        endcase
                    end
                    3'b001: to_inst = `Instsll ;
                    3'b010: to_inst = `Instslt ;
                    3'b011: to_inst = `Instsltu ;
                    3'b100: to_inst = `Instxor ;
                    3'b101: begin
                        case(up_inst[31:25])
                            7'b0000000: to_inst = `Instsrl ;
                            7'b0100000: to_inst = `Instsra ;
//                            default: $display("error: R func7 option overflow") ;
                        endcase
                    end 
                    3'b110: to_inst = `Instor ;
                    3'b111: to_inst = `Instand ;
 //                   default: $display("error: R option overflow") ;
                endcase
            end

 //           default: $display("error: decode option overflow %d",opcode) ;
        endcase

    end
end
    
endmodule