`include "opcode.vh"

module control_logic(
    input  logic [6:0]  opcode,
    output logic        branch,
    output logic        jump,
    output logic        MemRead,
    output logic        MemWrite,
    output logic [1:0]  MemtoReg,
    output logic [1:0]  ALUop,
    output logic        ALUsrc, 
    output logic        jalr, 
    output logic        RegWrite
);

always_comb begin
    branch=0;
    jump=0;
    jalr=0;
    MemRead=0;
    MemWrite=0;
    MemtoReg=2'b00;
    ALUop=2'b01;
    ALUsrc=0;
    RegWrite=0;


    case(opcode)

        7'b0110011: begin // R-type
        branch=0;
        jump=0;
        jalr=0;
        MemRead=0;
        MemtoReg=2'b00;
        ALUop=2'b10;
        MemWrite=0;
        ALUsrc=0;
        RegWrite=1;
        end
            
        7'b0000011: begin // I-type (load)
        branch=0;
        jump=0;
        jalr=0;
        MemRead=1;
        MemtoReg=2'b01;
        ALUop=2'b11;
        MemWrite=0;
        ALUsrc=1;
        RegWrite=1;
        end

        7'b0010011: begin // I-type (arithmetic)
        branch=0;
        jump=0;
        jalr=0;
        MemRead=0;
        MemtoReg=2'b00;
        ALUop=2'b01;
        MemWrite=0;
        ALUsrc=1;
        RegWrite=1;
        end
            
        7'b0100011: begin // S-type
        branch=0;
        jump=0;
        jalr=0;
        MemRead=0;
        MemtoReg=2'b00; 
        ALUop=2'b11;
        MemWrite=1;
        ALUsrc=1;
        RegWrite=0;
        end

        7'b1100011: begin // B-type
        branch=1;
        jump=0;
        jalr=0;
        MemRead=0;
        MemtoReg=2'b00;
        ALUop=2'b00;
        MemWrite=0;
        ALUsrc=0;
        RegWrite=0;
        end

        7'b1101111: begin // Jal type
        branch=0;
        jump=1;
        jalr=0;
        MemRead=0;
        MemtoReg=2'b10;
        ALUop=2'b01; //donot care
        MemWrite=0;
        ALUsrc=0; //x
        RegWrite=1;
        end

        7'b1100111: begin // jalr 
        branch=0;
        jump=1;
        jalr=1;
        MemRead=0;
        MemtoReg=2'b10;
        ALUop=2'b01; 
        MemWrite=0;
        ALUsrc=1; 
        RegWrite=1;
        end

        
        // 7'b0010111: begin // U-type(auipc)
        // branch=0;
        // jump=0;
        // jalr=0;
        // MemRead=0;
        // MemtoReg=2'b11;
        // ALUop=2'b00; //donot care
        // MemWrite=0;
        // ALUsrc=0;  //donot care
        // RegWrite=1;
        // end

        7'b0110111: begin // LUI 
        branch=0;
        jump=0;
        jalr=0;
        MemRead=0;
        MemtoReg=2'b11;
        ALUop=2'b00; //donot care
        MemWrite=0;
        ALUsrc=0;  //donot care
        RegWrite=1;
        end

    endcase
end

endmodule

