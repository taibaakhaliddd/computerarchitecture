module mux_4x1(
           input  logic [31:0] in1,
           input  logic [31:0] in2,
           input  logic [31:0] in3,
           input  logic [31:0] in4,
           input  logic [1 :0] sel,
           output logic [31:0] mux_out);

always_comb begin
    case(sel)
    2'b00: mux_out=in1;
    2'b01: mux_out=in2;
    2'b10: mux_out=in3;
    2'b11: mux_out=in4;
    endcase
end
endmodule