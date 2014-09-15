program shallow

!     BENCHMARK WEATHER PREDICTION PROGRAM FOR COMPARING THE
!     PREFORMANCE OF CURRENT SUPERCOMPUTERS. THE MODEL IS
!     BASED OF THE PAPER - THE DYNAMICS OF FINITE-DIFFERENCE
!     MODELS OF THE SHALLOW-WATER EQUATIONS, BY ROBERT SADOURNY
!     J. ATM. SCIENCES, VOL 32, NO 4, APRIL 1975.
!     
!     CODE BY PAUL N. SWARZTRAUBER, NATIONAL CENTER FOR
!     ATMOSPHERIC RESEARCH, BOULDER, CO,  OCTOBER 1984.
!     Modified by Juliana Rew, NCAR, January 2006
!
!     In this version, shallow4.f, initial and calculated values
!     of U, V, and P are written to a netCDF file
!     for later use in visualizing the results. The netCDF data
!     management library is freely available from
!     http://www.unidata.ucar.edu/software/netcdf
!     This code is still serial but has been brought up to modern
!     Fortran constructs and uses portable intrinsic Fortran 90 timing routines
!     This can be compiled on the IBM SP using:
!     xlf90 -qmaxmem=-1 -g -o shallow4 -qfixed=132 -qsclk=micro \
!     -I/usr/local/include shallow4.f -L/usr/local/lib32/r4i4 -l netcdf
!     where the -L and -I point to local installation of netCDF
!     
!     Changes from shallow4.f (Annette Osprey, January 2010):
!     - Converted to free-form fortran 90.  
!     - Some tidying up of old commented-out code.   
!     - Explicit type declarations.
!     - Variables n, m, itmax and mprint read in from namelist. 
!     - Dynamic array allocation.
!     - Only write to netcdf at mprint timesteps.
!     - Don't write wrap-around points to NetCDF file.
!     - Use 8-byte reals. 
!
!     This version heavily modified as part of the GOcean-2D project
!     with the mantra "all computation must occur in a kernel."
!     Andrew Porter, April 2014

  use shallow_io_mod
  use timing_mod
  use model_mod
  use initial_conditions_mod
  use time_smooth_mod,        only: invoke_time_smooth
  use apply_bcs_mod,          only: invoke_apply_bcs_uv
  use time_step_mod,          only: invoke_time_step
  use topology_mod,           only: M, N
  implicit none

  !> Checksum used for each array
  REAL(KIND=8) :: csum

  !> Loop counter for time-stepping loop
  INTEGER :: ncycle
   
  !> Integer tags for timers
  INTEGER :: idxt0

  !  ** Initialisations of model parameters (dt etc) ** 
  CALL model_init()

  ! NOTE BELOW THAT TWO DELTA T (TDT) IS SET TO DT ON THE FIRST
  ! CYCLE AFTER WHICH IT IS RESET TO DT+DT.
  ! dt and tdt are prototypical fields that are actually a 
  ! single parameter.
  CALL copy_field(dt, tdt)

  !     INITIAL VALUES OF THE STREAM FUNCTION AND P

  CALL init_initial_condition_params()
  CALL invoke_init_stream_fn_kernel(PSI)
  CALL init_pressure(P)

  !     INITIALIZE VELOCITIES
 
  CALL init_velocity_u(u, psi)
  CALL init_velocity_v(v, psi)

  !     PERIODIC CONTINUATION
  CALL invoke_apply_bcs_uv(U, V)

  ! Initialise fields that will hold data at previous time step
  CALL copy_field(U, UOLD)
  CALL copy_field(V, VOLD)
  CALL copy_field(P, POLD)
     
  ! Write intial values of p, u, and v into a netCDF file   
  CALL model_write(0, p, u, v)

  !     Start timer
  CALL timer_start('Time-stepping',idxt0)

  !  ** Start of time-stepping loop ** 
  DO ncycle=1,itmax
    
    call invoke_time_step(cu, cv, u, unew, uold, v, vnew, vold, &
                          p, pnew, pold, h, z, tdt%data)
    !call invoke( compute_fluxes(...),              &
    !             periodic_bc(cu),                  &
    !             periodic_bc(cv),                  &
    !             periodic_bc(h), periodic_bc(z),   &
    !             compute_new_fields(...),          &
    !             periodic_bc(unew), periodic_bc(vnew) periodic_bc(pnew) )

    CALL model_write(ncycle, p, u, v)

    ! TIME SMOOTHING AND UPDATE FOR NEXT CYCLE
    IF(NCYCLE .GT. 1) then

      CALL invoke_time_smooth(U, UNEW, UOLD, &
                              V, VNEW, VOLD, &
                              P, PNEW, POLD)

    ELSE ! ncycle == 1

      ! Make TDT actually = 2*DT
      CALL increment(tdt, tdt)

    ENDIF ! ncycle > 1

    CALL copy_field(UNEW, U)
    CALL copy_field(VNEW, V)
    CALL copy_field(PNEW, P)

  END DO

  !  ** End of time loop ** 

  CALL timer_stop(idxt0)

  CALL compute_checksum(pnew(1:M,1:N), csum)
  CALL model_write_log("('P CHECKSUM after ',I6,' steps = ',E15.7)", &
                       itmax, csum)

  CALL compute_checksum(unew(2:M+1,1:N), csum)
  CALL model_write_log("('U CHECKSUM after ',I6,' steps = ',E15.7)", &
                       itmax, csum)

  CALL compute_checksum(vnew(1:M,2:N+1), csum)
  CALL model_write_log("('V CHECKSUM after ',I6,' steps = ',E15.7)", &
                       itmax, csum)

  CALL model_finalise()

CONTAINS

  !===================================================

  SUBROUTINE compute_checksum(field, val)
    IMPLICIT none
    REAL(KIND=8), INTENT(in), DIMENSION(:,:) :: field
    REAL(KIND=8), INTENT(out) :: val

    val = SUM(ABS(field))

  END SUBROUTINE compute_checksum

  !===================================================

END PROGRAM shallow
