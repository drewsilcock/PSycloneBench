# initial config
set term postscript eps enhanced color
set output 'roofline_daxpy.eps'

set nokey
set grid layerdefault   linetype 0 linewidth 1.000,  linetype 0 linewidth 1.000

set xlabel "Operational Intensity (FLOPs/byte)"
set ylabel "GFLOPS"

# sets log base 2 scale for both axes
set logscale x 2
set logscale y 2

# label offsets
L_MEM_X=0.3
L_MEM_ANG=27

# range of each axis
MAX_X=2
MIN_Y=0.5
MAX_Y=34
set xrange [0.1:MAX_X]
set yrange [MIN_Y:MAX_Y]

# CPU CONSTANTS
# For single core of Xeon E5-1620 v2 (my desktop), as measured with 
# the Intel MKL version of linpack. This is therefore using
# 256-bit AVX instructions (SIMD)
PEAK_GFLOPS=28.32
NUM_CORES=1

#ceilings
C_ALL_CORES		= 1
C_MUL_ADD_BAL	= NUM_CORES
# For Ivy Bridge, AVX registers are 256-bit and therefore can
# hold 4*64-bit double-precision reals. We therefore assume
# that peak, non-SIMD performance is 1/4 that of the performance
# obtained by Linpack
C_SIMD			= 4.0

# MEM CONSTANTS
# For single core of Xeon E5-1620 v2 (desktop) as measured with 
# the 'DAXPY' result of STREAM2. Units are GB/s.
PEAK_MEM_BW=20.5
PEAK_L3_BW=46.7
PEAK_L2_BW=65.8
PEAK_L1_BW=117.0


NUM_CHANNELS=2
# first ceiling, without multiple memory channels
C_NO_MULTI_CHANNEL	= NUM_CHANNELS

# FUNCTIONS
mem_roof(x,peak)= x * peak
cpu_roof	= PEAK_GFLOPS
min(x, y)	= (x < y) ? x : y
max(x, y)       = (x > y) ? x : y

PEAK_BW = max(PEAK_MEM_BW,PEAK_L1_BW)

cpu_ceiling(x, y)	= min(mem_roof(x,PEAK_BW), y)
mem_ceiling(x)		= min(x, PEAK_GFLOPS)
roofline(x, y)		= cpu_ceiling(x, y)

LINE_ROOF=1
LINE_CEIL=2

# Width of the bars
BAR_WIDTH = 0.02

set style line LINE_ROOF	lt 1 lw 6 lc rgb "black"
set style line LINE_CEIL	lt 1 lw 3 lc rgb "blue"

kernels = "DAXPY DAXPYPXY DAXPYPXYY DAXPYPXYYY"
kernel_ai = "0.125 0.167 0.208 0.25"
kernel_flops_L3 = "3.65 7.18 8.59 10.26"
kernel_flops_L2 = "5.05 10.49 12.49 15.06"
kernel_flops_L1 = "13.30 21.74 22.70 20.82"
colors = "violet orange dark-red red"

set multiplot

# Set up the line types
set for [i=1:words(colors)] linetype i lc rgb word(colors, i)

# Draw a rectangle for each data point
xshift = -0.05
set for [i=1:words(kernels)] object i rect from (1.0-BAR_WIDTH+xshift)*word(kernel_ai, i),MIN_Y to (1.0+BAR_WIDTH+xshift)*word(kernel_ai, i),word(kernel_flops_L3, i) back fc rgb word(colors, i) fs solid
xshift = 0.0
set for [i=1:words(kernels)] object i+words(kernels) rect from (1.0-BAR_WIDTH+xshift)*word(kernel_ai, i),MIN_Y to (1.0+BAR_WIDTH+xshift)*word(kernel_ai, i),word(kernel_flops_L2, i) back fc rgb word(colors, i) fs solid
xshift = 0.05
set for [i=1:words(kernels)] object i+2*words(kernels) rect from (1.0-BAR_WIDTH+xshift)*word(kernel_ai, i),MIN_Y to (1.0+BAR_WIDTH+xshift)*word(kernel_ai, i),word(kernel_flops_L1, i) back fc rgb word(colors, i) fs solid

# CPU CEILINGS

# SIMD
set label 11 "No SIMD" at (MAX_X-0.5),((cpu_roof / C_SIMD)/1.1) right
plot cpu_ceiling(x, cpu_roof / C_SIMD) ls LINE_CEIL

# MEM CEILINGS

set label 13 "Memory Bandwidth" at (L_MEM_X),(mem_roof(L_MEM_X,PEAK_MEM_BW)*0.87) rotate by L_MEM_ANG
set label 16 "L2 Bandwidth" at (L_MEM_X),(mem_roof(L_MEM_X,PEAK_L2_BW)*0.87) rotate by L_MEM_ANG
set label 17 "L3 Bandwidth" at (L_MEM_X),(mem_roof(L_MEM_X,PEAK_L3_BW)*0.87) rotate by L_MEM_ANG
plot mem_ceiling(mem_roof(x,PEAK_MEM_BW)) ls LINE_CEIL
plot mem_ceiling(mem_roof(x,PEAK_L3_BW)) ls LINE_CEIL
plot mem_ceiling(mem_roof(x,PEAK_L2_BW)) ls LINE_CEIL
# ROOFLINE
set label 14 "Peak FP Performance" at (MAX_X-0.5),(PEAK_GFLOPS*1.1) right
set label 15 "L1 Bandwidth" at 0.125,mem_roof(0.125,PEAK_BW)*1.1 rotate by L_MEM_ANG
plot roofline(x, cpu_roof) ls LINE_ROOF

unset multiplot
