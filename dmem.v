module dmem(input clk,input [7:0] addr,input we,input [31:0] wdata,input re,output [31:0] rdata);
    reg [31:0] mem [0:255];
    integer i;
    initial begin
        $readmemh("dmem1.hex",mem);
        for (i=0;i<256;i=i+1) if (^mem[i] === 1'bx) mem[i]=0;
    end
    always @(posedge clk) begin
        if (we) mem[addr]<=wdata;
    end
    assign rdata=re?mem[addr]: 32'b0;
endmodule

