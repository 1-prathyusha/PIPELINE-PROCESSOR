// processor.v

// ALU
module alu(input [15:0] a, b,
           input [1:0] op,
           output reg [15:0] result);
  always @(*) begin
    case(op)
      2'b00: result = a + b;
      2'b01: result = a - b;
      default: result = 16'b0;
    endcase
  end
endmodule

// Register File
module register_file(input clk, input we,
                     input [3:0] raddr1, raddr2, waddr,
                     input [15:0] wdata,
                     output [15:0] rdata1, rdata2);
  reg [15:0] regs[0:15];

  assign rdata1 = regs[raddr1];
  assign rdata2 = regs[raddr2];

  always @(posedge clk) begin
    if (we) regs[waddr] <= wdata;
  end
endmodule

// Instruction Memory
module instruction_memory(input [3:0] pc,
                          output [15:0] instruction);
  reg [15:0] instr_mem[0:15];
  initial begin
    // opcode[15:12], rd[11:8], rs1[7:4], rs2_or_addr[3:0]
    instr_mem[0] = 16'b0001_0001_0010_0011; // ADD R1, R2, R3
    instr_mem[1] = 16'b0010_0010_0011_0100; // SUB R2, R3, R4
    instr_mem[2] = 16'b0011_0011_0000_1000; // LOAD R3, 8
  end
  assign instruction = instr_mem[pc];
endmodule

// Data Memory
module data_memory(input [7:0] addr,
                   output [15:0] data);
  reg [15:0] mem[0:255];
  initial begin
    mem[8] = 16'h00FF; // data for LOAD
  end
  assign data = mem[addr];
endmodule

// Main Processor
module pipelined_processor(input clk);
  reg [3:0] pc = 0;

  // Pipeline registers
  reg [15:0] IF_ID_instr;
  reg [15:0] ID_EX_rdata1, ID_EX_rdata2;
  reg [3:0]  ID_EX_rdest;
  reg [1:0]  ID_EX_op;
  reg        ID_EX_is_load;
  reg [7:0]  ID_EX_addr;

  reg [15:0] EX_MEM_result;
  reg [3:0]  EX_MEM_rdest;
  reg        EX_MEM_we;

  // Wires
  wire [15:0] instruction, rdata1, rdata2, alu_result, mem_data;

  // Modules
  instruction_memory im(pc, instruction);
  register_file rf(clk, EX_MEM_we, IF_ID_instr[11:8], IF_ID_instr[7:4], EX_MEM_rdest, EX_MEM_result, rdata1, rdata2);
  alu myalu(ID_EX_rdata1, ID_EX_rdata2, ID_EX_op, alu_result);
  data_memory dm(ID_EX_addr, mem_data);

  // Pipeline Stages
  always @(posedge clk) begin
    // IF Stage
    IF_ID_instr <= instruction;
    pc <= pc + 1;

    // ID Stage
    ID_EX_rdata1 <= rdata1;
    ID_EX_rdata2 <= rdata2;
    ID_EX_rdest  <= IF_ID_instr[11:8];
    ID_EX_addr   <= IF_ID_instr[3:0];

    case (IF_ID_instr[15:12])
      4'b0001: begin ID_EX_op <= 2'b00; ID_EX_is_load <= 0; end // ADD
      4'b0010: begin ID_EX_op <= 2'b01; ID_EX_is_load <= 0; end // SUB
      4'b0011: begin ID_EX_op <= 2'b00; ID_EX_is_load <= 1; end // LOAD
    endcase

    // EX Stage
    EX_MEM_result <= ID_EX_is_load ? mem_data : alu_result;
    EX_MEM_rdest <= ID_EX_rdest;
    EX_MEM_we <= 1;
  end
endmodule
