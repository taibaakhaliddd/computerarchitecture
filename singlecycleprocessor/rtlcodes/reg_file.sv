module reg_file (
    input  logic        clk,
    input  logic        rst,
    input  logic [4:0]  read_reg1,
    input  logic [4:0]  read_reg2,
    input  logic [4:0]  write_reg,
    input  logic        RegWrite,
    input  logic [31:0] write_data,
    output logic [31:0] read_data1,
    output logic [31:0] read_data2
);

logic [31:0] Registers [31:0];

initial begin
    for (int i = 0; i < 32; i++)
        Registers[i] = 32'd0;
end

always_comb begin
    read_data1 = Registers[read_reg1];
    read_data2 = Registers[read_reg2];
end

// plain always so TB can backdoor-write Registers[]
// only x0 is reset on rst — TB's reset() task clears the rest explicitly
always @(posedge clk or posedge rst) begin
    if (rst)
        Registers[0] <= 32'd0;      // x0 always 0
    else if (RegWrite && write_reg != 5'd0)
        Registers[write_reg] <= write_data;
end

endmodule