module Imem (
    input  logic [31:0] addr,
    output logic [31:0] instr
);

logic [31:0] memory [16383:0];

always_comb begin
    instr = memory[addr[15:2]]; 
end

endmodule