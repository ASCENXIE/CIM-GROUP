
module cimd_repair_en_512(CIMEN,REN,RA,REPAIR_EN);
input CIMEN;
input REN;
input [8:0] RA;

output [511:0]REPAIR_EN;
reg [511:0] REPAIR_EN;
always@(* )
begin
    if((REN==1'b1) && (CIMEN == 1'b1))
        REPAIR_EN = 512'b1 << RA;
    else REPAIR_EN=64'd0;
end

endmodule