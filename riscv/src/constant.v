`timescale 1ns/1ps

//`define debug_show
//`define partial_show    20000
`define I_cache_added

`define AddrBus         31:0
`define InstBus         31:0 
`define RegBus          31:0
`define RegValBus       31:0
`define ImmediateBus    31:0
`define ALUOutputBus    31:0
`define LMDOutputBus    31:0
`define ByteBus         7:0
`define ROBTagBus       4:0
`define RegBitSize      32
`define RS_SIZE         16
`define LSB_SIZE        16
`define ROB_SIZE        16
`define I_cache_size    64

`define LayerStatusBus  1:0


// instructions

`define Instlui     0
`define Instauipc   1
`define Instjal     2
`define Instjalr    3
`define Instbeq     4
`define Instbne     5
`define Instblt     6
`define Instbge     7
`define Instbltu    8
`define Instbgeu    9
`define Instlb      10
`define Instlh      11
`define Instlw      12
`define Instlbu     13
`define Instlhu     14
`define Instsb      15
`define Instsh      16
`define Instsw      17
`define Instaddi    18
`define Instslti    19
`define Instsltiu   20
`define Instxori    21
`define Instori     22
`define Instandi    23
`define Instslli    24
`define Instsrli    25
`define Instsrai    26
`define Instadd     27
`define Instsub     28
`define Instsll     29
`define Instslt     30
`define Instsltu    31
`define Instxor     32
`define Instsrl     33
`define Instsra     34
`define Instor      35
`define Instand     36 


// define ctrl

// `define debug_show 0 