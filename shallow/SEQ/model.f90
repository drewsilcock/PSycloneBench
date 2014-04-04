MODULE model
  USE mesh
  USE shallow_IO
  USE timing, ONLY: timer_init, timer_report
  IMPLICIT none

  INTEGER :: m, n      !< global domain size
  INTEGER :: mp1, np1  !< m+1 and n+1 == array extents

  INTEGER :: itmax   !< number of timesteps

  ! solution arrays
  REAL(KIND=8), ALLOCATABLE, DIMENSION(:,:) ::                & 
                             u, v, p, unew, vnew, pnew,       & 
                             uold, vold, pold, cu, cv, z, h, psi  

CONTAINS

  !================================================

  SUBROUTINE model_init()
    USE manual_invoke_initialise
    USE mesh, ONLY: set_grid_extents, set_grid_spacings
    USE time_smooth, ONLY: time_smooth_init
    IMPLICIT none
    !> Grid spacings currently hard-wired, as in original
    !! version of code.
    REAL(KIND=8), PARAMETER :: dxloc=1.0E5, dyloc=1.0E5
    !> Parameter for time smoothing
    REAL(KIND=8), PARAMETER :: alpha_loc = .001

    CALL timer_init()

    CALL read_namelist(m,n,itmax)

    ! Set up mesh parameters
    CALL set_grid_extents(m, n)
    mp1 = m + 1
    np1 = n + 1

    CALL set_grid_spacings(dxloc, dyloc)

    ! Allocate model arrays
    CALL model_alloc(mp1, np1)

    CALL invoke_init_model_params_kernel(dxloc, m, n)

    ! Initialise time-smoothing module
    CALL time_smooth_init(alpha_loc)

    ! Initialise model IO 'system'
    CALL model_write_init(m,n)

  END SUBROUTINE model_init

  !================================================

  SUBROUTINE model_finalise()
    IMPLICIT none

    CALL model_write_finalise()

    CALL timer_report()

    CALL model_dealloc()
  
  END SUBROUTINE model_finalise

  !================================================

  SUBROUTINE model_alloc(idimx, idimy)
    IMPLICIT none
    INTEGER, INTENT(in) :: idimx, idimy

    ALLOCATE( u(idimx,idimy),    v(idimx,idimy),    p(idimx,idimy) ) 
    ALLOCATE( unew(idimx,idimy), vnew(idimx,idimy), pnew(idimx,idimy) ) 
    ALLOCATE( uold(idimx,idimy), vold(idimx,idimy), pold(idimx,idimy) )
    ALLOCATE( cu(idimx,idimy),   cv(idimx,idimy) ) 
    ALLOCATE( z(idimx,idimy),    h(idimx,idimy),    psi(idimx,idimy) ) 

  END SUBROUTINE model_alloc

  !================================================

  SUBROUTINE model_dealloc()
    IMPLICIT none

    !> Free memory \todo Move to model_finalise()
    DEALLOCATE( u, v, p, unew, vnew, pnew, uold, vold, pold )
    DEALLOCATE( cu, cv, z, h, psi ) 

  END SUBROUTINE model_dealloc

END MODULE model
