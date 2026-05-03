`timescale 1ns/1ns

`include "C:/Users/fatim/OneDrive/Desktop/single cycle proc_lab/opcode.vh"
`include "C:/Users/fatim/OneDrive/Desktop/single cycle proc_lab/mem_path.vh"
`include "opcode.vh"

module cpu_tb();
    reg clk, rst;
    parameter CPU_CLOCK_PERIOD = 20; // 20ns clock period = 50MHz

    // ── Test tracking signals ─────────────────────────
    reg [31:0]  cycle;               // counts clks within current test
    reg         done;                // 1 when test just passed
    reg [31:0]  current_test_id   = 0;
    reg [255:0] current_test_type;   // name of running test
    reg [31:0]  current_output;      // what CPU actually produced
    reg [31:0]  current_result;      // what we expect
    reg         all_tests_passed  = 0;

    // ── Instruction building helpers ──────────────────
    reg [4:0]  RD, RS1, RS2;        // register numbers
    reg [31:0] RD1, RD2;            // values loaded into RS1, RS2
    reg [4:0]  SHAMT;               // shift amount for SLLI/SRLI
    reg [31:0] IMM, IMM0;           // immediate values
    reg [14:0] INST_ADDR;           // word index into Imem
    reg [14:0] DATA_ADDR;           // byte address into Dmem
    reg [14:0] DATA_ADDR0;
    reg [31:0] JUMP_ADDR;           // word index of jump target

    // ── Branch test operands and names ───────────────
    // sized [1:0] — only BEQ(0) and BNE(1) tested
    reg [31:0]  BR_TAKEN_OP1  [1:0];
    reg [31:0]  BR_TAKEN_OP2  [1:0];
    reg [31:0]  BR_NTAKEN_OP1 [1:0];
    reg [31:0]  BR_NTAKEN_OP2 [1:0];
    reg [2:0]   BR_TYPE       [1:0]; // funct3 for branch instruction
    reg [255:0] BR_NAME_TK1   [1:0];
    reg [255:0] BR_NAME_TK2   [1:0];
    reg [255:0] BR_NAME_NTK   [1:0];

    // ── 50MHz clock generation ────────────────────────
    initial clk = 0;
    always #(CPU_CLOCK_PERIOD/2) clk = ~clk; // toggle every 10ns

    // ── Connect DUT ───────────────────────────────────
    cpu cpu ( .clk(clk), .rst(rst) );

    wire [31:0] timeout_cycle = 10; // fail if test takes >10 cycles

    // ─────────────────────────────────────────────────
    // BACKDOOR WRITE TASKS
    // force/release used instead of direct assignment
    // so RTL can keep always_ff (single-driver rule)
    // force temporarily overrides always_ff driver
    // release hands control back to RTL
    // ─────────────────────────────────────────────────

    // Write one word into Imem at word index idx
    task write_imem;
        input [13:0] idx;
        input [31:0] data;
        begin
            force `IMEM_PATH.memory[idx] = data;
            #1;
            release `IMEM_PATH.memory[idx];
        end
    endtask

    // Write one word into Dmem at byte address idx
    task write_dmem;
        input [31:0] idx;
        input [31:0] data;
        begin
            force `DMEM_PATH.memory[idx] = data;
            #1;
            release `DMEM_PATH.memory[idx];
        end
    endtask

    // Write one value into register file at index idx
    task write_reg;
        input [4:0]  idx;
        input [31:0] data;
        begin
            force `REGFILE_PATH.Registers[idx] = data;
            #1;
            release `REGFILE_PATH.Registers[idx];
        end
    endtask

    // ─────────────────────────────────────────────────
    // RESET TASK
    // Clears all registers, Dmem and fills Imem with
    // NOPs (ADDI x0,x0,0) so no X propagates if CPU
    // fetches an unwritten location
    // ─────────────────────────────────────────────────
    task reset;
        integer i;
        begin
            // clear all 32 registers
            for (i = 0; i < 32; i = i + 1) begin
                force `REGFILE_PATH.Registers[i] = 32'd0;
            end
            #1;
            for (i = 0; i < 32; i = i + 1)
                release `REGFILE_PATH.Registers[i];

            // clear entire Dmem
            for (i = 0; i < 65536; i = i + 1) begin
                force `DMEM_PATH.memory[i] = 32'd0;
            end
            #1;
            for (i = 0; i < 65536; i = i + 1)
                release `DMEM_PATH.memory[i];

            // fill Imem with NOPs — safe fetches after test ends
            for (i = 0; i < 16384; i = i + 1) begin
                force `IMEM_PATH.memory[i] = 32'h00000013;
            end
            #1;
            for (i = 0; i < 16384; i = i + 1)
                release `IMEM_PATH.memory[i];
        end
    endtask

    // ─────────────────────────────────────────────────
    // RESET CPU TASK
    // Pulses rst=1 for one clock + 30ns then releases
    // This resets PC back to 0x10000000
    // Registers NOT cleared here — reset() handles that
    // ─────────────────────────────────────────────────
    task reset_cpu;
        begin
            rst = 1;
            @(posedge clk); // wait one rising edge
            #30;            // extra half cycle for stability
            rst = 0;        // release — CPU starts fetching
        end
    endtask

    // ─────────────────────────────────────────────────
    // TIMEOUT WATCHDOG
    // Runs in parallel with main test thread
    // If any test takes >10 cycles → simulation fails
    // ─────────────────────────────────────────────────
    initial begin
        while (all_tests_passed === 0) begin
            @(posedge clk);
            if (cycle === timeout_cycle) begin
                $display("[Failed] Timeout at [%d] test %s, expected = %h, got = %h",
                          current_test_id, current_test_type,
                          current_result, current_output);
                $finish();
            end
        end
    end

    // cycle counter — resets to 0 after each passed test
    always @(posedge clk) begin
        if (done === 0) cycle <= cycle + 1;
        else            cycle <= 0;
    end

    // ─────────────────────────────────────────────────
    // CHECK REGISTER FILE
    // Polls destination register on every falling edge
    // !== checks for X values too (not just wrong values)
    // Passes when register holds expected result
    // ─────────────────────────────────────────────────
    task check_result_rf;
        input [31:0]  rf_wa;    // destination register number
        input [31:0]  result;   // expected value
        input [255:0] test_type;
        begin
            done = 0;
            current_test_id   = current_test_id + 1;
            current_test_type = test_type;
            current_result    = result;

            // keep checking every negedge until match
            while (`REGFILE_PATH.Registers[rf_wa] !== result) begin
                current_output = `REGFILE_PATH.Registers[rf_wa];
                @(negedge clk);
            end

            cycle = 0;
            done  = 1;
            $display("[%d] Test %s passed!", current_test_id, test_type);
        end
    endtask

    // ─────────────────────────────────────────────────
    // CHECK DATA MEMORY
    // Same polling approach but checks Dmem location
    // Used for SW (store word) test
    // ─────────────────────────────────────────────────
    task check_result_dmem;
        input [31:0]  addr;     // byte address to check
        input [31:0]  result;
        input [255:0] test_type;
        begin
            done = 0;
            current_test_id   = current_test_id + 1;
            current_test_type = test_type;
            current_result    = result;

            while (`DMEM_PATH.memory[addr] !== result) begin
                current_output = `DMEM_PATH.memory[addr];
                @(negedge clk);
            end

            cycle = 0;
            done  = 1;
            $display("[%d] Test %s passed!", current_test_id, test_type);
        end
    endtask

    // ══════════════════════════════════════════════════
    // MAIN TEST SEQUENCE
    // ══════════════════════════════════════════════════
    initial begin
        rst = 0;

        // initialize all memories before first test
        reset();

        // initial PC reset — CPU starts at 0x10000000
        rst = 1;
        repeat (1) @(posedge clk);
        @(negedge clk);
        rst = 0;

        // ── R-Type: ADD SUB SLL XOR OR AND SRL ───────
        // Also tests SLLI and SRLI (I-type shifts)
        // RS1=x1=-100, RS2=x2=200, results in x3..x14
        RS1   = 1;  RD1 = -100;
        RS2   = 2;  RD2 =  200;
        RD    = 3;
        SHAMT = 5'd20; // shift amount for SLLI/SRLI
        INST_ADDR = 14'h0000;

        write_reg(RS1, RD1); // x1 = -100
        write_reg(RS2, RD2); // x2 =  200

        // encode and write 9 instructions into Imem
        write_imem(INST_ADDR+0, {`FNC7_0, RS2,   RS1, `FNC_ADD_SUB, 5'd3,  `OPC_ARI_RTYPE}); // ADD  x3,x1,x2
        write_imem(INST_ADDR+1, {`FNC7_1, RS2,   RS1, `FNC_ADD_SUB, 5'd4,  `OPC_ARI_RTYPE}); // SUB  x4,x1,x2
        write_imem(INST_ADDR+2, {`FNC7_0, RS2,   RS1, `FNC_SLL,     5'd5,  `OPC_ARI_RTYPE}); // SLL  x5,x1,x2
        write_imem(INST_ADDR+3, {`FNC7_0, RS2,   RS1, `FNC_XOR,     5'd8,  `OPC_ARI_RTYPE}); // XOR  x8,x1,x2
        write_imem(INST_ADDR+4, {`FNC7_0, RS2,   RS1, `FNC_OR,      5'd9,  `OPC_ARI_RTYPE}); // OR   x9,x1,x2
        write_imem(INST_ADDR+5, {`FNC7_0, RS2,   RS1, `FNC_AND,     5'd10, `OPC_ARI_RTYPE}); // AND  x10,x1,x2
        write_imem(INST_ADDR+6, {`FNC7_0, RS2,   RS1, `FNC_SRL_SRA, 5'd11, `OPC_ARI_RTYPE}); // SRL  x11,x1,x2
        write_imem(INST_ADDR+7, {`FNC7_0, SHAMT, RS1, `FNC_SLL,     5'd13, `OPC_ARI_ITYPE}); // SLLI x13,x1,20
        write_imem(INST_ADDR+8, {`FNC7_0, SHAMT, RS1, `FNC_SRL_SRA, 5'd14, `OPC_ARI_ITYPE}); // SRLI x14,x1,20

        reset_cpu(); // PC→0x10000000, start fetching

        check_result_rf(5'd3,  32'h00000064, "R-Type ADD");  // -100+200=100
        check_result_rf(5'd4,  32'hfffffed4, "R-Type SUB");  // -100-200=-300
        check_result_rf(5'd5,  32'hffff9c00, "R-Type SLL");  // -100<<(200&31)
        check_result_rf(5'd8,  32'hffffff54, "R-Type XOR");
        check_result_rf(5'd9,  32'hffffffdc, "R-Type OR");
        check_result_rf(5'd10, 32'h00000088, "R-Type AND");
        check_result_rf(5'd11, 32'h00ffffff, "R-Type SRL");
        check_result_rf(5'd13, 32'hf9c00000, "R-Type SLLI"); // -100<<20
        check_result_rf(5'd14, 32'h00000fff, "R-Type SRLI"); // -100>>20 logical

        // ── I-Type Arithmetic: ADDI XORI ORI ANDI ────
        // RS1=x1=-100, IMM=-200
        // instructions at indices 0,3,4,5 (gaps are NOPs)
        reset();

        RS1 = 1; RD1 = -100;
        IMM = -200;
        INST_ADDR = 14'h0000;

        write_reg(RS1, RD1); // x1 = -100

        write_imem(INST_ADDR+0, {IMM[11:0], RS1, `FNC_ADD_SUB, 5'd3, `OPC_ARI_ITYPE}); // ADDI x3,x1,-200
        write_imem(INST_ADDR+3, {IMM[11:0], RS1, `FNC_XOR,     5'd6, `OPC_ARI_ITYPE}); // XORI x6,x1,-200
        write_imem(INST_ADDR+4, {IMM[11:0], RS1, `FNC_OR,      5'd7, `OPC_ARI_ITYPE}); // ORI  x7,x1,-200
        write_imem(INST_ADDR+5, {IMM[11:0], RS1, `FNC_AND,     5'd8, `OPC_ARI_ITYPE}); // ANDI x8,x1,-200

        reset_cpu();

        check_result_rf(5'd3, 32'hfffffed4, "I-Type ADD"); // -100+(-200)=-300
        check_result_rf(5'd6, 32'h000000a4, "I-Type XOR");
        check_result_rf(5'd7, 32'hffffffbc, "I-Type OR");
        check_result_rf(5'd8, 32'hffffff18, "I-Type AND");

        // ── I-Type Load: LW ───────────────────────────
        // x1=base=0x100, imm=0, loads from Dmem[0x100]
        reset();

        IMM0      = 32'h0000_0000;
        INST_ADDR = 14'h0000;
        DATA_ADDR = (32'h0000_0100 + IMM0[11:0]); // effective address

        write_reg(1, 32'h0000_0100);         // base address in x1
        write_dmem(DATA_ADDR, 32'hdeadbeef); // put test value in memory
        write_imem(INST_ADDR+0, {IMM0[11:0], 5'd1, `FNC_LW, 5'd2, `OPC_LOAD}); // LW x2,0(x1)

        reset_cpu();
        check_result_rf(5'd2, 32'hdeadbeef, "I-Type LW"); // x2 should = 0xdeadbeef

        // ── S-Type Store: SW ──────────────────────────
        // SW stores x1 into Dmem[x2+imm]
        // x1=0x12345678 (data), x2=0x10 (base), imm=0x100
        reset();

        IMM0       = 32'h0000_0100;
        INST_ADDR  = 14'h0000;
        DATA_ADDR0 = (32'h0000_0010 + IMM0[11:0]); // = 0x110

        write_reg(1, 32'h12345678);   // data to store
        write_reg(2, 32'h0000_0010);  // base address
        write_dmem(DATA_ADDR0, 32'd0);// pre-clear destination
        write_imem(INST_ADDR+0, {IMM0[11:5], 5'd1, 5'd2, `FNC_SW, IMM0[4:0], `OPC_STORE}); // SW x1,256(x2)

        reset_cpu();
        check_result_dmem(DATA_ADDR0, 32'h12345678, "S-Type SW");

        // ── U-Type: LUI ──────────────────────────────
        // LUI loads upper 20 bits into rd, zeros lower 12
        // IMM=0x7FFF0123 → upper20=0x7FFF0 → result=0x7FFF0000
        reset();

        IMM       = 32'h7FFF_0123;
        INST_ADDR = 14'h0000;

        write_imem(INST_ADDR+0, {IMM[31:12], 5'd3, `OPC_LUI}); // LUI x3, 0x7FFF0

        reset_cpu();
        check_result_rf(3, 32'h7fff0000, "U-Type LUI");

        // ── J-Type: JAL ──────────────────────────────
        // JAL x5, 0xFF0 → jumps to PC+0xFF0, saves PC+4 in x5
        // PC=0x10000000 so target=0x10000FF0, x5=0x10000004
        // instruction at memory[1] must NOT execute (skipped)
        // instruction at jump target must execute (ADD x7=x3+x4=700)
        reset();

        IMM       = 32'h0000_0FF0;
        INST_ADDR = 14'h0000;
        JUMP_ADDR = (32'h1000_0000 + {IMM[20:1], 1'b0}) >> 2; // word index of target

        write_reg(1, 100); write_reg(2, 200);
        write_reg(3, 300); write_reg(4, 400);

        write_imem(INST_ADDR+0,     {IMM[20], IMM[10:1], IMM[11], IMM[19:12], 5'd5, `OPC_JAL}); // JAL x5,0xFF0
        write_imem(INST_ADDR+1,     {`FNC7_0, 5'd2, 5'd1, `FNC_ADD_SUB, 5'd6, `OPC_ARI_RTYPE}); // ADD x6 — skipped
        write_imem(JUMP_ADDR[13:0], {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd7, `OPC_ARI_RTYPE}); // ADD x7=300+400

        reset_cpu();

        check_result_rf(5'd5, 32'h1000_0004, "J-Type JAL"); // return addr
        check_result_rf(5'd7, 700,            "J-Type JAL"); // executed at target
        check_result_rf(5'd6, 0,              "J-Type JAL"); // skipped → still 0

        // ── B-Type: BEQ taken/not-taken ──────────────
        // BEQ branches if RS1==RS2
        // Taken:     x1=100, x2=100 → equal   → jump to target → x6=700
        //            instruction at memory[1] skipped → x5=0
        // Not taken: x1=100, x2=200 → unequal → fall through → x5=700
        #100;
        IMM       = 32'h0000_0FF0;
        INST_ADDR = 14'h0000;
        JUMP_ADDR = (32'h0000ff0) >> 2; // word index of branch target

        BR_TYPE[0]       = `FNC_BEQ;
        BR_NAME_TK1[0]   = "B-Type BEQ Taken 1";
        BR_NAME_TK2[0]   = "B-Type BEQ Taken 2";
        BR_NAME_NTK[0]   = "B-Type BEQ Not Taken";
        BR_TAKEN_OP1[0]  = 100; BR_TAKEN_OP2[0]  = 100; // equal → taken
        BR_NTAKEN_OP1[0] = 100; BR_NTAKEN_OP2[0] = 200; // unequal → not taken

        BR_TYPE[1]       = `FNC_BNE;
        BR_NAME_TK1[1]   = "B-Type BNE Taken 1";
        BR_NAME_TK2[1]   = "B-Type BNE Taken 2";
        BR_NAME_NTK[1]   = "B-Type BNE Not Taken";
        BR_TAKEN_OP1[1]  = 100; BR_TAKEN_OP2[1]  = 200; // unequal → BNE taken
        BR_NTAKEN_OP1[1] = 100; BR_NTAKEN_OP2[1] = 200;

        // BEQ branch TAKEN (x1==x2 → jump)
        reset();
        write_reg(1, BR_TAKEN_OP1[0]); // x1=100
        write_reg(2, BR_TAKEN_OP2[0]); // x2=100
        write_reg(3, 300);
        write_reg(4, 400);

        write_imem(INST_ADDR+0, {IMM[12], IMM[10:5], 5'd2, 5'd1, BR_TYPE[0], IMM[4:1], IMM[11], `OPC_BRANCH}); // BEQ x1,x2
        write_imem(INST_ADDR+1, {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd5, `OPC_ARI_RTYPE}); // ADD x5 — skipped
        write_imem(JUMP_ADDR,   {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd6, `OPC_ARI_RTYPE}); // ADD x6=300+400

        reset_cpu();
        check_result_rf(5'd5, 0,   BR_NAME_TK1[0]); // skipped → 0
        check_result_rf(5'd6, 700, BR_NAME_TK2[0]); // executed at target

        // BEQ branch NOT TAKEN (x1!=x2 → fall through)
        reset();
        write_reg(1, BR_NTAKEN_OP1[1]); // x1=100
        write_reg(2, BR_NTAKEN_OP2[1]); // x2=200 → not equal
        write_reg(3, 300);
        write_reg(4, 400);

        write_imem(INST_ADDR+0, {IMM[12], IMM[10:5], 5'd2, 5'd1, BR_TYPE[0], IMM[4:1], IMM[11], `OPC_BRANCH}); // BEQ x1,x2
        write_imem(INST_ADDR+1, {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd5, `OPC_ARI_RTYPE}); // ADD x5=300+400

        reset_cpu();
        check_result_rf(5'd5, 700, BR_NAME_NTK[0]); // executed → 700

        // ── All tests passed ──────────────────────────
        all_tests_passed = 1'b1;
        repeat (100) @(posedge clk);
        $display("All tests passed!");
        $finish();
    end

endmodule