`timescale 1ns/1ps
module tb;
reg clk, reset;
mips cpu(
    .clk(clk),
    .reset(reset)
);
initial clk=0;
always #5 clk=~clk;
integer cycle;
initial begin
    $dumpfile("mips.vcd");
    $dumpvars(0,tb);
    reset=1;
    #20;
    reset=0;
    for(cycle=0;cycle<45;cycle=cycle+1) begin
        @(posedge clk);
        #1;
        $display("cycle=%0d pc=%0d branches=%0d stalls=%0d instr=%0d",cpu.cycle_count,cpu.pc,cpu.branch_count,cpu.stall_count,cpu.instr_count);
    end
    $display("$at=%0d",cpu.regfile[1]);
    $display("$v0=%0d",cpu.regfile[2]);
    $display("$v1=%0d",cpu.regfile[3]);
    $display("$a0=%0d",cpu.regfile[4]);
    $display("$a1=%0d",cpu.regfile[5]);
    $display("$a2=%0d",cpu.regfile[6]);
    $display("$a3=%0d",cpu.regfile[7]);
    $display("$t0=%0d",cpu.regfile[8]);
    $display("$t1=%0d",cpu.regfile[9]);
    $display("$t2=%0d",cpu.regfile[10]);
    $display("$t3=%0d",cpu.regfile[11]);
    $display("$t4=%0d",cpu.regfile[12]);
    $display("$t5=%0d",cpu.regfile[13]);
    $display("$t6=%0d",cpu.regfile[14]);
    $display("$t7=%0d",cpu.regfile[15]);
    $display("$t8=%0d",cpu.regfile[24]);
    $finish;
end
endmodule

