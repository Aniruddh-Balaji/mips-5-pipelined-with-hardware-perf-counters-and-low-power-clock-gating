# mips-5-pipelined-with-hardware-perf-counters-and-low-power-clock-gating

This project is a basic implementation of a 5-stage pipelined MIPS processor in Verilog with:

- Hardware performance counters
- Hazard detection and forwarding
- Low-power clock gating

---

# Hardware Performance Counters

Hardware performance counters are special registers used to monitor processor behavior during execution. These counters help analyze:

- pipeline efficiency
- stalls
- branch behavior
- clock gating effectiveness
- CPI (Cycles Per Instruction)

## Implementation

```verilog
reg [31:0] cycle_count;
reg [31:0] instr_count;
reg [31:0] stall_count;
reg [31:0] branch_count;
reg [31:0] clock_gated_cycles;
```

---

## 1. Cycle Counter

Counts the total number of clock cycles elapsed during execution.

Useful for:
- CPI calculation
- performance analysis
- throughput measurement

```verilog
always @(posedge clk or posedge reset) begin
    if(reset)
        cycle_count <= 0;
    else
        cycle_count <= cycle_count + 1;
end
```

---

## 2. Instruction Counter

Counts instructions that successfully perform useful work.

Instructions stalled or flushed due to hazards are not counted.

Useful for:
- IPC/CPI calculations
- pipeline efficiency analysis

---

## 3. Stall Counter

Counts the number of cycles lost due to pipeline stalls.

```verilog
if(stall)
    stall_count <= stall_count + 1;
```

Stalls occur due to:
- load-use hazards
- branch hazards

---

## 4. Branch Counter

Counts the number of taken branches during execution.

Useful for:
- control hazard analysis
- branch performance evaluation

---

## 5. Clock Gated Cycles Counter

Counts cycles where clock gating disables unnecessary switching activity.

Useful for:
- low-power analysis
- estimating dynamic power savings

---

# Low Power Clock Gating

Clock gating reduces dynamic power consumption by disabling the clock to inactive hardware blocks.

Dynamic power equation:

```text
P = αCV²f
```

Where:
- α = switching activity
- C = capacitance
- V = supply voltage
- f = clock frequency

Reducing clock toggling lowers switching activity and therefore reduces power consumption.

---

# Clock Gating Methods

## Method 1 — Direct AND Gating

```verilog
wire gated_clk = clk & enable;
```

### Problem

This method can generate glitches.

If `enable` changes while the clock is HIGH, unwanted pulses may occur because of propagation delays.

These glitches can:
- incorrectly trigger registers
- corrupt pipeline state
- cause unintended writes

---

## Method 2 — Latch-Based Safe Clock Gating

```verilog
reg enable_latch;

always @(*) begin
    if (!clk)
        enable_latch = enable;
end

wire gated_clk = clk & enable_latch;
```

### Why This Works

The enable signal is updated only when the clock is LOW.

During the HIGH phase:
- enable remains stable
- no glitches are generated
- gated clock becomes safe

This is the standard technique used in practical clock-gating designs.

---

# Clock Gating Implementation in This Project

Clock gating is used to reduce unnecessary switching activity in the pipeline and register file.

---

## 1. Pipeline Stall and Control Hazard Gating

During:
- load-use hazards
- branch hazards
- pipeline flushes

pipeline registers are prevented from updating.

```verilog
assign if_id_clk_enable = !stall && !id_branch;
assign id_ex_clk_enable = !stall && !id_branch;
```

This prevents unnecessary toggling in:
- IF/ID register
- ID/EX register

---

## 2. Register File Clock Gating

The register file clock is enabled only when a valid write occurs.

```verilog
assign regfile_clk_enable =
    MEM_WB_regwrite && (MEM_WB_rd != 0);
```

If no register write is required:
- the register file clock does not toggle
- dynamic power consumption is reduced

---

## 3. Safe Gated Clock Generation

```verilog
always @(*) begin
    if (!clk)
        regfile_clk_en_latch = regfile_clk_enable;
end

wire regfile_gated_clk =
    clk & regfile_clk_en_latch;
```

This ensures glitch-free clock gating for the register file.
# forwarding unit
```` verilog
always @(*) begin
    forwardA = 2'b00;
    forwardB = 2'b00;

    // EX hazard forwarding
    if (EX_MEM_regwrite &&
        EX_MEM_rd != 0 &&
        EX_MEM_rd == ID_EX_rs)
        forwardA = 2'b10;

    if (EX_MEM_regwrite &&
        EX_MEM_rd != 0 &&
        EX_MEM_rd == ID_EX_rt)
        forwardB = 2'b10;

    // MEM hazard forwarding
    if (MEM_WB_regwrite &&
        MEM_WB_rd != 0 &&
        MEM_WB_rd == ID_EX_rs &&
        !(EX_MEM_regwrite && EX_MEM_rd == ID_EX_rs))
        forwardA = 2'b01;

    if (MEM_WB_regwrite &&
        MEM_WB_rd != 0 &&
        MEM_WB_rd == ID_EX_rt &&
        !(EX_MEM_regwrite && EX_MEM_rd == ID_EX_rt))
        forwardB = 2'b01;
end
````
```` verilog
assign alu_op1 =
    (forwardA == 2'b00) ? ID_EX_regdata1 :
    (forwardA == 2'b10) ? EX_MEM_aluout :
                          MEM_WB_aluout;

assign alu_op2 =
    ID_EX_alu_src ? ID_EX_imm :
    (forwardB == 2'b00) ? ID_EX_regdata2 :
    (forwardB == 2'b10) ? EX_MEM_aluout :
                          MEM_WB_aluout;
````
# stall unit
```` verilog
wire stall;
wire load_use_stall;
wire branch_stall;

assign load_use_stall =
    ID_EX_memread &&
    (ID_EX_rt != 0) &&
    (
        (ID_EX_rt == id_rs) ||
        (ID_EX_rt == id_rt)
    );

assign branch_stall =
    (id_opcode == 6'b000100) &&
    (
        (ID_EX_regwrite &&
         (ID_EX_rd != 0) &&
         ((ID_EX_rd == id_rs) || (ID_EX_rd == id_rt)))
        ||
        (EX_MEM_regwrite &&
         (EX_MEM_rd != 0) &&
         ((EX_MEM_rd == id_rs) || (EX_MEM_rd == id_rt)))
    );

assign stall = load_use_stall || branch_stall;
````
```` verilog
else if(stall) begin
    pc <= pc;
    IF_ID_instr <= IF_ID_instr;
    IF_ID_pc <= IF_ID_pc;

    ID_EX_regwrite <= 0;
    ID_EX_memread <= 0;
    ID_EX_memwrite <= 0;
    ID_EX_memtoreg <= 0;
    ID_EX_alu_src <= 0;
    ID_EX_alu_ctrl <= 0;
end
````


