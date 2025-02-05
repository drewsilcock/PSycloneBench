module time_step_mod
  implicit none

  private

  public invoke_time_step

contains

  subroutine invoke_time_step(istp, ssha, ssha_u, ssha_v, &
                              sshn_t, sshn_u, sshn_v, &
                              hu, hv, ht, ua, va, un, vn)
    use kind_params_mod
    use dl_timer
    use field_mod
    use grid_mod
    use model_mod,       only: rdt, cbfr, visc
    use physical_params_mod, only: g, omega, d2r
    use boundary_conditions_mod
    implicit none
    real(wp),        intent(in)    :: istp
    type(r2d_field), intent(inout) :: un, vn, sshn_t, sshn_u, sshn_v
    type(r2d_field), intent(inout) :: ua, va, ssha, ssha_u, ssha_v
    type(r2d_field), intent(in)    :: hu, hv, ht
    ! Locals
    integer :: ji, jj, jiu, jiv
    integer :: M, N
    integer :: cont_timer, mom_timer, bc_timer, next_timer
    ! Locals for momentum
    REAL(wp) :: u_e, u_w, v_n, v_s
    real(wp) :: v_nc, v_sc
    real(wp) :: depe, depw, deps, depn
    real(wp) :: hpg, adv, cor, vis
    real(wp) :: dudx_e, dudx_w, dudy_s, dudy_n
    real(wp) :: uu_e, uu_n, uu_s, uu_w
    real(wp) :: u_ec, u_wc, vv_e, vv_n, vv_s, vv_w
    real(wp) :: dvdx_e, dvdx_w, dvdy_n, dvdy_s
    real(wp) :: rtmp1, rtmp2, rtmp3, rtmp4
    ! end locals for momentum
    ! Locals for BCs
    real(wp) :: amp_tide, omega_tide, rtime

    M  = ssha%grid%simulation_domain%xstop
    N  = ssha%grid%simulation_domain%ystop

    ! In the general case we have to reason about whether or not the
    ! domain has PBCs and what sort of offset convention the kernels
    ! use. However, this is a middle layer specific to NEMOLite2D and
    ! therefore we know that we have no periodic BCs and are using a
    ! NE stagger
    !txstart = 2 ! grid%simulation_domain%xstart
    !tystart = 2 ! grid%simulation_domain%ystart

    !uxstart = 2 ! grid%simulation_domain%xstart
    !uxstop  = M - 1
    !uystart = 2 ! grid%simulation_domain%ystart
    !uystop  = N

    !vxstart = 2 ! grid%simulation_domain%xstart
    !vxstop  = M
    !vystart = 2 ! grid%simulation_domain%ystart
    !vystop  = N - 1

    !uwhole_xstart = 1 ! uxstart - NBOUNDARY
    !uwhole_xstop  = M ! uxstop  + NBOUNDARY
    !uwhole_ystart = 1 ! uystart - NBOUNDARY
    !uwhole_ystop  = N+1 ! uystop  + NBOUNDARY

    !vwhole_xstart = 1 ! vxstart - NBOUNDARY
    !vwhole_xstop  = M+1 ! vxstop  + NBOUNDARY
    !vwhole_ystart = 1 ! vystart - NBOUNDARY
    !vwhole_ystop  = N ! vystop  + NBOUNDARY

    call timer_start(cont_timer, label='Continuity')

!    do jj = ssha%internal%ystart, ssha%internal%ystop, 1
!      do ji = ssha%internal%xstart, ssha%internal%xstop, 1
    do jj = 2, N, 1
      do ji = 2, M, 1

!        call continuity_code(ji, jj,                             &
!                             ssha%data, sshn_t%data,             &
!                             sshn_u%data, sshn_v%data,           &
!                             hu%data, hv%data, un%data, vn%data, &
!                             rdt, sshn_t%grid%area_t)
         rtmp1 = (sshn_u%data(ji  ,jj ) + hu%data(ji  ,jj  ))*un%data(ji  ,jj)
         rtmp2 = (sshn_u%data(ji-1,jj ) + hu%data(ji-1,jj  ))*un%data(ji-1,jj)
         rtmp3 = (sshn_v%data(ji ,jj ) + hv%data(ji  ,jj  ))*vn%data(ji ,jj)
         rtmp4 = (sshn_v%data(ji ,jj-1) + hv%data(ji  ,jj-1))*vn%data(ji,jj-1)

         ssha%data(ji,jj) = sshn_t%data(ji,jj) + (rtmp2 - rtmp1 + rtmp4 - rtmp3) * &
                       rdt / sshn_t%grid%area_t(ji,jj)
      end do
    end do

    call timer_stop(cont_timer)

  end subroutine invoke_time_step

end module time_step_mod
