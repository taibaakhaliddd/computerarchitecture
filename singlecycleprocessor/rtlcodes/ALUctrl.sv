module ALUctrl(
    input  logic [1:0] ALUop,
    input  logic [2:0] func3,
    input  logic [6:0] func7,
    output logic [3:0] ALU_operation
);

always_comb begin
    ALU_operation = 4'b1111; // safe default

    case (ALUop)

        2'b11: begin
            // LOAD / STORE
            ALU_operation = 4'b0000;
        end

        2'b01: begin
            // I-type arithmetic
            case (func3)
                3'b000: ALU_operation = 4'b0000; // ADDI
                3'b100: ALU_operation = 4'b0100; // XORI
                3'b110: ALU_operation = 4'b0010; // ORI
                3'b111: ALU_operation = 4'b0011; // ANDI
                3'b010: ALU_operation = 4'b1000; // SLTI  (signed)
                3'b011: ALU_operation = 4'b1001; // SLTIU (unsigned) 
                3'b001: ALU_operation = 4'b0101; // SLLI 
                3'b101: ALU_operation = (func7 == 7'b0100000) ? 4'b0110 : 4'b0111;   // SRAI : SRLI 
                default: ALU_operation = 4'b1111;
            endcase
        end

        2'b00: begin
            // B-type
            case (func3)
                3'b000: ALU_operation = 4'b1010; // BEQ
                3'b001: ALU_operation = 4'b1011; // BNE
                3'b100: ALU_operation = 4'b1000; // BLT  (signed)
                3'b101: ALU_operation = 4'b1100; // BGE  (signed)
                3'b110: ALU_operation = 4'b1001; // BLTU (unsigned)
                3'b111: ALU_operation = 4'b1101; // BGEU (unsigned)
                default: ALU_operation = 4'b1111;
            endcase
        end

        2'b10: begin
            // R-type 
            case (func3)
                3'b000: ALU_operation = (func7 == 7'b0100000) ? 4'b0001 : 4'b0000; // SUB:ADD
                3'b001: ALU_operation = 4'b0101; // SLL
                3'b010: ALU_operation = 4'b1000; // SLT  (signed)
                3'b011: ALU_operation = 4'b1001; // SLTU
                3'b100: ALU_operation = 4'b0100; // XOR
                3'b101: ALU_operation = (func7 == 7'b0100000) ? 4'b0110 : 4'b0111; // SRA:SRL
                3'b110: ALU_operation = 4'b0010; // OR
                3'b111: ALU_operation = 4'b0011; // AND
                default: ALU_operation = 4'b1111;
            endcase
        end

    endcase
end
endmodule