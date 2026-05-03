    module pc (input  logic         clk,
           input  logic        rst,
           input  logic [31:0] in_addr,
           output logic [31:0] out_addr );

always_ff @(posedge clk or posedge rst) begin 
    
    if (rst) begin
        out_addr <= 32'h10000000;
    end
    else begin
        out_addr <= in_addr;
    end
end
endmodule