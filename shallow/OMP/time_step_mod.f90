module time_step_mod
  use kind_params_mod
  use field_mod, only: copy_field
  use topology_mod, only: M, N, mp1, np1
  implicit none

contains

  subroutine invoke_time_step(cufld, cvfld, ufld, unew, uold, &
                              vfld, vnew, vold, &
                              pfld, pnew, pold, &
                              hfld, zfld, tdt)
    use compute_cu_mod,   only: compute_cu_code
    use compute_cv_mod,   only: compute_cv_code
    use compute_z_mod,    only: compute_z_code
    use compute_h_mod,    only: compute_h_code
    use compute_unew_mod, only: compute_unew_code
    use compute_vnew_mod, only: compute_vnew_code
    use compute_pnew_mod, only: compute_pnew_code
    use time_smooth_mod,  only: time_smooth_code
    use timing_mod,       only: timer_start, timer_stop
    implicit none
    real(wp), dimension(mp1,np1), intent(inout) :: cufld, cvfld
    real(wp), dimension(mp1,np1), intent(inout) :: unew, vnew, pnew
    real(wp), dimension(mp1,np1), intent(inout) :: hfld, zfld, pfld, &
                                                   ufld, vfld
    real(wp), dimension(mp1,np1), intent(inout) :: uold, vold, pold
    real(wp),                     intent(in) :: tdt
    ! Locals
    integer :: idxt
    integer :: I, J

!$OMP PARALLEL default(none), shared(cufld, cvfld, &
!$OMP          unew,vnew,pnew,hfld,zfld,pfld,ufld,vfld,    &
!$OMP          uold,vold,pold,M,N,tdt), private(j,i,idxt)

    !============================================
    ! COMPUTE CAPITAL U, CAPITAL V, Z AND H
    call timer_start('Capital {U,V,Z,H}',idxt)

!$OMP DO SCHEDULE(RUNTIME)
    DO J= 1, N, 1
       DO I= 1, M, 1
             
          call compute_cu_code(i+1, j, cufld, pfld, ufld)
             
          call compute_cv_code(i, j+1, cvfld, pfld, vfld)

          call compute_z_code(i+1, j+1, zfld, pfld, ufld, vfld)

          call compute_h_code(i, j, hfld, pfld, ufld, vfld)
       end do
    end do
!$OMP END DO NOWAIT

    call timer_stop(idxt)
!$OMP BARRIER

    !============================================
    ! PERIODIC CONTINUATION

    call timer_start('PBC 1',idxt)

    !call invoke(periodic_bc(cu), periodic_bc(cv), ....)

    ! Ultimately, this can be generated by PSyclone but in the
    ! absence of that we implement it manually here...

    ! We could parallelise these loops over threads instead of
    ! updating each of the fields in parallel...
!$OMP SINGLE
    DO J=1,N
       CUfld(1,J) = CUfld(M+1,J)
    END DO
    DO I=1,M
       CUfld(I+1,N+1) = CUfld(I+1,1)
    END DO
    CUfld(1,N+1) = CUfld(M+1,1)
!$OMP END SINGLE NOWAIT

!$OMP SINGLE
    DO J=1,N
       CVfld(M+1,J+1) = CVfld(1,J+1)
    END DO
    DO I=1,M
       CVfld(I,1) = CVfld(I,N+1)
    END DO
    CVfld(M+1,1) = CVfld(1,N+1)
!$OMP END SINGLE NOWAIT

!$OMP SINGLE
    DO J=1,N
       Zfld(1,J+1) = Zfld(M+1,J+1)
    END DO
    DO I=1,M
       Zfld(I+1,1) = Zfld(I+1,N+1)
    END DO
    Zfld(1,1) = Zfld(M+1,N+1)
!$OMP END SINGLE NOWAIT

!$OMP SINGLE
    DO J=1,N
       Hfld(M+1,J) = Hfld(1,J)
    END DO
    DO I=1,M
       Hfld(I,N+1) = Hfld(I,1)
    END DO
    Hfld(M+1,N+1) = Hfld(1,1)
!$OMP END SINGLE NOWAIT

    call timer_stop(idxt)
!$OMP BARRIER

    !============================================
    ! COMPUTE NEW VALUES U,V AND P

    call timer_start('Compute {u,v,p}new',idxt)

    !CALL manual_invoke_compute_unew(unew, uold,  z, cv, h, tdt)
!$OMP DO SCHEDULE(RUNTIME)
    do J= 1, N, 1
       do I= 1, M, 1

          CALL compute_unew_code(i+1, j, unew, uold, &
                                 zfld, cvfld, hfld, tdt)

          CALL compute_vnew_code(i, j+1, vnew, vold, &
                                 zfld, cufld, hfld, tdt)

          CALL compute_pnew_code(i, j, pnew, pold, &
                                 cufld, cvfld, tdt)
       end do
    end do
!$OMP END DO NOWAIT

    call timer_stop(idxt)
