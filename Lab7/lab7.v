// You can use this skeleton testbench code, the textbook testbench code, or your own
module MIPS_Testbench ();
  reg CLK;
  reg RST;
  wire CS;
  wire WE;
  wire [31:0] Mem_Bus;
  wire [6:0] Address;

  initial
  begin
    CLK = 0;
  end

  MIPS CPU(CLK, RST, CS, WE, Address, Mem_Bus);
  Memory MEM(CS, WE, CLK, Address, Mem_Bus);

  always
  begin
    #5 CLK = !CLK;
  end

  always
  begin
    RST <= 1'b1; //reset the processor

    //Notice that the memory is initialize in the in the memory module not here

    @(posedge CLK);
    // driving reset low here puts processor in normal operating mode
    RST = 1'b0;

    /* add your testing code here */
    // you can add in a 'Halt' signal here as well to test Halt operation
    // you will be verifying your program operation using the
    // waveform viewer and/or self-checking operations

    $display("TEST COMPLETE");
    $stop;
  end

endmodule

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

module Complete_MIPS(CLK, RST, A_Out, D_Out);
  // Will need to be modified to add functionality
  input CLK;
  input RST;

  wire CS, WE;
  wire [6:0] ADDR;
  wire [31:0] Mem_Bus;

  MIPS CPU(CLK, RST, CS, WE, ADDR, Mem_Bus);
  Memory MEM(CS, WE, CLK, ADDR, Mem_Bus);

endmodule

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

module Memory(CS, WE, CLK, ADDR, Mem_Bus);
  input CS;
  input WE;
  input CLK;
  input [6:0] ADDR;
  inout [31:0] Mem_Bus;

  reg [31:0] data_out;
  reg [31:0] RAM [0:127];


  initial
  begin
    /* Write your Verilog-Text IO code here */
  end

  assign Mem_Bus = ((CS == 1'b0) || (WE == 1'b1)) ? 32'bZ : data_out;

  always @(negedge CLK)
  begin

    if((CS == 1'b1) && (WE == 1'b1))
      RAM[ADDR] <= Mem_Bus[31:0];

    data_out <= RAM[ADDR];
  end
endmodule

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

