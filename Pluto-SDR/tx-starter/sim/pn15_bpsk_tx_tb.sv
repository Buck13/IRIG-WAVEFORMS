`timescale 1ns/1ps
module pn15_bpsk_tx_tb;
  parameter integer SPS = 8;
  reg clk = 0;
  always #5 clk = ~clk;
  reg reset = 1, enable = 0, restart = 0, ready = 0;
  reg [14:0] seed = 15'h7fff;
  wire [31:0] data;
  wire valid;
  reg reference_default [0:32766];
  reg reference_alternate [0:32766];
  integer accepted = 0, total = 0;
  bit alternate = 0;
  bit was_stalled = 0;
  reg [31:0] held_data;
  pn15_bpsk_tx #(.SAMPLES_PER_SYMBOL(SPS)) dut (
    .clk(clk), .reset(reset), .enable(enable), .restart(restart), .seed(seed),
    .m_axis_tdata(data), .m_axis_tvalid(valid), .m_axis_tready(ready)
  );

  task cycle(input bit next_enable, input bit next_ready);
    bit expected_bit;
    integer index;
    @(negedge clk);
    enable = next_enable;
    ready = next_ready;
    @(posedge clk);
    if (was_stalled && (!valid || data !== held_data))
      $fatal(1, "Data/valid changed during a stall");
    if (valid && ready) begin
      index = (accepted / SPS) % 32767;
      expected_bit = alternate ? reference_alternate[index] : reference_default[index];
      if (data !== (expected_bit ? 32'h40000000 : 32'hc0000000))
        $fatal(1, "PN/BPSK mismatch at sample %0d: %h", accepted, data);
      accepted++;
      total++;
    end
    was_stalled = valid && !ready;
    held_data = data;
    #1;
  endtask

  task load_seed(input reg [14:0] next_seed, input bit use_alternate);
    @(negedge clk);
    seed = next_seed;
    restart = 1;
    @(posedge clk); #1;
    if (valid !== 0) $fatal(1, "Restart did not clear valid");
    accepted = 0;
    alternate = use_alternate;
    was_stalled = 0;
    @(negedge clk); restart = 0;
  endtask

  initial begin
    $readmemh("pn15_default.mem", reference_default);
    $readmemh("pn15_alternate.mem", reference_alternate);
    repeat (3) @(negedge clk);
    reset = 0;
    // Full period plus wraparound, with random backpressure and enable pauses.
    while (accepted < (32767+32)*SPS)
      cycle($urandom_range(0, 9) != 0, $urandom_range(0, 3) != 0);
    // Disable must retain an already offered sample under backpressure.
    cycle(1, 0);
    repeat (20) cycle(0, 0);
    repeat (4) cycle(0, 1);
    if (valid !== 0) $fatal(1, "Disable did not drain the pending sample");
    // Explicit restart may discard a pending sample and restarts symbol phase.
    cycle(1, 0);
    load_seed(15'h1234, 1);
    while (accepted < (32767+32)*SPS) cycle(1, $urandom_range(0, 3) != 0);
    // Illegal all-zero seed is deterministically replaced with all ones.
    load_seed(0, 0);
    while (accepted < 64*SPS) cycle(1, 1);
    $display("PASS: PN15 BPSK TX, SPS=%0d, %0d accepted samples", SPS, total);
    $finish;
  end
  initial begin
    #20000000;
    $fatal(1, "TX test timeout");
  end
endmodule

module pn15_bpsk_tx_tb_sps1;
  pn15_bpsk_tx_tb #(.SPS(1)) testbench();
endmodule
module pn15_bpsk_tx_tb_sps8;
  pn15_bpsk_tx_tb #(.SPS(8)) testbench();
endmodule
