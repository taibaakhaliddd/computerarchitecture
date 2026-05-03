
module branch_adder(input  logic [31:0] branch_src,
                    input  logic [31:0] immediate,
                    output logic [31:0] pc_target
);

always_comb begin
    pc_target = branch_src + immediate;
end

endmodule