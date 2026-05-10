`timescale 1ns/1ps

module mips(
    input clk,
    input reset
);

reg [31:0] pc;
wire [31:0] pc_plus4 = pc + 4;

wire [31:0] instr;
wire [31:0] if_pc = pc;

reg [31:0] IF_ID_instr, IF_ID_pc;

wire [5:0] id_opcode = IF_ID_instr[31:26];
wire [5:0] id_funct  = IF_ID_instr[5:0];
wire [4:0] id_rs = IF_ID_instr[25:21];
wire [4:0] id_rt = IF_ID_instr[20:16];
wire [4:0] id_rd = IF_ID_instr[15:11];
wire [15:0] id_imm = IF_ID_instr[15:0];

wire [31:0] id_imm_se = {{16{id_imm[15]}}, id_imm};

reg [31:0] regfile [0:31];

wire [31:0] reg_rdata1 = regfile[id_rs];
wire [31:0] reg_rdata2 = regfile[id_rt];

reg id_regwrite, id_memread, id_memwrite;
reg id_memtoreg, id_alu_src;

reg [2:0] id_alu_ctrl;

always @(*) begin
    id_regwrite = 0;
    id_memread = 0;
    id_memwrite = 0;
    id_memtoreg = 0;
    id_alu_src = 0;
    id_alu_ctrl = 3'b010;

    case(id_opcode)

        6'b000000: begin
            id_regwrite = 1;

            if(id_funct == 6'b100000)
                id_alu_ctrl = 3'b010;
            else if(id_funct == 6'b100010)
                id_alu_ctrl = 3'b110;
        end

        6'b100011: begin
            id_regwrite = 1;
            id_memread = 1;
            id_memtoreg = 1;
            id_alu_src = 1;
        end

        6'b101011: begin
            id_memwrite = 1;
            id_alu_src = 1;
        end

        6'b001000: begin
            id_regwrite = 1;
            id_alu_src = 1;
        end

        6'b000100: begin
            id_alu_ctrl = 3'b110;
        end
    endcase
end

wire id_branch =
    (id_opcode == 6'b000100) &&
    (reg_rdata1 == reg_rdata2);

wire [31:0] branch_target =
    IF_ID_pc + 4 + (id_imm_se << 2);

reg [31:0] ID_EX_pc;
reg [31:0] ID_EX_regdata1;
reg [31:0] ID_EX_regdata2;
reg [31:0] ID_EX_imm;

reg [4:0] ID_EX_rs, ID_EX_rt, ID_EX_rd;

reg ID_EX_regwrite, ID_EX_memread;
reg ID_EX_memwrite, ID_EX_memtoreg;
reg ID_EX_alu_src;

reg [2:0] ID_EX_alu_ctrl;

reg [31:0] EX_MEM_aluout;
reg [31:0] EX_MEM_regdata2;

reg [4:0] EX_MEM_rd;

reg EX_MEM_regwrite, EX_MEM_memread;
reg EX_MEM_memwrite, EX_MEM_memtoreg;

reg [31:0] MEM_WB_memdata;
reg [31:0] MEM_WB_aluout;

reg [4:0] MEM_WB_rd;

reg MEM_WB_regwrite, MEM_WB_memtoreg;

reg [31:0] cycle_count;
reg [31:0] instr_count;
reg [31:0] stall_count;
reg [31:0] branch_count;

reg [31:0] clock_gated_cycles;

wire stall;

assign stall =
    ID_EX_memread &&
    (ID_EX_rt != 0) &&
    ((ID_EX_rt == id_rs) ||
     (ID_EX_rt == id_rt));

reg [1:0] forwardA, forwardB;

wire dmem_we;
wire dmem_re;

wire [31:0] dmem_addr;
wire [31:0] dmem_wdata;
wire [31:0] dmem_rdata;

wire [31:0] alu_op1;
wire [31:0] alu_op2_reg;
wire [31:0] alu_op2;

wire [31:0] alu_from_EXMEM;
wire [31:0] alu_from_MEMWB;

reg [31:0] EX_ALU_out;

wire if_id_clk_enable;
wire id_ex_clk_enable;
wire regfile_clk_enable;

assign if_id_clk_enable = !stall && !id_branch;

assign id_ex_clk_enable = !stall && !id_branch;

assign regfile_clk_enable = MEM_WB_regwrite && (MEM_WB_rd != 0);

reg if_id_clk_en_latch;
reg id_ex_clk_en_latch;
reg regfile_clk_en_latch;

always @(*) begin
    if (!clk) begin
        if_id_clk_en_latch = if_id_clk_enable;
        id_ex_clk_en_latch = id_ex_clk_enable;
        regfile_clk_en_latch = regfile_clk_enable;
    end
end

wire if_id_gated_clk = clk & if_id_clk_en_latch;
wire id_ex_gated_clk = clk & id_ex_clk_en_latch;
wire regfile_gated_clk = clk & regfile_clk_en_latch;

imem imem_inst(
    .addr(pc[9:2]),
    .instr(instr)
);

dmem dmem_inst(
    .clk(clk),
    .addr(dmem_addr[9:2]),
    .we(dmem_we),
    .wdata(dmem_wdata),
    .re(dmem_re),
    .rdata(dmem_rdata)
);

assign dmem_we = EX_MEM_memwrite;
assign dmem_re = EX_MEM_memread;

assign dmem_addr = EX_MEM_aluout;
assign dmem_wdata = EX_MEM_regdata2;

assign alu_from_EXMEM = EX_MEM_aluout;

assign alu_from_MEMWB =
    MEM_WB_memtoreg ?
    MEM_WB_memdata :
    MEM_WB_aluout;

assign alu_op1 =
    (forwardA == 2'b00) ? ID_EX_regdata1 :
    (forwardA == 2'b10) ? alu_from_EXMEM :
                          alu_from_MEMWB;

assign alu_op2_reg =
    (forwardB == 2'b00) ? ID_EX_regdata2 :
    (forwardB == 2'b10) ? alu_from_EXMEM :
                          alu_from_MEMWB;

assign alu_op2 =
    ID_EX_alu_src ?
    ID_EX_imm :
    alu_op2_reg;

integer i;

always @(posedge clk or posedge reset) begin

    if(reset) begin

        pc <= 0;

        IF_ID_instr <= 0;
        IF_ID_pc <= 0;

        ID_EX_pc <= 0;
        ID_EX_regdata1 <= 0;
        ID_EX_regdata2 <= 0;
        ID_EX_imm <= 0;

        ID_EX_rs <= 0;
        ID_EX_rt <= 0;
        ID_EX_rd <= 0;

        ID_EX_regwrite <= 0;
        ID_EX_memread <= 0;
        ID_EX_memwrite <= 0;
        ID_EX_memtoreg <= 0;
        ID_EX_alu_src <= 0;
        ID_EX_alu_ctrl <= 0;

        EX_MEM_aluout <= 0;
        EX_MEM_regdata2 <= 0;
        EX_MEM_rd <= 0;

        EX_MEM_regwrite <= 0;
        EX_MEM_memread <= 0;
        EX_MEM_memwrite <= 0;
        EX_MEM_memtoreg <= 0;

        MEM_WB_memdata <= 0;
        MEM_WB_aluout <= 0;
        MEM_WB_rd <= 0;

        MEM_WB_regwrite <= 0;
        MEM_WB_memtoreg <= 0;

        cycle_count <= 0;
        instr_count <= 0;
        stall_count <= 0;
        branch_count <= 0;
        clock_gated_cycles <= 0;

        for(i = 0; i < 32; i = i + 1)
            regfile[i] <= 0;

    end else begin

        cycle_count <= cycle_count + 1;

        if(!stall && !id_branch)
            instr_count <= instr_count + 1;

        if(stall)
            stall_count <= stall_count + 1;

        if(id_branch)
            branch_count <= branch_count + 1;

        if(!if_id_clk_enable || !id_ex_clk_enable || !regfile_clk_enable)
            clock_gated_cycles <= clock_gated_cycles + 1;

        MEM_WB_memdata <= dmem_rdata;
        MEM_WB_aluout <= EX_MEM_aluout;
        MEM_WB_rd <= EX_MEM_rd;

        MEM_WB_regwrite <= EX_MEM_regwrite;
        MEM_WB_memtoreg <= EX_MEM_memtoreg;

        EX_MEM_aluout <= EX_ALU_out;
        EX_MEM_regdata2 <= alu_op2_reg;
        EX_MEM_rd <= ID_EX_rd;

        EX_MEM_regwrite <= ID_EX_regwrite;
        EX_MEM_memread <= ID_EX_memread;
        EX_MEM_memwrite <= ID_EX_memwrite;
        EX_MEM_memtoreg <= ID_EX_memtoreg;

        if(id_branch) begin

            pc <= branch_target;

            IF_ID_instr <= 0;
            IF_ID_pc <= 0;

            ID_EX_pc <= 0;
            ID_EX_regdata1 <= 0;
            ID_EX_regdata2 <= 0;
            ID_EX_imm <= 0;

            ID_EX_rs <= 0;
            ID_EX_rt <= 0;
            ID_EX_rd <= 0;

            ID_EX_regwrite <= 0;
            ID_EX_memread <= 0;
            ID_EX_memwrite <= 0;
            ID_EX_memtoreg <= 0;
            ID_EX_alu_src <= 0;
            ID_EX_alu_ctrl <= 0;

        end else if(stall) begin

            pc <= pc;
            IF_ID_instr <= IF_ID_instr;
            IF_ID_pc <= IF_ID_pc;

            ID_EX_pc <= 0;
            ID_EX_regdata1 <= 0;
            ID_EX_regdata2 <= 0;
            ID_EX_imm <= 0;

            ID_EX_rs <= 0;
            ID_EX_rt <= 0;
            ID_EX_rd <= 0;

            ID_EX_regwrite <= 0;
            ID_EX_memread <= 0;
            ID_EX_memwrite <= 0;
            ID_EX_memtoreg <= 0;
            ID_EX_alu_src <= 0;
            ID_EX_alu_ctrl <= 0;

        end else begin

            pc <= pc_plus4;

            IF_ID_instr <= instr;
            IF_ID_pc <= if_pc;

            ID_EX_pc <= IF_ID_pc;

            ID_EX_regdata1 <= reg_rdata1;
            ID_EX_regdata2 <= reg_rdata2;

            ID_EX_imm <= id_imm_se;

            ID_EX_rs <= id_rs;
            ID_EX_rt <= id_rt;

            ID_EX_rd <=
                (id_opcode == 6'b000000) ?
                id_rd :
                id_rt;

            ID_EX_regwrite <= id_regwrite;
            ID_EX_memread <= id_memread;
            ID_EX_memwrite <= id_memwrite;
            ID_EX_memtoreg <= id_memtoreg;
            ID_EX_alu_src <= id_alu_src;
            ID_EX_alu_ctrl <= id_alu_ctrl;
        end
    end
end

always @(posedge regfile_gated_clk or posedge reset) begin
    if(reset) begin
        for(i = 0; i < 32; i = i + 1)
            regfile[i] <= 0;
    end else begin
        if(MEM_WB_regwrite && (MEM_WB_rd != 0))
            regfile[MEM_WB_rd] <=
                (MEM_WB_memtoreg ?
                 MEM_WB_memdata :
                 MEM_WB_aluout);
    end
end

always @(*) begin

    forwardA = 2'b00;
    forwardB = 2'b00;

    if(EX_MEM_regwrite &&
       (EX_MEM_rd != 0) &&
       (EX_MEM_rd == ID_EX_rs))
        forwardA = 2'b10;

    if(EX_MEM_regwrite &&
       (EX_MEM_rd != 0) &&
       (EX_MEM_rd == ID_EX_rt))
        forwardB = 2'b10;

    if(MEM_WB_regwrite &&
       (MEM_WB_rd != 0) &&
       (MEM_WB_rd == ID_EX_rs) &&
       !(EX_MEM_regwrite &&
       (EX_MEM_rd != 0) &&
       (EX_MEM_rd == ID_EX_rs)))
        forwardA = 2'b01;

    if(MEM_WB_regwrite &&
       (MEM_WB_rd != 0) &&
       (MEM_WB_rd == ID_EX_rt) &&
       !(EX_MEM_regwrite &&
       (EX_MEM_rd != 0) &&
       (EX_MEM_rd == ID_EX_rt)))
        forwardB = 2'b01;
end

always @(*) begin
    case(ID_EX_alu_ctrl)

        3'b010:
            EX_ALU_out = alu_op1 + alu_op2;

        3'b110:
            EX_ALU_out = alu_op1 - alu_op2;

        default:
            EX_ALU_out = alu_op1 + alu_op2;
    endcase
end

endmodule

