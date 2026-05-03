module pc_adder(
    input logic  [31:0] out_addr,
    output logic [31:0] PCplus4
);


always_comb begin
    PCplus4 = out_addr + 32'd4;
end
    
endmodule