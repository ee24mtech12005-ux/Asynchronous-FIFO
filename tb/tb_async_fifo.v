`timescale 1ps/1ps
// Self-checking testbench for async_fifo
// Clock periods are given in ps so that any (unrelated) frequency ratio can be tested.
module tb_async_fifo;
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter DEPTH      = 1 << ADDR_WIDTH;
    parameter WCLK_PS    = 10000;     // 100 MHz
    parameter RCLK_PS    = 25000;     // 40  MHz
    parameter NUM_RAND   = 2000;      // transactions in random phases
    parameter TAG        = "run";
    parameter SEED_W     = 11;
    parameter SEED_R     = 29;
    parameter MAXQ       = 16384;

    reg                   wclk = 0, rclk = 0, wrst_n = 0, rrst_n = 0;
    reg                   winc = 0, rinc = 0;
    reg  [DATA_WIDTH-1:0] wdata = 0;
    wire [DATA_WIDTH-1:0] rdata;
    wire                  wfull, rempty;

    async_fifo #(DATA_WIDTH, ADDR_WIDTH) dut (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty));

    always #(WCLK_PS/2) wclk = ~wclk;
    always #(RCLK_PS/2) rclk = ~rclk;

    // ---------------- scoreboard ----------------
    reg [DATA_WIDTH-1:0] expected [0:MAXQ-1];
    integer wr_idx = 0, rd_idx = 0, errors = 0;
    integer max_occ = 0, occ;
    integer full_events = 0, empty_events = 0;
    integer overflow_attempts = 0, underflow_attempts = 0;
    integer seed_w = SEED_W, seed_r = SEED_R;

    // percentage probability of request per clock; w_go/r_go gate the drivers
    integer w_prob = 0, r_prob = 0;
    reg     w_go = 0, r_go = 0;
    integer w_limit = 0;                    // max accepted writes allowed overall (0 = no limit)

    // write side: log every ACCEPTED write
    always @(posedge wclk) begin
        if (wrst_n && winc && !wfull) begin
            expected[wr_idx % MAXQ] <= wdata;
            wr_idx = wr_idx + 1;
        end
        if (wrst_n && winc && wfull) overflow_attempts = overflow_attempts + 1;
    end

    // read side: check every ACCEPTED read (rdata is valid before the edge)
    always @(posedge rclk) begin
        if (rrst_n && rinc && !rempty) begin
            if (rdata !== expected[rd_idx % MAXQ]) begin
                errors = errors + 1;
                $display("[%0t] ERROR #%0d: read idx %0d got 0x%02h expected 0x%02h",
                         $time, errors, rd_idx, rdata, expected[rd_idx % MAXQ]);
            end
            rd_idx = rd_idx + 1;
        end
        if (rrst_n && rinc && rempty) underflow_attempts = underflow_attempts + 1;
    end

    always @* begin
        occ = wr_idx - rd_idx;
        if (occ > max_occ) max_occ = occ;
    end
    always @(posedge wfull)  if (wrst_n) full_events  = full_events + 1;
    always @(posedge rempty) if (rrst_n) empty_events = empty_events + 1;

    // ---------------- drivers ----------------
    always @(posedge wclk) begin
        if (!wrst_n) winc <= 0;
        else begin
            winc  <= w_go && (($random(seed_w) & 32'h7fffffff) % 100 < w_prob)
                          && (w_limit == 0 || wr_idx < w_limit);
            wdata <= $random(seed_w);
        end
    end
    always @(posedge rclk) begin
        if (!rrst_n) rinc <= 0;
        else         rinc <= r_go && (($random(seed_r) & 32'h7fffffff) % 100 < r_prob);
    end

    // ---------------- CSV waveform-ish log (fill/drain phases only) ----------------
    integer fcsv;
    reg     log_en = 0;
    always @(posedge wclk or posedge rclk)
        if (log_en)
            $fdisplay(fcsv, "%0d,%0d,%0d,%0d,%0d,%0d", $time, occ, wfull, rempty,
                      (winc && !wfull), (rinc && !rempty));

    // ---------------- helpers ----------------
    task check(input cond, input [511:0] name);
        begin
            if (cond) $display("  [PASS] %0s", name);
            else begin $display("  [FAIL] %0s", name); errors = errors + 1; end
        end
    endtask

    task wait_wclks(input integer n); begin repeat (n) @(posedge wclk); end endtask
    task wait_rclks(input integer n); begin repeat (n) @(posedge rclk); end endtask

    task drain_all;
        begin
            w_go = 0; r_go = 1; r_prob = 100;
            while (rd_idx != wr_idx) @(posedge rclk);
            wait_rclks(8);           // let pointers/flags settle
            r_go = 0;
            wait_rclks(4);
        end
    endtask

    integer k;
    initial begin
        $dumpfile({"results/", TAG, ".vcd"});
        $dumpvars(0, tb_async_fifo);
        fcsv = $fopen({"results/", TAG, "_trace.csv"}, "w");
        $fdisplay(fcsv, "time_ps,occupancy,wfull,rempty,write_acc,read_acc");

        $display("==============================================================");
        $display(" Async FIFO test  [%0s]  DEPTH=%0d WIDTH=%0d  wclk=%0d ps  rclk=%0d ps",
                 TAG, DEPTH, DATA_WIDTH, WCLK_PS, RCLK_PS);
        $display("==============================================================");

        // ---- Test 1: reset ----
        $display("TEST 1: reset behaviour");
        #(3*RCLK_PS); wrst_n = 1; rrst_n = 1;      // release resets
        wait_wclks(5); wait_rclks(5);
        check(rempty === 1'b1, "empty asserted after reset");
        check(wfull  === 1'b0, "full de-asserted after reset");

        // ---- Test 2: fill to full, then overflow attempts ----
        $display("TEST 2: fill FIFO completely, then try to overflow");
        log_en = 1;
        w_go = 1; w_prob = 100; r_go = 0;
        wait (wfull === 1'b1);
        wait_wclks(12);                            // keep hammering writes while full
        check(wr_idx == DEPTH,           "exactly DEPTH writes accepted");
        check(wfull === 1'b1,            "full flag stays high");
        check(overflow_attempts > 0,     "overflow attempts were generated and blocked");
        w_go = 0;
        wait_wclks(4);

        // ---- Test 3: drain to empty, then underflow attempts ----
        $display("TEST 3: drain FIFO completely, then try to underflow");
        r_go = 1; r_prob = 100;
        wait (rempty === 1'b1);
        wait_rclks(12);
        check(rd_idx == DEPTH,           "exactly DEPTH reads accepted");
        check(errors == 0,               "all data read in FIFO order, no mismatch");
        check(underflow_attempts > 0,    "underflow attempts were generated and blocked");
        r_go = 0;
        wait_rclks(4);
        log_en = 0;
        wait (wfull === 1'b0);
        check(wfull === 1'b0,            "full cleared after draining");

        // ---- Test 4: balanced random traffic ----
        $display("TEST 4: random traffic, balanced (w=60%%, r=60%%), %0d writes", NUM_RAND);
        w_limit = wr_idx + NUM_RAND;
        w_go = 1; w_prob = 60; r_go = 1; r_prob = 60;
        wait (wr_idx >= w_limit);
        drain_all;
        check(rd_idx == wr_idx,          "all written words were read");

        // ---- Test 5: write-heavy bursts (FIFO runs full) ----
        $display("TEST 5: write-heavy traffic (w=95%%, r=25%%), %0d writes", NUM_RAND);
        w_limit = wr_idx + NUM_RAND;
        w_go = 1; w_prob = 95; r_go = 1; r_prob = 25;
        wait (wr_idx >= w_limit);
        drain_all;
        check(rd_idx == wr_idx,          "all written words were read");

        // ---- Test 6: read-heavy traffic (FIFO runs empty) ----
        $display("TEST 6: read-heavy traffic (w=25%%, r=95%%), %0d writes", NUM_RAND);
        w_limit = wr_idx + NUM_RAND;
        w_go = 1; w_prob = 25; r_go = 1; r_prob = 95;
        wait (wr_idx >= w_limit);
        drain_all;
        check(rd_idx == wr_idx,          "all written words were read");

        // ---- Test 7: simultaneous read+write streaming at full rate ----
        $display("TEST 7: continuous simultaneous read/write (100%%/100%%), %0d writes", NUM_RAND);
        w_limit = wr_idx + NUM_RAND;
        w_go = 1; w_prob = 100; r_go = 1; r_prob = 100;
        wait (wr_idx >= w_limit);
        drain_all;
        check(rd_idx == wr_idx,          "all written words were read");

        // ---- Test 8: mid-operation reset ----
        // (write domain reset + read domain reset together)
        $display("TEST 8: reset in the middle of traffic");
        w_limit = 0; w_go = 1; w_prob = 70; r_go = 0;
        wait_wclks(6);
        w_go = 0; r_go = 0; wait_wclks(2);
        wrst_n = 0; rrst_n = 0; wait_wclks(3); wait_rclks(3);
        wrst_n = 1; rrst_n = 1; wait_wclks(4); wait_rclks(4);
        check(rempty === 1'b1 && wfull === 1'b0, "FIFO is empty again after mid-traffic reset");
        // re-sync scoreboard indices and run one more burst
        rd_idx = wr_idx;
        w_limit = wr_idx + 200; w_go = 1; w_prob = 70; r_go = 1; r_prob = 70;
        wait (wr_idx >= w_limit);
        drain_all;
        check(rd_idx == wr_idx,          "data integrity after reset");

        $display("--------------------------------------------------------------");
        $display(" SUMMARY [%0s]", TAG);
        $display("   total words written      : %0d", wr_idx);
        $display("   total words read         : %0d", rd_idx);
        $display("   data mismatches/errors   : %0d", errors);
        $display("   max occupancy observed   : %0d / %0d", max_occ, DEPTH);
        $display("   full events              : %0d", full_events);
        $display("   empty events             : %0d", empty_events);
        $display("   blocked overflow tries   : %0d", overflow_attempts);
        $display("   blocked underflow tries  : %0d", underflow_attempts);
        if (errors == 0) $display(" RESULT [%0s]: *** PASS ***", TAG);
        else             $display(" RESULT [%0s]: *** FAIL ***", TAG);
        $display("--------------------------------------------------------------");
        $fclose(fcsv);
        $finish;
    end

    // watchdog
    initial begin
        #(500_000_000);
        $display("WATCHDOG TIMEOUT"); $finish;
    end
endmodule
