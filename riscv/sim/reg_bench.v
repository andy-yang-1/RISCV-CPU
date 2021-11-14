//~ `New testbench
`include "../src/constant.v"


module tb_regFile;

// regFile Parameters
parameter PERIOD  = 10;

reg clk = 0 ;
reg rst_n = 0 ;

// regFile Inputs
reg   clk_in                               = 0 ;
reg   rdy_in                               = 0 ;
reg   rst_in                               = 0 ;
reg   stall                                = 0 ;
reg   [`RegBus] rs1                        = 0 ;
reg   rs1_read_rdy                         = 0 ;
reg   [`RegBus] rs2                        = 0 ;
reg   rs2_read_rdy                         = 0 ;
reg     write_val               = 0 ;
reg   [`RegBus] rd                         = 0 ;
reg   write_rdy                            = 0 ;

// regFile Outputs
wire    rs1_val                 ;
wire    rs2_val                 ;
wire  rs1_read_fin                         ;
wire  rs2_read_fin                         ;
wire  write_fin                            ;




initial
begin
    #(PERIOD*2) rst_n  =  1;
end

regFile  u_regFile (
    .clk_in                  ( clk_in                   ),
    .rdy_in                  ( rdy_in                   ),
    .rst_in                  ( rst_in                   ),
    .stall                   ( stall                    ),
    .rs1           ( rs1            ),
    .rs1_read_rdy            ( rs1_read_rdy             ),
    . rs2           (  rs2            ),
    .rs2_read_rdy            ( rs2_read_rdy             ),
    .  write_val  (   write_val   ),
    . rd            ( rd             ),
    .write_rdy               ( write_rdy                ),

    .  rs1_val    (   rs1_val     ),
    .  rs2_val    (   rs2_val     ),
    .rs1_read_fin            ( rs1_read_fin             ),
    .rs2_read_fin            ( rs2_read_fin             ),
    .write_fin               ( write_fin                )
);

initial
begin
    # 20
    repeat(50)begin
        #
    end

    $finish;
end

endmodule

// python3 .vscode/extensions/truecrab.verilog-testbench-instance-0.0.5/out/vTbgenerator.py Desktop/small_project/RISCV-CPU/riscv/src/regFile.v