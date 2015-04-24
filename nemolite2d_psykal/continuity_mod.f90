module continuity_mod
  use kind_params_mod
  use kernel_mod
  use argument_mod
  use grid_mod
  use field_mod
  implicit none

  type, extends(kernel_type) :: continuity
     type(arg), dimension(10) :: meta_args =    &
          (/ arg(WRITE, CT, POINTWISE),        & ! ssha
             arg(READ,  CT, POINTWISE),        & ! sshn
             arg(READ,  CU, POINTWISE),        & ! sshn_u
             arg(READ,  CV, POINTWISE),        & ! sshn_v
             arg(READ,  CU, POINTWISE),        & ! hu
             arg(READ,  CV, POINTWISE),        & ! hv
             arg(READ,  CU, POINTWISE),        & ! un
             arg(READ,  CV, POINTWISE),        & ! vn
             arg(READ,  R,  POINTWISE),        & ! Time-step
             arg(READ,  GRID_AREA_T)           &
           /)
     !> This kernel updates only internal points of the simulation
     !! domain
     integer :: ITERATES_OVER = INTERNAL_PTS

     !> Although the staggering of variables used in an Arakawa
     !! C grid is well defined, the way in which they are indexed is
     !! an implementation choice. This can be thought of as choosing
     !! which grid-point types have the same (i,j) index as a T
     !! point. This kernel assumes that the U,V and F points that
     !! share the same index as a given T point are those immediately
     !! to the North and East of it.
     integer :: index_offset = OFFSET_NE

  contains
    procedure, nopass :: code => continuity_code
  end type continuity

contains

  !===================================================

  subroutine invoke_continuity(ssha, sshn, sshn_u, sshn_v, hu, hv, un, vn)
    use model_mod, only: rdt
    implicit none
    type(r2d_field),     intent(inout) :: ssha
    type(r2d_field),     intent(in) :: sshn, sshn_u, sshn_v
    type(r2d_field),     intent(in) :: hu, hv, un, vn
    ! Locals
    integer :: ji, jj

    do jj = ssha%internal%ystart, ssha%internal%ystop, 1
       do ji = ssha%internal%xstart, ssha%internal%xstop, 1

          call continuity_code(ji, jj,                      &
                               ssha%data, sshn%data,        &
                               sshn_u%data, sshn_v%data,    &
                               hu%data, hv%data, un%data, vn%data, &
                               rdt, ssha%grid%area_t)
       end do
    end do

  end subroutine invoke_continuity

  !===================================================

  subroutine continuity_code(ji, jj,                     &
                             ssha, sshn, sshn_u, sshn_v, &
                             hu, hv, un, vn, rdt, e12t)
    implicit none
    integer,                  intent(in)  :: ji, jj
    real(wp),                 intent(in)  :: rdt
    real(wp), dimension(:,:), intent(in)  :: e12t
    real(wp), dimension(:,:), intent(out) :: ssha
    real(wp), dimension(:,:), intent(in)  :: sshn, sshn_u, sshn_v, &
                                             hu, hv, un, vn
    ! Locals
    real(wp) :: rtmp1, rtmp2, rtmp3, rtmp4

    rtmp1 = (sshn_u(ji  ,jj  ) + hu(ji  ,jj  )) * un(ji  ,jj  )
    rtmp2 = (sshn_u(ji-1,jj  ) + hu(ji-1,jj  )) * un(ji-1,jj  )
    rtmp3 = (sshn_v(ji  ,jj  ) + hv(ji  ,jj  )) * vn(ji  ,jj  )
    rtmp4 = (sshn_v(ji  ,jj-1) + hv(ji  ,jj-1)) * vn(ji  ,jj-1)

    ssha(ji,jj) = sshn(ji,jj) + (rtmp2 - rtmp1 + rtmp4 - rtmp3) * &
                    rdt / e12t(ji,jj)

  end subroutine continuity_code

end module continuity_mod
