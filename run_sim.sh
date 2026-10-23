#!/bin/bash
# Usage: ./run_sim.sh      (needs Icarus Verilog:  sudo apt install iverilog)
set -e
mkdir -p results sim
rm -f results/summary.log
iverilog -g2012 -s tb_async_fifo -o sim/base.vvp rtl/*.v tb/tb_async_fifo.v

# name        write-period(ps)  read-period(ps)
run() {
  iverilog -g2012 -s tb_async_fifo -o sim/$1.vvp \
    -P tb_async_fifo.WCLK_PS=$2 -P tb_async_fifo.RCLK_PS=$3 -P tb_async_fifo.TAG=\"$1\" \
    rtl/*.v tb/tb_async_fifo.v
  vvp sim/$1.vvp | tee results/$1.log | grep -E "RESULT|\[FAIL\]|ERROR"
  cat results/$1.log >> results/summary.log
}
run fast_w_slow_r   10000 25000     # 100 MHz write , 40 MHz read
run slow_w_fast_r   25000 10000     # 40 MHz write , 100 MHz read
run close_ratio     10000 10300     # ~100 MHz vs ~97 MHz (slow phase drift)
run equal_freq      10000 10000     # same frequency, unrelated phase
run odd_ratio        7000 13000     # ~143 MHz vs ~77 MHz
echo "All runs finished. Logs in results/"
