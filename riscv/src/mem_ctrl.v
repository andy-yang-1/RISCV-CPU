`include "constant.v"

module mem_ctrl (
    // ctrl
    input wire clk_in ,
    input wire rdy_in ,
    input wire rst_in ,

    // from fetch
    input wire [`AddrBus] fetch_req_addr ,

    // from LSB
    input wire LSB_mem_in_need ,
    input wire [`AddrBus] LSB_req_addr ,
    input wire LSB_mem_wr , // 0 -> read 
    input wire [`ByteBus] LSB_write_data ,

    // from memory
    input wire[`ByteBus] mem_din ,

    // to memory 
    output wire[`AddrBus] mem_a ,
    output wire[`ByteBus] mem_dout ,
    output wire mem_wr , // 要告诉 fetch 如果在 write valid 作废
    
    // to fetch
    output wire fetch_mem_rdy ,    
    output wire IO_is_writing ,
    
    // to fetch & LSB 
    output wire[`ByteBus] mem_byte

);

assign mem_byte = mem_din ;

assign mem_a = LSB_mem_in_need == 0 ? fetch_req_addr : LSB_req_addr ;

assign mem_wr = LSB_mem_in_need == 0 ? 0 : LSB_mem_wr ;

assign fetch_mem_rdy = LSB_mem_in_need == 0 ;

assign mem_dout = LSB_write_data ;

assign mem_byte = mem_din ;

assign IO_is_writing = LSB_mem_in_need == 1 &&( LSB_req_addr == 196608 || LSB_req_addr == 196612 ) ;

    
endmodule