module REG(CLK, RegW, DR, SR1, SR2, Reg_In, ReadReg1, ReadReg2);
  input CLK;
  input RegW;
  input [4:0] DR;
  input [4:0] SR1;
  input [4:0] SR2;
  input [31:0] Reg_In;
  output reg [31:0] ReadReg1;
  output reg [31:0] ReadReg2;

  reg [31:0] REG [0:31];
  integer i;

  initial begin
    ReadReg1 = 0;
    ReadReg2 = 0;
  end

  always @(posedge CLK)
  begin

    if(RegW == 1'b1)
      REG[DR] <= Reg_In[31:0];

    ReadReg1 <= REG[SR1];
    ReadReg2 <= REG[SR2];
  end
endmodule


///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

`define opcode instr[31:26]
`define sr1 instr[25:21]
`define sr2 instr[20:16]
`define f_code instr[5:0]
`define numshift instr[10:6]

module MIPS (CLK, RST, CS, WE, ADDR, Mem_Bus);
  input CLK, RST;
  output reg CS, WE;
  output [6:0] ADDR;
  inout [31:0] Mem_Bus;

  //special instructions (opcode == 000000), values of F code (bits 5-0):
  parameter add = 6'b100000;
  parameter sub = 6'b100010;
  parameter xor1 = 6'b100110;
  parameter and1 = 6'b100100;
  parameter or1 = 6'b100101;
  parameter slt = 6'b101010;
  parameter srl = 6'b000010;
  parameter sll = 6'b000000;
  parameter jr = 6'b001000;
  parameter mult = 6'b011000;
  parameter mfhi = 6'b010000;
  parameter mflo = 6'b010010;
  parameter add8 = 6'b101101;
  parameter rbit = 6'b101111;
  parameter rev = 6'b110000;
  parameter sadd = 6'b110001;
  parameter ssub = 6'b110010;

  //non-special instructions, values of opcodes:
  parameter addi = 6'b001000;
  parameter andi = 6'b001100;
  parameter ori = 6'b001101;
  parameter lw = 6'b100011;
  parameter sw = 6'b101011;
  parameter beq = 6'b000100;
  parameter bne = 6'b000101;
  parameter j = 6'b000010;
  parameter jal = 6'b000011;
  parameter lui = 6'b001111;

  //instruction format
  parameter R = 2'd0;
  parameter I = 2'd1;
  parameter J = 2'd2;

  //internal signals
  reg [5:0] op, opsave;
  wire [1:0] format;
  reg [31:0] instr, alu_result;
  reg [6:0] pc, npc;
  wire [31:0] imm_ext, alu_in_A, alu_in_B, reg_in, readreg1, readreg2;
  reg [31:0] alu_result_save;
  reg alu_or_mem, alu_or_mem_save, regw, writing, reg_or_imm, reg_or_imm_save;
  reg fetchDorI;
  wire [4:0] dr;
  reg [2:0] state, nstate;
  reg [31:0] hi,lo;

  //combinational
  assign imm_ext = (instr[15] == 1)? {16'hFFFF, instr[15:0]} : {16'h0000, instr[15:0]};//Sign extend immediate field
  assign dr = (`opcode == jal) ? 5'd31 : (((`opcode == rbit) || (`opcode == rev))? instru[25:21]:((format == R)? instr[15:11] : instr[20:16])); //Destination Register MUX (MUX1)
  assign alu_in_A = readreg1;
  assign alu_in_B = (reg_or_imm_save)? imm_ext : readreg2; //ALU MUX (MUX2)
  assign reg_in = (alu_or_mem_save)? Mem_Bus : alu_result_save; //Data MUX
  assign format = (`opcode == 6'd0)? R : ((`opcode == 6'd2)? J : I);
  assign Mem_Bus = (writing)? readreg2 : 32'bZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ;

  //drive memory bus only during writes
  assign ADDR = (fetchDorI)? pc : alu_result_save[6:0]; //ADDR Mux
  REG Register(CLK, regw, dr, `sr1, `sr2, reg_in, readreg1, readreg2);

  initial begin
    op = and1; opsave = and1;
    state = 3'b0; nstate = 3'b0;
    alu_or_mem = 0;
    regw = 0;
    fetchDorI = 0;
    writing = 0;
    reg_or_imm = 0; reg_or_imm_save = 0;
    alu_or_mem_save = 0;
  end

  always @(*)
  begin
    fetchDorI = 0; CS = 0; WE = 0; regw = 0; writing = 0; alu_result = 32'd0;
    npc = pc; op = jr; reg_or_imm = 0; alu_or_mem = 0; nstate = 3'd0;
    case (state)
      0: begin //fetch
        npc = pc + 7'd1; CS = 1; nstate = 3'd1;
        fetchDorI = 1;
      end
      1: begin //decode
        nstate = 3'd2; reg_or_imm = 0; alu_or_mem = 0;
        if (format == J) begin //jump, and finish
          npc = instr[6:0];
          nstate = 3'd0;
        end
        else if (format == R) //register instructions
          op = `f_code;
        else if (format == I) begin //immediate instructions
          reg_or_imm = 1;
          if(`opcode == lw) begin
            op = add;
            alu_or_mem = 1;
          end
          else if ((`opcode == lw)||(`opcode == sw)||(`opcode == addi)) op = add;
          else if ((`opcode == beq)||(`opcode == bne)) begin
            op = sub;
            reg_or_imm = 0;
          end
          else if (`opcode == andi) op = and1;
          else if (`opcode == ori) op = or1;
		  else if (`opcode == jal) op = jal;
		  else if (`opcode == lui) op = lui;
        end
      end
      2: begin //execute //dont know how to do mult
        nstate = 3'd3;
        if (opsave == and1) alu_result = alu_in_A & alu_in_B;
        else if (opsave == or1) alu_result = alu_in_A | alu_in_B;
        else if (opsave == add) alu_result = alu_in_A + alu_in_B;
        else if (opsave == sub) alu_result = alu_in_A - alu_in_B;
        else if (opsave == srl) alu_result = alu_in_B >> `numshift;
        else if (opsave == sll) alu_result = alu_in_B << `numshift;
        else if (opsave == slt) alu_result = (alu_in_A < alu_in_B)? 32'd1 : 32'd0;
        else if (opsave == xor1) alu_result = alu_in_A ^ alu_in_B;
        if (((alu_in_A == alu_in_B)&&(`opcode == beq)) || ((alu_in_A != alu_in_B)&&(`opcode == bne))) begin
          npc = pc + imm_ext[6:0];
          nstate = 3'd0;
        end
        else if ((`opcode == bne)||(`opcode == beq)) nstate = 3'd0;
        else if (opsave == jr) begin
          npc = alu_in_A[6:0];
          nstate = 3'd0;
        end
		else if (opsave == jal) begin
			npc = instr[7:0];
			alu_result = pc + 7'd1;
		end
		else if (opsave == lui) alu_result = {instr[15:0] << 16 , 16'b0000000000000000};
		else if (opsave == mfhi) alu_result = hi;
		else if (opsave == mflo) alu_result = lo;
		else if (opsave == add8) begin
			alu_result[31:24] <= alu_in_A[31:24] + alu_in_B[31:24];
			alu_result[23:16] <= alu_in_A[23:16] + alu_in_B[23:16];
			alu_result[15:8] <= alu_in_A[15:8] + alu_in_B[15:8];
			alu_result[7:0] <= alu_in_A[7:0] + alu_in_B[7:0];
		end
		else if (opsave == rbit) begin
			alu_result[31] <= alu_in_B[0];
			alu_result[30] <= alu_in_B[1];
			alu_result[29] <= alu_in_B[2];
			alu_result[28] <= alu_in_B[3];
			alu_result[27] <= alu_in_B[4];
			alu_result[26] <= alu_in_B[5];
			alu_result[25] <= alu_in_B[6];
			alu_result[24] <= alu_in_B[7];
			alu_result[23] <= alu_in_B[8];
			alu_result[22] <= alu_in_B[9];
			alu_result[21] <= alu_in_B[10];
			alu_result[20] <= alu_in_B[11];
			alu_result[19] <= alu_in_B[12];
			alu_result[18] <= alu_in_B[13];
			alu_result[17] <= alu_in_B[14];
			alu_result[16] <= alu_in_B[15];
			alu_result[15] <= alu_in_B[16];
			alu_result[14] <= alu_in_B[17];
			alu_result[13] <= alu_in_B[18];
			alu_result[12] <= alu_in_B[19];
			alu_result[11] <= alu_in_B[20];
			alu_result[10] <= alu_in_B[21];
			alu_result[9] <= alu_in_B[22];
			alu_result[8] <= alu_in_B[23];
			alu_result[7] <= alu_in_B[24];
			alu_result[6] <= alu_in_B[25];
			alu_result[5] <= alu_in_B[26];
			alu_result[4] <= alu_in_B[27];
			alu_result[3] <= alu_in_B[28];
			alu_result[2] <= alu_in_B[29];
			alu_result[1] <= alu_in_B[30];
			alu_result[0] <= alu_in_B[31];
		end
		else if (opsave == rev) begin
			alu_result[31:24] <= alu_in_B[7:0];
			alu_result[23:16] <= alu_in_B[15:8];
			alu_result[15:8] <= alu_in_B[23:16];
			alu_result[7:0] <= alu_in_B[31:24];
		end
		else if (opsave == sadd) alu_result = ((alu_in_A + alu_in_B) > 32'hffffffff) ? 32'hffffffff : (alu_in_A + alu_in_B);
		else if (opsave == ssub) alu_result = ((alu_in_A - alu_in_B) < 32'd0) ? 32'd0 : (alu_in_A - alu_in_B);
      3: begin //prepare to write to mem
        nstate = 3'd0;
        if (((format == R)&&(`f_code != mult))||(`opcode == addi)||(`opcode == andi)||(`opcode == ori)||(`opcode == jal)||(`opcode == lui)) regw = 1;
        else if (`opcode == sw) begin
          CS = 1;
          WE = 1;
          writing = 1;
        end
        else if (`opcode == lw) begin
          CS = 1;
          nstate = 3'd4;
        end
      end
      4: begin
        nstate = 3'd0;
        CS = 1;
        if (`opcode == lw) regw = 1;
      end
    endcase
  end //always

  always @(posedge CLK) begin

    if (RST) begin
      state <= 3'd0;
      pc <= 7'd0;
    end
    else begin
      state <= nstate;
      pc <= npc;
    end

    if (state == 3'd0) instr <= Mem_Bus;
    else if (state == 3'd1) begin
      opsave <= op;
      reg_or_imm_save <= reg_or_imm;
      alu_or_mem_save <= alu_or_mem;
    end
    else if (state == 3'd2) alu_result_save <= alu_result;

  end //always

endmodule
