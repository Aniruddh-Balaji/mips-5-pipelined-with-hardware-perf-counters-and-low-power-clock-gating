`timescale 1ns/1ps

module tb;

reg clk, reset;

mips cpu(
    .clk(clk),
    .reset(reset)
);

initial clk = 0;
always #5 clk = ~clk;

integer cycle;

initial begin

    $dumpfile("mips.vcd");
    $dumpvars(0, tb);

    reset = 1;
    #20;
    reset = 0;

    for(cycle = 0; cycle < 25; cycle = cycle + 1) begin

        @(posedge clk);
        #1;

        $display("cycle=%0d pc=%0d branches=%0d stalls=%0d instr=%0d",
                 cpu.cycle_count,
                 cpu.pc,
                 cpu.branch_count,
                 cpu.stall_count,
                 cpu.instr_count,
	 	cpu.clock_gated_cycles);
    end

    $finish;
end

endmodule

