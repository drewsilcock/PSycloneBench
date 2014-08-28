module gocean2d_io_mod
  use kind_params_mod
  use field_mod
  implicit none

  private

  logical, save :: l_out   !< Whether or not to produce output  
  integer, save :: mprint  !< frequency of output    
  !> Extents of arrays to write \todo Carry with field object.
  integer, save :: jpi, jpj 

  !> Interface to logging routines
  interface model_write_log
     module procedure write_log_ir, write_log_r
  end interface

  public read_namelist
  public model_write_init, model_write, model_write_finalise
  public model_write_log

contains

  !===================================================

  !> Reads the namelist file for user-specified control 
  !! parameters
  SUBROUTINE read_namelist(jpiglo, jpjglo, dx, dy,   &
                           nit000, nitend, irecord,  &
                           jphgr_msh, dep_const, rdt, cbfr, visc)
    implicit none
    !> Extent of the mask that describes the area that
    !! contains the simulation domain
    integer,  intent(out) :: jpiglo, jpjglo
    !> Grid spacing
    real(wp), intent(out) :: dx, dy
    !> Start time-step, stop time-step and output interval
    integer, intent(out) :: nit000, nitend, irecord
    !> Whether grid is to be read from file or not
    integer, intent(out) :: jphgr_msh
    !> (Constant) depth of water in domain
    real(wp), intent(out) :: dep_const
    !> Model time-step (seconds?)
    real(wp), intent(out) :: rdt
    !> Coefficient of bottom friction
    real(wp), intent(out) :: cbfr
    !> Background/constant viscosity
    real(wp), intent(out) :: visc
    ! namelist input 
    character (len=8) :: nml_name = "namelist" 
    integer :: input_unit = 99
    integer :: ios

    !! Read in model setup parameters 
    NAMELIST/namctl/ jpiglo, jpjglo, jphgr_msh, &
                     dx    , dy    , dep_const, &
                     nit000, nitend, irecord  , &
                     rdt   , cbfr  , visc

    !! Default values

    jpiglo      =      50               !  number of columns of model grid
    jpjglo      =     100               !  number of rows of model grid
    jphgr_msh   =       1               !  type of grid (0: read in a data file; 1: setup with following parameters)
    dx          =   1000._wp            !  grid size in x direction (m)
    dy          =   1000._wp            !  grid size in y direction (m)
    dep_const   =    100._wp            !  constant depth (m)
    nit000      =       1               !  first time step
    nitend      =    1000               !  end time step
    irecord     =       1               !  intervals to save results
    rdt         =     10._wp            !  size of time step (second) 
    cbfr        =   0.001_wp            !  bottom friction coefficeint
    visc        =     100._wp           !  horiz. kinematic viscosity coeff. 
 
    OPEN(input_unit, file=nml_name, STATUS='OLD')
    REWIND(input_unit)
    READ(input_unit, NML=namctl, IOSTAT = ios)
    IF(ios /= 0) STOP "err found in reading namelist file"
    WRITE(*,NML=namctl)
    
    CLOSE(unit=input_unit)

  END SUBROUTINE read_namelist

  !===================================================
  
  SUBROUTINE model_write_init(m, n, interval)
    IMPLICIT none
    INTEGER, INTENT(in) :: m, n, interval

    jpi = m
    jpj = n
    mprint = interval
    l_out = .true.

  END SUBROUTINE model_write_init
 
  !===================================================

  !> Write data for the current time step
  subroutine model_write(grid, istp, ht, sshn, un, vn)
    use kind_params_mod
    use grid_mod
    implicit none
    type(grid_type), intent(in) :: grid
    integer, intent(in) :: istp
    real(wp), dimension(:,:), intent(in) :: ht, sshn, un, vn
    ! Locals
    integer :: ji, jj
    real(wp) :: rtmp1, rtmp2
    character(len=5) :: fname
    
    if( l_out .and. (mod(istp, mprint) .eq. 0) ) then

       ! output model results
       write(fname, '(I5.5)') istp
       !OPEN(21, file='go2d_'//fname//'.dat', STATUS='UNKNOWN')
       open(21, file='go2d_'//fname//'.csv', STATUS='UNKNOWN')
       rewind(21)

       DO jj = 1, jpj
          DO ji = 1, jpi
             rtmp1 = 0.5_wp * (un(ji-1,jj) + un(ji,jj))
             rtmp2 = 0.5_wp * (vn(ji,jj-1) + vn(ji,jj))

             ! write "x-coord, y-coord, depth, ssh, u-velocity, v-velocity" to ASCII files

             !WRITE(1,'(2f20.3, 2f15.4, 2e18.3)')  &            
             WRITE(21,'(f20.3,'','',f20.3,'','',f15.4,'','',f15.4,'','',f18.3,'','',f18.3)') &
             & grid%xt(ji,jj), grid%yt(ji,jj), ht(ji,jj), sshn(ji,jj),rtmp1, rtmp2 
          END DO
       END DO
          
       close(21)

    end if ! we're doing output

  end subroutine model_write

  !===================================================

  !> Write log entry with one integer and one real arg
  SUBROUTINE write_log_ir(fmtstr, istep, fvar)
    IMPLICIT none
    CHARACTER(LEN=*), INTENT(in) :: fmtstr
    INTEGER,          INTENT(in) :: istep
    REAL(wp),         INTENT(in) :: fvar

    WRITE(6,FMT=fmtstr) istep, fvar

  END SUBROUTINE write_log_ir

  !===================================================

  !> Write log entry with one real arg
  SUBROUTINE write_log_r(fmtstr, fvar)
    IMPLICIT none
    CHARACTER(LEN=*), INTENT(in) :: fmtstr
    REAL(wp),         INTENT(in) :: fvar

    WRITE(6,FMT=fmtstr) fvar

  END SUBROUTINE write_log_r

  !===================================================

  SUBROUTINE model_write_finalise()
    IMPLICIT none
    
    ! Nothing to do here as we open and close ASCII file for
    ! each write.

  END SUBROUTINE model_write_finalise

  !===================================================

  ! Check error code
!!$  subroutine check(status, text)
!!$    implicit none
!!$      
!!$    integer, intent(in) :: status
!!$    character (len=*)   :: text
!!$    
!!$    if (status /= 0) then
!!$       write(6,*) "error ", status
!!$       write(6,*) text
!!$       stop 2
!!$    endif
!!$
!!$  end subroutine check

  !===================================================

END MODULE gocean2d_io_mod