!$OMP BARRIER

    !============================================
    ! PERIODIC CONTINUATION
    !CALL invoke_apply_bcs_uvt(UNEW, VNEW, PNEW)

    call timer_start('PBC 2',idxt)

!$OMP SINGLE
    !call invoke_apply_bcs_cu(unew)
    ! Ultimately, this can be generated by PSyclone but in the
    ! absence of that we implement it manually here...
    DO J=1,N
       UNEW(1,J) = UNEW(M+1,J)
    END DO
    DO I=1,M
       UNEW(I+1,N+1) = UNEW(I+1,1)
    END DO
    UNEW(1,N+1) = UNEW(M+1,1)
!$OMP END SINGLE NOWAIT

!$OMP SINGLE
    !call invoke_apply_bcs_cu(unew)
    ! Ultimately, this can be generated by PSyclone but in the
    ! absence of that we implement it manually here...
    DO J=1,N
       VNEW(M+1,J+1) = VNEW(1,J+1)
    END DO
    DO I=1,M
       VNEW(I,1) = VNEW(I,N+1)
    END DO
    VNEW(M+1,1) = VNEW(1,N+1)
!$OMP END SINGLE NOWAIT

!$OMP SINGLE
    !call invoke_apply_bcs_cu(unew)
    ! Ultimately, this can be generated by PSyclone but in the
    ! absence of that we implement it manually here...
    DO J=1,N
       PNEW(M+1,J) = PNEW(1,J)
    END DO
    DO I=1,M
       PNEW(I,N+1) = PNEW(I,1)
    END DO
    PNEW(M+1,N+1) = PNEW(1,1)
!$OMP END SINGLE NOWAIT

    call timer_stop(idxt)
!$OMP BARRIER

    !============================================
    ! The time-smoothing is applied to a field at *every* grid point
    ! However this presents a problem when tiling as get race
    ! conditions at tile overlaps (when using OpenMP). So, we only
    ! apply the time-smoothing on the internal points and then
    ! apply boundary conditions afterwards.
    ! This updates the 'old' fields...

    call timer_start('Time smooth',idxt)

!$OMP DO SCHEDULE(RUNTIME)
    do J= 1, N, 1
       do I= 1, M, 1
          CALL time_smooth_code(i+1,j,ufld,unew,uold)
          CALL time_smooth_code(i,j+1,vfld,vnew,vold)
          CALL time_smooth_code(i,j,pfld,pnew,pold)
          ! Update for next step
          Ufld(i+1,j) = UNEW(i+1,j)
          Vfld(i,j+1) = VNEW(i,j+1)
          Pfld(i,j)   = PNEW(i,j)
       end do
    end do
!$OMP END DO NOWAIT

    call timer_stop(idxt)
!$OMP BARRIER

    !============================================
    ! Apply BCs to the fields updated in the time-smoothing
    ! and update stages above

    call timer_start('PBC 3',idxt)

!$OMP SINGLE
    DO J=1,N
       Uold(1,J)     = Uold(M+1,J)
    END DO
    DO I=1,M
       Uold(I+1,N+1) = Uold(I+1,1)
    END DO
    Uold(1,N+1)   = Uold(M+1,1)
!$OMP END SINGLE NOWAIT

!$OMP SINGLE
    DO J=1,N
       Vold(M+1,J+1) = Vold(1,J+1)
    END DO
    DO I=1,M
       Vold(I,1)     = Vold(I,N+1)
    END DO
    Vold(M+1,1)   = Vold(1,N+1)
!$OMP END SINGLE NOWAIT

!$OMP SINGLE
    DO J=1,N
       Pold(M+1,J)   = Pold(1,J)
    END DO
    DO I=1,M
       Pold(I,N+1)   = Pold(I,1)
    END DO
    Pold(M+1,N+1) = Pold(1,1)
!$OMP END SINGLE NOWAIT

!$OMP SINGLE
    DO J=1,N
       Ufld(1,J)     = Ufld(M+1,J)
    END DO
    DO I=1,M
       Ufld(I+1,N+1) = Ufld(I+1,1)
    END DO
    Ufld(1,N+1)   = Ufld(M+1,1)
!$OMP END SINGLE NOWAIT

!$OMP SINGLE
    DO J=1,N
       Vfld(M+1,J+1) = Vfld(1,J+1)
    END DO
    DO I=1,M
       Vfld(I,1)     = Vfld(I,N+1)
    END DO
    Vfld(M+1,1)   = Vfld(1,N+1)
!$OMP END SINGLE NOWAIT

!$OMP SINGLE
    DO J=1,N
       Pfld(M+1,J)   = Pfld(1,J)
    END DO
    DO I=1,M
       Pfld(I,N+1)   = Pfld(I,1)
    END DO
    Pfld(M+1,N+1) = Pfld(1,1)
!$OMP END SINGLE NOWAIT

    call timer_stop(idxt)

!$OMP END PARALLEL

  end subroutine invoke_time_step

end module time_step_mod
