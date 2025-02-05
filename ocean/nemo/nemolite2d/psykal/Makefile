# This Makefile expects the following env. vars to be set:
#
# F90       - How to invoke the Fortran compiler
# F90FLAGS  - Flags to pass to the Fortran compiler
# OMPFLAGS  - Flags for compiling with OpenMP
# AR        - Command to use when creating an archive (.a)

# Location of the dl_timer and infrastucture code
SHARED_DIR = ../../../../shared

TIMER_DIR = ${SHARED_DIR}/dl_timer
TIMER_INC = ${TIMER_DIR}/src
TIMER_LIB = ${TIMER_DIR}/dl_timer_lib.a
INF_DIR = ${SHARED_DIR}/dl_esm_inf/finite_difference
INF_INC = ${INF_DIR}/src
INF_LIB = ${INF_DIR}/src/dl_esm_inf_fd.a
COMMON_DIR = ../common
COMMON_LIB = ${COMMON_DIR}/nemolite2d_common.a

LIBS = ${COMMON_LIB} ${TIMER_LIB} ${INF_LIB}

# The targets that this Makefile supports

.PHONY: all inf_lib timer_lib

all: nemolite2d_gen nemolite2d_gen_omp

# The kernels used by this application and their location
KERNEL_DIR = ../kernels/fortran
KERNELS = boundary_conditions_mod.o \
          continuity_mod.o \
          momentum_mod.o \
          time_update_mod.o \
          infrastructure_mod.o
${KERNELS}: ${COMMON_LIB}

# INF_LIB is an archive that must come at the end of the list of objects
# passed to the linker
COMMON_MODULES = ${COMMON_LIB} ${KERNELS} ${INF_LIB}

# Shorthand for invoking PSyclone
PSYCLONE = psyclone -api gocean1.0 -d ${KERNEL_DIR}

# Targets involving the code-generation framework. nemolite2d_gen.f90 and
# psy.f90 are generated by PSyclone from nemolite2d_alg.f90 which contains
# the definition of the Algorithm.
psy.f90: nemolite2d_alg.f90
	${PSYCLONE} -oalg nemolite2d_gen.f90 -opsy psy.f90 nemolite2d_alg.f90

# psy_omp.f90 is the same PSy layer but with OpenMP transformations
# applied to it.
psy_omp.f90: nemolite2d_alg.f90 nemolite2d_omp_transform.py
	${PSYCLONE} -s ./nemolite2d_omp_transform.py -oalg nemolite2d_gen.f90 -opsy psy_omp.f90 nemolite2d_alg.f90

# psy_acc.f90 is the same PSy layer but with OpenACC transformations
# applied to it.
psy_acc.f90: nemolite2d_alg.f90 nemolite2d_acc_transform.py
	${PSYCLONE} nemolite2d_alg.f90 -oalg nemolite2d_gen.f90 -opsy psy_acc.f90 -s ./nemolite2d_acc_transform.py

# The generated code depends on the generated Psy middle-layer
nemolite2d_gen: timer_lib inf_lib ${KERNELS} psy.o
	${MAKE} MODULE_LIST="psy.o nemolite2d_gen.o ${COMMON_MODULES} ${LIBS}" LDFLAGS="${LDFLAGS} ${OMPFLAGS}" nemolite2d_gen.exe

nemolite2d_gen_omp: timer_lib inf_lib ${KERNELS} psy_omp.o
	${MAKE} MODULE_LIST="psy_omp.o nemolite2d_gen.o ${COMMON_MODULES}" \
             F90FLAGS="${F90FLAGS} ${OMPFLAGS}" \
             LDFLAGS="${LDFLAGS} ${OMPFLAGS}" nemolite2d_gen_omp.exe

nemolite2d_gen_acc: timer_lib inf_lib ${KERNELS} psy_acc.o
	${MAKE} MODULE_LIST="psy_acc.o ${COMMON_MODULES}" \
             F90FLAGS="${F90FLAGS} ${OMPFLAGS}" \
             LDFLAGS="${LDFLAGS} ${OMPFLAGS}" nemolite2d_gen_acc.exe

# Generic rules

%.exe: $(MODULE_LIST)
	$(F90) -o $@ $(MODULE_LIST) ${TIMER_LIB} $(LDFLAGS)

%.o: %.f90
	$(F90) $(F90FLAGS) -I${COMMON_DIR} -I${INF_INC} -I${TIMER_INC} -c $<
%.o: %.F90
	$(F90) $(F90FLAGS) -I${COMMON_DIR} -I${INF_INC} -I${TIMER_INC} -c $<

# If we need a .f90 file that doesn't exist then it must be a kernel.
# Create a link to the required file...
%.f90:
	ln -sf ../kernels/fortran/$@ .

timer_lib:
	${MAKE} -C ${TIMER_DIR} sm_lib

inf_lib:
	${MAKE} -C ${INF_DIR}

${COMMON_LIB}:
	${MAKE} -C ${COMMON_DIR}

clean: 
	rm -f *.o *.mod *.MOD *~ *.pyc gnu_opt_report.txt
	rm -f psy.f90 psy_omp.f90 psy_acc.f90 nemolite2d_gen.f90

libclean:
	${MAKE} -C ${INF_DIR} distclean
	${MAKE} -C ${TIMER_DIR} allclean
	${MAKE} -C ${COMMON_DIR} allclean

allclean: clean libclean
	rm -f ${KERNELS:.o=.f90}
	rm -f *.exe fparser.log
	rm -f *.lst *.cg *.opt *.optrpt *.s
	rm -rf *_wpl_dir/

docs:
	doxygen gocean2d.doxy.config
