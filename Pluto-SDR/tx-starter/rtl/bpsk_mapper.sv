// SPDX-License-Identifier: GPL-3.0-or-later
// BPSK at one sample per symbol, fixed half-scale signed 16-bit amplitude.
// RFNoC sc16 wire order is {I[15:0], Q[15:0]}.
`default_nettype none
module bpsk_mapper(input wire symbol_bit, output wire [31:0] iq);
  assign iq = {symbol_bit ? 16'h4000 : 16'hC000, 16'h0000};
endmodule
`default_nettype wire
