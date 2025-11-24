//Macro
`define Macro_num                      6
`define Local_input_channel_width      9
`define Local_output_channel_width     6
`define Macro_psum_width               22
`define Macro_psum_8out_width          8*`Macro_psum_width
`define Input_feature_width            8*64
`define Input_weight_width             2*64

`define Local_adder_tree_psum          8*`Macro_num*`Macro_psum_width

//Tile
`define Tile_num                       9
`define Input_channel_width            11
`define Output_channel_width           7