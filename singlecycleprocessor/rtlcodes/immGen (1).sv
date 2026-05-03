module ImmGen (
    input  logic [31:0] instruction,
    output logic [31:0] immediate
);


//instruction[6:5]=opcode, instruction[14:12]=func3, instruction[31:25]=func7(for shift instructions)
always_comb begin
    case (instruction[6:0])

        // I-Type (LOAD) 
        7'b0000011: begin
            immediate = {{20{instruction[31]}}, instruction[31:20]};
        end

        // I-Type (ARITHMETIC) 
        7'b0010011: begin
            // Shift instructions: SLLI, SRLI, SRAI
            if ((instruction[14:12] == 3'b001 && instruction[31:25] == 7'b0000000) ||  // SLLI
                (instruction[14:12] == 3'b101 && instruction[31:25] == 7'b0000000) ||  // SRLI
                (instruction[14:12] == 3'b101 && instruction[31:25] == 7'b0100000))    // SRAI
            begin
                immediate = {27'd0, instruction[24:20]}; // shamt
            end
            else begin
                immediate = {{20{instruction[31]}}, instruction[31:20]};
            end
        end

        // S-Type
        7'b0100011: begin
            immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        end

        // B-Type (BRANCH)
        7'b1100011: begin
            immediate = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        end

        // J-Type 
        7'b1101111: begin
            immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
        end

        // I-Type (JALR) 
        7'b1100111: begin
            immediate = {{20{instruction[31]}}, instruction[31:20]};
        end

        // U-Type (LUI) 
        7'b0110111: begin
            immediate = {instruction[31:12], 12'b0};
        end

        //  U-Type (AUIPC) 
        7'b0010111: begin
            immediate = {instruction[31:12], 12'b0};
        end

        // Default 
        default: begin
            immediate = 32'b0;
        end

    endcase
end

endmodule