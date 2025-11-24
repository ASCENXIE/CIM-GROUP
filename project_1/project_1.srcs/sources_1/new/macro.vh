`ifndef MACRO_VH_
`define MACRO_VH_
`define MEM_MODE 0
`define CIM_MODE 1
`define MEM_R 0
`define MEM_W 1
`define P4MODE 0
`define P8MODE 1
`define SIGNED 0
`define UNSIGN 1

`ifdef ROW64
    `define GROUP_NUM 1 
`else 
    `define GROUP_NUM 8
`endif

`endif