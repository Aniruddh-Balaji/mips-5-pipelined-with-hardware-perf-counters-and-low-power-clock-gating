# mips-5-pipelined-with-hardware-perf-counters-and-low-power-clock-gating
This is a basic implementation of a 5 stage pipelined mips processor with hardware perf counters and clock gating in verilog
## hardware performance counters
> These are special registers in the proccessor that track events during execution
### implementation
```` verilog
reg [31:0] cycle_count;         
reg [31:0] instr_count;         
reg [31:0] stall_count;         
reg [31:0] branch_count;        
reg [31:0] clock_gated_cycles;
````
1. cycle count:
> This counts the number of cyles elapsed useful for cpi calculations
```` verilog
always @(posedge clk or posedge reset) begin
    if(reset)
        cycle_count <= 0;
    else
        cycle_count <= cycle_count + 1;  // Increment every cycle
end 
````
2. intruction count
> counts the number of instructions that are fetched and do useful work (not stalled or flushed due to wrong branches) 
3. stall count
```` verilog
if(stall)
    stall_count <= stall_count + 1;
````
4. branch count:
## low power clock gating
> Low power clock gating allows us to conserve power by stopping toggling of the clock when idle 
+ power=a*C*V²*f where alpha is the amount of toggling 
+ solution:To reduce power consumption don't toggle clock when idle
### method-1
` wire gated_clk = clk & enable; `
> This fails as it causes glitches, glitches occur due to propogation delay of the signals.Glitches occur when enable toggles when the clk is high.This can lead to error by unnecessarily updating the register file.
### method-2
```` verilog 
reg enable_latch;
always @(*) begin
    if (!clk)
        enable_latch = enable;  // Only update when clk=0
end
wire gated_clk = clk & enable_latch; 
````
> This removes the glitch by updating enable latch only when clock is 0
### implementation
1. When there is a control hazard
> The next instruction fetched could be wrong insert bubble and don't toggle clock
2. When there is a load-use hazard
> Stalls are inserted in 
3. When regfile is not updated
```` wire regfile_clk_enable = MEM_WB_regwrite && (MEM_WB_rd != 0);wire regfile_clk_enable = MEM_WB_regwrite && (MEM_WB_rd != 0);
 ````
