!> Module for physical/mathematical parameters
MODULE physical_params_mod
  USE kind_params_mod
  IMPLICIT none

  PUBLIC

  !> Pi =  4.0*ATAN(1.0)
  REAL(wp), save :: pi
  !> 2 x Pi
  REAL(wp), save :: tpi

contains

  subroutine physical_params_init
    implicit none

    pi = 4.0_wp*ATAN(1.0_wp)
    tpi = pi + pi

    write (*,*) 'PI set to: ',pi

  end subroutine physical_params_init

END MODULE physical_params_mod
