// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.1 (lin64) Build 2552052 Fri May 24 14:47:09 MDT 2019
// Date        : Mon Sep 14 14:38:39 2020
// Host        : rdsrv300 running 64-bit Ubuntu 20.04.1 LTS
// Command     : write_verilog -force -mode synth_stub
//               /u/ec/weaver/projects/l2si-hsd/firmware/common/PC821/Fmc126/coregen/serdes_mmcm_stub.v
// Design      : serdes_mmcm
// Purpose     : Stub declaration of top-level module interface
// Device      : xcku085-flvb1760-2-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module serdes_mmcm(clk_out1, clk_out2, clk_out3, psclk, psen, 
  psincdec, psdone, reset, locked, clk_in1)
/* synthesis syn_black_box black_box_pad_pin="clk_out1,clk_out2,clk_out3,psclk,psen,psincdec,psdone,reset,locked,clk_in1" */;
  output clk_out1;
  output clk_out2;
  output clk_out3;
  input psclk;
  input psen;
  input psincdec;
  output psdone;
  input reset;
  output locked;
  input clk_in1;
endmodule
