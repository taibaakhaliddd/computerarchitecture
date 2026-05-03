module Dmem (
    input  logic        clk,
    input  logic        MemWrite,
    input  logic        MemRead,
    input  logic [31:0] address,
    input  logic [31:0] write_data,
    output logic [31:0] read_data
);

logic [31:0] memory [65535:0]; 

always_ff @(posedge clk) begin 
    if (MemWrite)
        memory[address] <= write_data; 
end 

always_comb begin
    if (MemRead)
        read_data = memory[address]; 
end

endmodule