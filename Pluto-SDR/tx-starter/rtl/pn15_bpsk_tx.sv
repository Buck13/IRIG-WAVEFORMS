// SPDX-License-Identifier: GPL-3.0-or-later
// Platform-independent TX source. Connect ready to an actual sample consumer.
// b[n+15] = b[n+14] XOR b[n], polynomial x^15 + x^14 + 1.
// Output bit is state[0]; shift right and insert feedback into state[14].
`default_nettype none
module pn15_bpsk_tx #(
  parameter integer SAMPLES_PER_SYMBOL = 8
) (
  input wire clk,
  input wire reset,
  input wire enable,
  input wire restart,
  input wire [14:0] seed,
  output wire [31:0] m_axis_tdata,
  output reg m_axis_tvalid,
  input wire m_axis_tready
);
  localparam integer COUNT_W = (SAMPLES_PER_SYMBOL > 1) ?
                               $clog2(SAMPLES_PER_SYMBOL) : 1;
  reg [14:0] state;
  reg [COUNT_W-1:0] sample_index;

  // Reuse the already tested BPSK mapper. Word order is I then Q.
  bpsk_mapper mapper (.symbol_bit(state[0]), .iq(m_axis_tdata));

  always @(posedge clk) begin
    if (reset || restart) begin
      state <= (seed == 0) ? 15'h7fff : seed;
      sample_index <= 0;
      m_axis_tvalid <= 0;
    end else if (!m_axis_tvalid || m_axis_tready) begin
      m_axis_tvalid <= enable;
      if (m_axis_tvalid && m_axis_tready) begin
        if (sample_index == SAMPLES_PER_SYMBOL-1) begin
          state <= {state[14] ^ state[0], state[14:1]};
          sample_index <= 0;
        end else begin
          sample_index <= sample_index + 1'b1;
        end
      end
    end
  end
endmodule
`default_nettype wire
