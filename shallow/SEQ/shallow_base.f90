      PROGRAM shallow

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


      IMPLICIT NONE

      INCLUDE 'netcdf.inc'

      INTEGER :: m, n    ! global domain size
      INTEGER :: itmax   ! number of timesteps
      INTEGER :: mprint  ! frequency of output    
      NAMELIST/global_domain/ m, n, itmax, mprint

      LOGICAL :: l_out   ! produce output  
      NAMELIST/io_control/ l_out

      INTEGER :: mp1, np1           ! m+1 and n+1 == array extents

      ! solution arrays
      REAL(KIND=8), ALLOCATABLE, DIMENSION(:,:) ::                & 
                             u, v, p, unew, vnew, pnew,           & 
                             uold, vold, pold, cu, cv, z, h, psi  

      REAL(KIND=8) :: dt, tdt, dx, dy, a, alpha, el, pi, tpi, di, dj, pcf, & 
                      tdts8, tdtsdx, tdtsdy, fsdx, fsdy
      INTEGER :: mnmin, ncycle
      INTEGER :: i, j
   
      ! timer variables 
      REAL(KIND=8) :: mfs100, mfs200, mfs300, mfs310, & 
                      t100, t200, t300, t310,         & 
                      tstart, ctime, tcyc, time, ptime
      INTEGER :: c1, c2, r, max
     
      ! NetCDF variables
      INTEGER :: ncid, t_id, p_id, u_id, v_id, iret, t_val
      INTEGER, DIMENSION(3) :: istart, icount 
      CHARACTER (LEN=13) :: ncfile = "shallowdat.nc"
 
      ! namelist input 
      CHARACTER (LEN=8) :: nml_name = "namelist" 
      INTEGER :: input_unit = 99
      INTEGER :: ierr


!  ** Initialisations ** 

