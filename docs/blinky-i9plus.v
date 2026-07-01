// Colorlight i9plus-v6.1 blinky
// Clock: 25MHz (K4), LED: A18
// LED toggles at ~0.5Hz (25MHz / 2^24 / 2 ≈ 0.75Hz)

module blink_top (
    input  wire clk_i,
    output wire led_o
);

    reg [24:0] counter;

    always @(posedge clk_i) begin
        counter <= counter + 1'b1;
    end

    // MSB をそのまま LED に出力 → 約 0.75Hz で点滅
    assign led_o = counter[24];

endmodule
