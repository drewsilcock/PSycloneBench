# Makefile for the NEMOLite2D routines that are commone to all of the
# various versions of the benchmark.
SHARED_DIR = ../../../../shared
TIMER_DIR = ${SHARED_DIR}/dl_timer
TIMER_INC = ${TIMER_DIR}/src
INF_DIR = ${SHARED_DIR}/dl_esm_inf/finite_difference
INF_INC = ${INF_DIR}/src

MODULES = physical_params_mod.o \
          gocean2d_io_mod.o \
          model_mod.o \
          initialisation_mod.o

nemolite2d_common.a: inf_lib timer_lib ${MODULES}
	${AR} ${ARFLAGS} $@ ${MODULES}

.PHONY: inf_lib timer_lib

timer_lib:
	${MAKE} -C ${TIMER_DIR} sm_lib

inf_lib:
	${MAKE} -C ${INF_DIR}

%.o: %.f90
	$(F90) $(F90FLAGS) -I${INF_INC} -I${TIMER_INC} -c $<
%.o: %.F90
	$(F90) $(F90FLAGS) -I${INF_INC} -I${TIMER_INC} -c $<

clean:
	rm -f *.o *~ gnu_opt_report.txt

allclean: clean
	rm -f *.mod
	rm -f nemolite2d_common.a