!     Read in namelist 
      OPEN(unit=input_unit, file=nml_name, status='old',iostat=ierr)
        CALL check(ierr, "open "//nml_name)
      READ(unit=input_unit, nml=global_domain, iostat=ierr)
        CALL check(ierr, "read "//nml_name)
      READ(unit=input_unit, nml=io_control, iostat=ierr)
        CALL check(ierr, "read "//nml_name)

!     NOTE BELOW THAT TWO DELTA T (TDT) IS SET TO DT ON THE FIRST
!     CYCLE AFTER WHICH IT IS RESET TO DT+DT.
      DT = 90.
      TDT = DT
 
      DX = 1.E5
      DY = 1.E5
      A = 1.E6
      ALPHA = .001

      MP1 = M+1
      NP1 = N+1
      EL = N*DX
      PI = 4.*ATAN(1.)
      TPI = PI+PI
      DI = TPI/M
      DJ = TPI/N
      PCF = PI*PI*A*A/(EL*EL)

 !     Set up arrays

      ALLOCATE( u(MP1,NP1), v(MP1,NP1), p(MP1,NP1) ) 
      ALLOCATE( unew(MP1,NP1), vnew(MP1,NP1), pnew(MP1,NP1) ) 
      ALLOCATE( uold(MP1,NP1), vold(MP1,NP1), pold(MP1,NP1) )
      ALLOCATE( cu(MP1,NP1), cv(MP1,NP1) ) 
      ALLOCATE( z(MP1,NP1), h(MP1,NP1), psi(MP1,NP1) ) 

!     Prepare netCDF file to receive model output data
      IF (l_out) THEN 
         call netcdf_setup(ncfile,m,n,ncid,t_id,p_id,u_id,v_id,istart,icount)
      ENDIF
     
!     INITIAL VALUES OF THE STREAM FUNCTION AND P

      CALL init_stream_fn(PSI, A, DI, DJ)
      CALL init_pressure(P, PCF, DI, DJ)

!     INITIALIZE VELOCITIES

      CALL init_velocity_u(u, psi, m, n, dy)
      CALL init_velocity_v(v, psi, m, n, dx)

!     PERIODIC CONTINUATION
      CALL apply_bcs_u(U)
      CALL apply_bcs_v(V)

      ! Initialise fields that will hold data at previous time step
      CALL copy_field(U, UOLD)
      CALL copy_field(V, VOLD)
      CALL copy_field(P, POLD)
     
!     PRINT INITIAL VALUES
      IF (l_out) THEN 
         WRITE(6,390) N,M,DX,DY,DT,ALPHA
 390     FORMAT(" NUMBER OF POINTS IN THE X DIRECTION",I8,/    & 
                " NUMBER OF POINTS IN THE Y DIRECTION",I8,/    & 
                " GRID SPACING IN THE X DIRECTION    ",F8.0,/  & 
                " GRID SPACING IN THE Y DIRECTION    ",F8.0,/  & 
                " TIME STEP                          ",F8.0,/  & 
                " TIME FILTER PARAMETER              ",F8.3)
         MNMIN = MIN0(M,N)
         WRITE(6,391) (P(I,I),I=1,MNMIN)
 391     FORMAT(/' INITIAL DIAGONAL ELEMENTS OF P ' //,(8E15.6))
         WRITE(6,392) (U(I,I),I=1,MNMIN)
 392     FORMAT(/' INITIAL DIAGONAL ELEMENTS OF U ' //,(8E15.6))
         WRITE(6,393) (V(I,I),I=1,MNMIN)
 393     FORMAT(/' INITIAL DIAGONAL ELEMENTS OF V ' //,(8E15.6))

!        Write intial values of p, u, and v into a netCDF file   
         t_val = 0   
         call my_ncwrite(ncid,p_id,istart,icount,p(1:m,1:n),m,n,t_id,t_val)
         call my_ncwrite(ncid,u_id,istart,icount,u(1:m,1:n),m,n,t_id,t_val)
         call my_ncwrite(ncid,v_id,istart,icount,v(1:m,1:n),m,n,t_id,t_val)
      ENDIF

!     Start timer
      call system_clock (count=c1, count_rate=r, count_max=max)
      TSTART = c1
      T300 = 1.
      T310 = 1.
      TIME = 0.


!  ** Start of time loop ** 
      DO ncycle=1,itmax
    
!        COMPUTE CAPITAL U, CAPITAL V, Z AND H
         FSDX = 4./DX
         FSDY = 4./DY

         call system_clock(count=c1, count_rate=r,count_max=max)
         T100 = c1

         DO J=1,N
            DO I=1,M
               CU(I+1,J) = .5*(P(I+1,J)+P(I,J))*U(I+1,J)
               CV(I,J+1) = .5*(P(I,J+1)+P(I,J))*V(I,J+1)
               Z(I+1,J+1) =(FSDX*(V(I+1,J+1)-V(I,J+1))-FSDY*(U(I+1,J+1) & 
                    -U(I+1,J)))/(P(I,J)+P(I+1,J)+P(I+1,J+1)+P(I,J+1))
               H(I,J) = P(I,J)+.25*(U(I+1,J)*U(I+1,J)+U(I,J)*U(I,J)     & 
                    +V(I,J+1)*V(I,J+1)+V(I,J)*V(I,J))
            END DO
         END DO

         call system_clock(count=c2,count_rate=r,count_max=max)
         T100 = dble(c2-T100)/dble(r)

!        PERIODIC CONTINUATION

         CALL apply_bcs_u(CU)
         CALL apply_bcs_p(H)
         CALL apply_bcs_v(CV)

         Z(1,    2:NP1) = Z(MP1,  2:NP1)
         Z(2:MP1,1)     = Z(2:MP1,NP1)
         Z(1,    1)     = Z(MP1,  NP1)
     
!        COMPUTE NEW VALUES U,V AND P
         TDTS8 = TDT/8.
         TDTSDX = TDT/DX
         TDTSDY = TDT/DY

         call system_clock(count=c1, count_rate=r, count_max=max)
         T200 = c1

         DO J=1,N
            DO I=1,M
               UNEW(I+1,J) = UOLD(I+1,J)+                                     &
                   TDTS8*(Z(I+1,J+1)+Z(I+1,J))*(CV(I+1,J+1)+CV(I,J+1)+CV(I,J) &
                   +CV(I+1,J))-TDTSDX*(H(I+1,J)-H(I,J))                       
               VNEW(I,J+1) = VOLD(I,J+1)-TDTS8*(Z(I+1,J+1)+Z(I,J+1)) & 
                   *(CU(I+1,J+1)+CU(I,J+1)+CU(I,J)+CU(I+1,J))        & 
                   -TDTSDY*(H(I,J+1)-H(I,J))
               PNEW(I,J) = POLD(I,J)-TDTSDX*(CU(I+1,J)-CU(I,J))   & 
                   -TDTSDY*(CV(I,J+1)-CV(I,J))
            END DO
         END DO

         call system_clock(count=c2, count_rate=r, count_max=max)
         T200 = dble(c2 -T200)/dble(r)

!        PERIODIC CONTINUATION

         CALL apply_bcs_u(UNEW)
         CALL apply_bcs_v(VNEW)
         CALL apply_bcs_p(PNEW)

         TIME = TIME + DT

         IF( l_out .AND. (MOD(NCYCLE,MPRINT) .EQ. 0) ) then
            
            PTIME = TIME/3600.
            WRITE(6,350) NCYCLE,PTIME
 350        FORMAT(//' CYCLE NUMBER',I5,' MODEL TIME IN  HOURS', F6.2)
            WRITE(6,355) (PNEW(I,I),I=1,MNMIN)
 355        FORMAT(/' DIAGONAL ELEMENTS OF P ' //(8E15.6))
            WRITE(6,360) (UNEW(I,I),I=1,MNMIN)
 360        FORMAT(/' DIAGONAL ELEMENTS OF U ' //(8E15.6))
            WRITE(6,365) (VNEW(I,I),I=1,MNMIN)
 365        FORMAT(/' DIAGONAL ELEMENTS OF V ' //(8E15.6))

!           jr added MFS310--don't know what actual mult factor should be
!           jr changed divide by 1 million to divide by 100K since system_clock
!           jr resolution is millisec rather than cpu_time's 10 millisec
            MFS310 = 0.0
            MFS100 = 0.0
            MFS200 = 0.0
            MFS300 = 0.0
            IF (T310 .GT. 0) MFS310 = 24.*M*N/T310/1.D5
            IF (T100 .GT. 0) MFS100 = 24.*M*N/T100/1.D5
            IF (T200 .GT. 0) MFS200 = 26.*M*N/T200/1.D5
            IF (T300 .GT. 0) MFS300 = 15.*M*N/T300/1.D5

            call system_clock(count=c2, count_rate=r,count_max=max)
            CTIME = dble(c2 - TSTART)/dble(r)
            TCYC = CTIME/FLOAT(NCYCLE)

            WRITE(6,375) NCYCLE,CTIME,TCYC,T310,MFS310,T200,MFS200,T300,MFS300
 375        FORMAT(' CYCLE NUMBER',I5,' TOTAL COMPUTER TIME', D15.6,   & 
                   ' TIME PER CYCLE', D15.6, /                           & 
                   ' TIME AND MEGAFLOPS FOR LOOP 310 ', D15.6,2x,D6.1/   & 
                   ' TIME AND MEGAFLOPS FOR LOOP 200 ', D15.6,2x,D6.1/   & 
                   ' TIME AND MEGAFLOPS FOR LOOP 300 ', D15.6,2x,D6.1/ )

!           Append calculated values of p, u, and v to netCDF file
            istart(3) = ncycle/mprint + 1
            t_val = ncycle

!           Shape of record to be written (one ncycle at a time)
            call my_ncwrite(ncid,p_id,istart,icount,p(1:m,1:n),m,n,t_id,t_val)
            call my_ncwrite(ncid,u_id,istart,icount,u(1:m,1:n),m,n,t_id,t_val)
            call my_ncwrite(ncid,v_id,istart,icount,v(1:m,1:n),m,n,t_id,t_val)

         endif

!        Write out time if last timestep
         IF (ncycle .EQ. itmax) THEN 
            call system_clock(count=c2, count_rate=r,count_max=max)
            CTIME = dble(c2 - TSTART)/dble(r)
            WRITE(6,376) ctime  
 376        FORMAT('system_clock time ', F15.6)
         ENDIF


!        TIME SMOOTHING AND UPDATE FOR NEXT CYCLE
         IF(NCYCLE .GT. 1) then

            call system_clock(count=c1,count_rate=r,count_max=max)
            T300 = c1

            DO J=1,NP1
               DO I=1,MP1
                  UOLD(I,J) = U(I,J)+ALPHA*(UNEW(I,J)-2.*U(I,J)+UOLD(I,J))
                  VOLD(I,J) = V(I,J)+ALPHA*(VNEW(I,J)-2.*V(I,J)+VOLD(I,J))
                  POLD(I,J) = P(I,J)+ALPHA*(PNEW(I,J)-2.*P(I,J)+POLD(I,J))
                  U(I,J) = UNEW(I,J)
                  V(I,J) = VNEW(I,J)
                  P(I,J) = PNEW(I,J)
               END DO
            END DO

            call system_clock(count=c2,count_rate=r, count_max=max)
            T300 = dble(c2 - T300)/dble(r)

         ELSE ! ncycle == 1

            TDT = TDT+TDT

            call system_clock(count=c1, count_rate=r,count_max=max)
            T310 = c1

            DO J=1,NP1
               DO I=1,MP1
                  UOLD(I,J) = U(I,J)
                  VOLD(I,J) = V(I,J)
                  POLD(I,J) = P(I,J)
                  U(I,J) = UNEW(I,J)
                  V(I,J) = VNEW(I,J)
                  P(I,J) = PNEW(I,J)
               END DO
            END DO

            call system_clock(count=c2, count_rate=r, count_max=max)
            T310 = dble(c2 - T310)/dble(r)

         ENDIF ! ncycle > 1

      End do

!  ** End of time loop ** 

      WRITE(6,"('P CHECKSUM after ',I6,' steps = ',E15.7)") &
           itmax, SUM(PNEW(:,:))
      WRITE(6,"('U CHECKSUM after ',I6,' steps = ',E15.7)") &
           itmax,SUM(UNEW(:,:))
      WRITE(6,"('V CHECKSUM after ',I6,' steps = ',E15.7)") &
           itmax,SUM(VNEW(:,:))

 !     Close the netCDF file

      IF (l_out) THEN 

         iret = nf_close(ncid)
         call check_err(iret)
      ENDIF

!     Free memory
      DEALLOCATE( u, v, p, unew, vnew, pnew, uold, vold, pold )
      DEALLOCATE( cu, cv, z, h, psi ) 

    CONTAINS

      !===================================================

      SUBROUTINE apply_bcs_p(field)
        IMPLICIT none
        REAL(KIND=8), INTENT(inout), DIMENSION(:,:) :: field
        INTEGER :: M, MP1, N, NP1

        MP1 = SIZE(field, 1)
        NP1 = SIZE(field, 2)
        M = MP1 - 1
        N = NP1 - 1

        field(MP1,1:N) = field(1,  1:N)
        field(1:M,NP1) = field(1:M,1)
        field(MP1,NP1) = field(1,  1)

      END SUBROUTINE apply_bcs_p

      !===================================================

      SUBROUTINE apply_bcs_u(field)
        IMPLICIT none
        REAL(KIND=8), INTENT(inout), DIMENSION(:,:) :: field
        INTEGER :: M, MP1, N, NP1

        MP1 = SIZE(field, 1)
        NP1 = SIZE(field, 2)
        M = MP1 - 1
        N = NP1 - 1

        ! First col = last col
        field(1,    1:N) = field(MP1,  1:N)
        ! Last row = first row
        field(1:MP1,NP1) = field(1:MP1,1)

      END SUBROUTINE apply_bcs_u

      !===================================================

      SUBROUTINE apply_bcs_v(field)
        IMPLICIT none
        REAL(KIND=8), INTENT(inout), DIMENSION(:,:) :: field
        INTEGER :: M, MP1, N, NP1

        MP1 = SIZE(field, 1)
        NP1 = SIZE(field, 2)
        M = MP1 - 1
        N = NP1 - 1

        ! First row = last row
        field(1:M,1    ) = field(1:M,NP1)
        ! Last col = first col
        field(MP1,1:NP1) = field(1,  1:NP1)

      END SUBROUTINE apply_bcs_v
 
      !===================================================

      SUBROUTINE init_stream_fn(psi, A, DI, DJ)
        IMPLICIT none
        REAL(KIND=8), INTENT(out), DIMENSION(:,:) :: psi
        REAL(KIND=8), INTENT(in) :: A, DI, DJ
        ! Locals
        INTEGER :: idim1, idim2
        INTEGER :: I,J

        idim1 = SIZE(p, 1)
        idim2 = SIZE(p, 2)

        ! di = 2Pi/(Extent of mesh in x)
        ! dj = 2Pi/(Extent of mesh in y)

        DO J=1, idim2
           DO I=1, idim1
              PSI(I,J) = A*SIN((I-.5)*DI)*SIN((J-.5)*DJ)
           END DO
        END DO

      END SUBROUTINE init_stream_fn

      !===================================================

      SUBROUTINE init_pressure(p, pcf, di, dj)
        IMPLICIT none
        REAL(KIND=8), INTENT(out), DIMENSION(:,:) :: p
        REAL(KIND=8), INTENT(in) :: pcf, di, dj
        INTEGER :: idim1, idim2
        INTEGER :: i, j

        idim1 = SIZE(p, 1)
        idim2 = SIZE(p, 2)
        ! di = 2Pi/(Extent of mesh in x)
        ! dj = 2Pi/(Extent of mesh in y)
        ! Fields have one extra row and column than the mesh
        ! extent. Presumably because e.g. velocity fields are
        ! offset from pressure but this not dealt with that
        ! explicitly. Only field(1:m,1:n) is sent to be
        ! written to the netcdf file.
        DO J=1,idim2
           DO I=1,idim1
              P(I,J) = PCF*(COS(2.*(I-1)*DI)   & 
                   +COS(2.*(J-1)*DJ))+50000.
           END DO
        END DO

      END SUBROUTINE init_pressure

      !===================================================

      SUBROUTINE init_velocity_u(u, psi, m, n, dy)
        IMPLICIT none
        REAL(KIND=8), INTENT(out), DIMENSION(:,:) :: u
        REAL(KIND=8), INTENT(in),  DIMENSION(:,:) :: psi
        INTEGER,      INTENT(in) :: m, n
        REAL(KIND=8), INTENT(in) :: dy
        ! Locals
        INTEGER :: I, J

        ! dy is a property of the mesh
        DO J=1,N
           DO I=1,M+1
              U(I,J) = -(PSI(I,J+1)-PSI(I,J))/DY
           END DO
        END DO
      END SUBROUTINE init_velocity_u

      !===================================================

      SUBROUTINE init_velocity_v(v, psi, m, n, dx)
        IMPLICIT none
        REAL(KIND=8), INTENT(out), DIMENSION(:,:) :: v
        REAL(KIND=8), INTENT(in),  DIMENSION(:,:) :: psi
        INTEGER, INTENT(in) :: m, n
        REAL(KIND=8), INTENT(in) :: dx
        ! Locals
        INTEGER :: I, J

        ! dx is a property of the mesh
        DO J=1,N+1
           DO I=1,M
              V(I,J) = (PSI(I+1,J)-PSI(I,J))/DX
           END DO
        END DO
      END SUBROUTINE init_velocity_v

      !===================================================

      SUBROUTINE copy_field(field_in, field_out)
        IMPLICIT none
        REAL(KIND=8), INTENT(in),  DIMENSION(:,:) :: field_in
        REAL(KIND=8), INTENT(out), DIMENSION(:,:) :: field_out
        
        field_out(:,:) = field_in(:,:)
        
      END SUBROUTINE copy_field

    END PROGRAM shallow

    !===================================================

    ! Check error code
    subroutine check(status, text)
      implicit none
      
      integer, intent(in) :: status
      character (len=*)   :: text
    
      if (status /= 0) then
        write(6,*) "error ", status
        write(6,*) text
        stop 2
      endif

      end subroutine check

      !===================================================

      subroutine check_err(iret)
      integer iret
      include 'netcdf.inc'
      if(iret .ne. NF_NOERR) then
         print *, nf_strerror(iret)
         stop
      endif
      end subroutine

      !===================================================

      subroutine netcdf_setup(file,m,n,ncid,t_id,p_id,u_id,v_id,istart,icount)
!     Input args: file, m, n
!     Output args: ncid,t_id,p_id,u_id,v_id,istart,icount)
      character(len=*) file
      integer m,n
!     declarations for netCDF library
      include 'netcdf.inc'
!     error status return
      integer iret
!     netCDF id
      integer ncid
!     dimension ids
      integer m_dim
      integer n_dim
      integer time_dim      
!     variable ids
      integer t_id
      integer p_id
      integer u_id
      integer v_id
!     rank (number of dimensions) for each variable
      integer p_rank, u_rank, v_rank
      parameter (p_rank = 3)
      parameter (u_rank = 3)
      parameter (v_rank = 3)
!     variable shapes
      integer t_dims(1)
      integer p_dims(p_rank)
      integer u_dims(u_rank)
      integer v_dims(v_rank)
      integer istart(p_rank)
      integer icount(p_rank)
      
!     enter define mode
      iret = nf_create(file, NF_CLOBBER,ncid)
      call check_err(iret)
!     define dimensions
      iret = nf_def_dim(ncid, 'm', m, m_dim)
      call check_err(iret)
      iret = nf_def_dim(ncid, 'n', n, n_dim)
      call check_err(iret)
!     time is an unlimited dimension so that any number of
!     records can be added
      iret = nf_def_dim(ncid, 'time', NF_UNLIMITED, time_dim)
      call check_err(iret)
!     define coordinate variable for time      
      t_dims(1) = time_dim
      iret = nf_def_var(ncid, 'time', NF_INT, 1, t_dims, t_id)
      call check_err(iret)
!     define variables
      p_dims(1) = m_dim
      p_dims(2) = n_dim
      p_dims(3) = time_dim
      iret = nf_def_var(ncid, 'p', NF_DOUBLE, p_rank, p_dims, p_id)
      call check_err(iret)
      u_dims(1) = m_dim
      u_dims(2) = n_dim
      u_dims(3) = time_dim
      iret = nf_def_var(ncid, 'u', NF_DOUBLE, u_rank, u_dims, u_id)
      call check_err(iret)
      v_dims(1) = m_dim
      v_dims(2) = n_dim
      v_dims(3) = time_dim
      iret = nf_def_var(ncid, 'v', NF_DOUBLE, v_rank, v_dims, v_id)
      call check_err(iret)
!     start netCDF write at the first (1,1,1) position of the array
      istart(1) = 1
      istart(2) = 1
      istart(3) = 1
!     shape of record to be written (one ncycle at a time)
      icount(1) = m
      icount(2) = n
      icount(3) = 1
      
!     leave define mode
      iret = nf_enddef(ncid)
      call check_err(iret)
      
!     end of netCDF definitions
      end subroutine netcdf_setup

      !===================================================
     
      subroutine my_ncwrite(id,varid,istart,icount,var,m,n,t_id,t_val)
!     Input args: id, varid,istart,icount,var,m,n,t_id,t_val
!     Write a whole array out to the netCDF file
      integer id,varid,iret
      integer icount(3)
      integer istart(3)
      integer m,n
      real(kind=8) var (m,n)
      integer t_id,t_val
      integer t_start(1), t_count(1)

      iret = nf_put_vara_double(id,varid,istart,icount,var)
      call check_err(iret)
      
      t_start(1) = istart(3) 
      t_count(1) = 1
      iret = nf_put_vara_int(id,t_id,t_start,t_count,t_val)
      call check_err(iret)

      end subroutine my_ncwrite

