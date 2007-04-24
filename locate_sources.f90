!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  4 . 0
!          --------------------------------------------------
!
!          Main authors: Dimitri Komatitsch and Jeroen Tromp
!    Seismological Laboratory, California Institute of Technology, USA
!                    and University of Pau, France
! (c) California Institute of Technology and University of Pau, April 2007
!
!    A signed non-commercial agreement is required to use this program.
!   Please check http://www.gps.caltech.edu/research/jtromp for details.
!           Free for non-commercial academic research ONLY.
!      This program is distributed WITHOUT ANY WARRANTY whatsoever.
!      Do not redistribute this program without written permission.
!
!=====================================================================

!----
!----  locate_sources finds the correct position of the sources
!----

! to locate the sources we loop in elements above the 670 only

  subroutine locate_sources(NSOURCES,myrank,nspec,nglob,ibool,&
                 xstore,ystore,zstore,xigll,yigll,zigll, &
                 NPROCTOT,ELLIPTICITY,TOPOGRAPHY, &
                 sec,t_cmt,yr,jda,ho,mi,theta_source,phi_source, &
                 NSTEP,DT,hdur,Mxx,Myy,Mzz,Mxy,Mxz,Myz, &
                 islice_selected_source,ispec_selected_source, &
                 xi_source,eta_source,gamma_source, nu_source, &
                 rspl,espl,espl2,nspl,ibathy_topo,NEX_XI,PRINT_SOURCE_TIME_FUNCTION)

  implicit none

! standard include of the MPI library
  include 'mpif.h'

  include "constants.h"
  include "precision.h"

  integer NPROCTOT
  integer NSTEP,NSOURCES,NEX_XI

  logical ELLIPTICITY,TOPOGRAPHY,PRINT_SOURCE_TIME_FUNCTION

  double precision DT

! use integer array to store values
  integer ibathy_topo(NX_BATHY,NY_BATHY)

! for ellipticity
  integer nspl
  double precision rspl(NR),espl(NR),espl2(NR)

  integer nspec,nglob,myrank,isource

  integer ibool(NGLLX,NGLLY,NGLLZ,nspec)

! arrays containing coordinates of the points
  real(kind=CUSTOM_REAL), dimension(nglob) :: xstore,ystore,zstore

! Gauss-Lobatto-Legendre points of integration
  double precision xigll(NGLLX),yigll(NGLLY),zigll(NGLLZ)

  double precision nu_source(NDIM,NDIM,NSOURCES)

  integer yr,jda,ho,mi

  double precision sec
  double precision t_cmt(NSOURCES)
  double precision t0, hdur_gaussian(NSOURCES)

  integer iprocloop

  integer i,j,k,ispec,iglob
  integer ier

  double precision ell
  double precision elevation
  double precision r0,dcost,p20
  double precision theta,phi
  double precision, dimension(NSOURCES) :: theta_source,phi_source
  double precision dist,typical_size
  double precision xi,eta,gamma,dx,dy,dz,dxi,deta

! topology of the control points of the surface element
  integer iax,iay,iaz
  integer iaddx(NGNOD),iaddy(NGNOD),iaddr(NGNOD)

! coordinates of the control points of the surface element
  double precision xelm(NGNOD),yelm(NGNOD),zelm(NGNOD)

  integer iter_loop

  integer ia
  double precision x,y,z
  double precision xix,xiy,xiz
  double precision etax,etay,etaz
  double precision gammax,gammay,gammaz
  double precision dgamma

  double precision final_distance_source(NSOURCES)
  double precision final_distance_source_sub(NSOURCES_SUB)

  double precision x_target_source,y_target_source,z_target_source
  double precision r_target_source

  integer islice_selected_source(NSOURCES)

! timer MPI
  double precision time_start,tCPU

  integer isources_read,itsource
  integer ispec_selected_source(NSOURCES)
  integer ispec_selected_source_sub(NSOURCES_SUB)

  integer, dimension(NSOURCES_SUB,0:NPROCTOT-1) :: ispec_selected_source_all
  double precision, dimension(NSOURCES_SUB,0:NPROCTOT-1) :: xi_source_all,eta_source_all,gamma_source_all, &
     final_distance_source_all,x_found_source_all,y_found_source_all,z_found_source_all

  double precision hdur(NSOURCES)

  double precision, dimension(NSOURCES) :: Mxx,Myy,Mzz,Mxy,Mxz,Myz
  double precision, dimension(NSOURCES) :: xi_source,eta_source,gamma_source
  double precision, dimension(NSOURCES_SUB) :: xi_source_sub,eta_source_sub,gamma_source_sub

  double precision, dimension(NSOURCES) :: lat,long,depth
  double precision scalar_moment
  double precision moment_tensor(6,NSOURCES)
  double precision radius

  character(len=150) OUTPUT_FILES,plot_file

  double precision, dimension(NSOURCES_SUB) :: x_found_source,y_found_source,z_found_source
  double precision r_found_source
  double precision st,ct,sp,cp
  double precision Mrr,Mtt,Mpp,Mrt,Mrp,Mtp
  double precision colat_source
  double precision distmin

  integer ix_initial_guess_source,iy_initial_guess_source,iz_initial_guess_source

  logical located_target

! for calculation of source time function and spectrum
  integer it,iom
  double precision time_source,om
  double precision, external :: comp_source_time_function,comp_source_spectrum

! number of points to plot the source time function and spectrum
  integer, parameter :: NSAMP_PLOT_SOURCE = 1000

  integer iorientation
  double precision stazi,stdip,thetan,phin,n(3)

! **************

! get the base pathname for output files
  call get_value_string(OUTPUT_FILES, 'OUTPUT_FILES', 'OUTPUT_FILES')

! read all the sources
  if(myrank == 0) call get_cmt(yr,jda,ho,mi,sec,t_cmt,hdur,lat,long,depth,moment_tensor,DT,NSOURCES)
! broadcast the information read on the master to the nodes
  call MPI_BCAST(yr,1,MPI_INTEGER,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(jda,1,MPI_INTEGER,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(ho,1,MPI_INTEGER,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(mi,1,MPI_INTEGER,0,MPI_COMM_WORLD,ier)

  call MPI_BCAST(sec,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)

  call MPI_BCAST(t_cmt,NSOURCES,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(hdur,NSOURCES,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(lat,NSOURCES,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(long,NSOURCES,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(depth,NSOURCES,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)

  call MPI_BCAST(moment_tensor,6*NSOURCES,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)

! define topology of the control element
  call hex_nodes(iaddx,iaddy,iaddr)

! get MPI starting time for all sources
  time_start = MPI_WTIME()

! convert the half duration for triangle STF to the one for gaussian STF
  hdur_gaussian = hdur/SOURCE_DECAY_RATE

! define t0 as the earliest start time
  t0 = - 1.5d0*minval(t_cmt-hdur)

! loop on all the sources
! gather source information in chunks to reduce memory requirements
! loop over chunks of sources
  do isources_read = 0,NSOURCES,NSOURCES_SUB
! loop over sources within chunks
  do itsource = 1,min(NSOURCES_SUB,NSOURCES-isources_read)
  isource = itsource+isources_read

! convert geographic latitude lat (degrees)
! to geocentric colatitude theta (radians)
  theta=PI/2.0d0-atan(0.99329534d0*dtan(lat(isource)*PI/180.0d0))
  phi=long(isource)*PI/180.0d0
  call reduce(theta,phi)

! get the moment tensor
  Mrr = moment_tensor(1,isource)
  Mtt = moment_tensor(2,isource)
  Mpp = moment_tensor(3,isource)
  Mrt = moment_tensor(4,isource)
  Mrp = moment_tensor(5,isource)
  Mtp = moment_tensor(6,isource)

! convert from a spherical to a Cartesian representation of the moment tensor
  st=dsin(theta)
  ct=dcos(theta)
  sp=dsin(phi)
  cp=dcos(phi)

  Mxx(isource)=st*st*cp*cp*Mrr+ct*ct*cp*cp*Mtt+sp*sp*Mpp &
      +2.0d0*st*ct*cp*cp*Mrt-2.0d0*st*sp*cp*Mrp-2.0d0*ct*sp*cp*Mtp
  Myy(isource)=st*st*sp*sp*Mrr+ct*ct*sp*sp*Mtt+cp*cp*Mpp &
      +2.0d0*st*ct*sp*sp*Mrt+2.0d0*st*sp*cp*Mrp+2.0d0*ct*sp*cp*Mtp
  Mzz(isource)=ct*ct*Mrr+st*st*Mtt-2.0d0*st*ct*Mrt
  Mxy(isource)=st*st*sp*cp*Mrr+ct*ct*sp*cp*Mtt-sp*cp*Mpp &
      +2.0d0*st*ct*sp*cp*Mrt+st*(cp*cp-sp*sp)*Mrp+ct*(cp*cp-sp*sp)*Mtp
  Mxz(isource)=st*ct*cp*Mrr-st*ct*cp*Mtt &
      +(ct*ct-st*st)*cp*Mrt-ct*sp*Mrp+st*sp*Mtp
  Myz(isource)=st*ct*sp*Mrr-st*ct*sp*Mtt &
      +(ct*ct-st*st)*sp*Mrt+ct*cp*Mrp-st*cp*Mtp


! record three components for each station
  do iorientation = 1,3

!     North
    if(iorientation == 1) then
      stazi = 0.d0
      stdip = 0.d0
!     East
    else if(iorientation == 2) then
      stazi = 90.d0
      stdip = 0.d0
!     Vertical
    else if(iorientation == 3) then
      stazi = 0.d0
      stdip = - 90.d0
    else
      call exit_MPI(myrank,'incorrect orientation')
    endif

!     get the orientation of the seismometer
    thetan=(90.0d0+stdip)*PI/180.0d0
    phin=stazi*PI/180.0d0

! we use the same convention as in Harvard normal modes for the orientation

!     vertical component
    n(1) = dcos(thetan)
!     N-S component
    n(2) = - dsin(thetan)*dcos(phin)
!     E-W component
    n(3) = dsin(thetan)*dsin(phin)

!     get the Cartesian components of n in the model: nu

    nu_source(iorientation,1,isource) = n(1)*st*cp+n(2)*ct*cp-n(3)*sp
    nu_source(iorientation,2,isource) = n(1)*st*sp+n(2)*ct*sp+n(3)*cp
    nu_source(iorientation,3,isource) = n(1)*ct-n(2)*st

  enddo


! normalized source radius
  r0 = R_UNIT_SPHERE

  if(ELLIPTICITY) then
    if(TOPOGRAPHY) then
      call get_topo_bathy(lat(isource),long(isource),elevation,ibathy_topo)
      r0 = r0 + elevation/R_EARTH
    endif
    dcost = dcos(theta)
    p20 = 0.5d0*(3.0d0*dcost*dcost-1.0d0)
    radius = r0 - depth(isource)*1000.0d0/R_EARTH
    call splint(rspl,espl,espl2,nspl,radius,ell)
    r0 = r0*(1.0d0-(2.0d0/3.0d0)*ell*p20)
  endif

! compute the Cartesian position of the source
  r_target_source = r0 - depth(isource)*1000.0d0/R_EARTH
  x_target_source = r_target_source*dsin(theta)*dcos(phi)
  y_target_source = r_target_source*dsin(theta)*dsin(phi)
  z_target_source = r_target_source*dcos(theta)

  if(myrank == 0) write(IOVTK,*) x_target_source,y_target_source,z_target_source

! set distance to huge initial value
  distmin = HUGEVAL

! compute typical size of elements at the surface
  typical_size = TWO_PI * R_UNIT_SPHERE / (4.*NEX_XI)

! use 10 times the distance as a criterion for source detection
  typical_size = 10. * typical_size

! flag to check that we located at least one target element
  located_target = .false.

  do ispec = 1,nspec

! loop on elements in the crust or in mantle above d660 only
!!!!!!! DK DK suppressed this, could be dangerous if sources are located in the vicinity of d660 in a 3D Earth
!!!!!!! DK DK suppressed this  if(idoubling(ispec) == IFLAG_MANTLE_NORMAL) cycle

! exclude elements that are too far from target
  iglob = ibool(1,1,1,ispec)
  dist = dsqrt((x_target_source - dble(xstore(iglob)))**2 &
             + (y_target_source - dble(ystore(iglob)))**2 &
             + (z_target_source - dble(zstore(iglob)))**2)
  if(USE_DISTANCE_CRITERION .and. dist > typical_size) cycle

  located_target = .true.

! loop only on points inside the element
! exclude edges to ensure this point is not shared with other elements
  do k = 2,NGLLZ-1
    do j = 2,NGLLY-1
      do i = 2,NGLLX-1

!       keep this point if it is closer to the receiver
        iglob = ibool(i,j,k,ispec)
        dist = dsqrt((x_target_source - dble(xstore(iglob)))**2 &
                    +(y_target_source - dble(ystore(iglob)))**2 &
                    +(z_target_source - dble(zstore(iglob)))**2)
        if(dist < distmin) then
          distmin = dist
          ispec_selected_source_sub(itsource) = ispec
          ix_initial_guess_source = i
          iy_initial_guess_source = j
          iz_initial_guess_source = k
        endif

      enddo
    enddo
  enddo

! end of loop on all the elements in current slice
  enddo

! *******************************************
! find the best (xi,eta,gamma) for the source
! *******************************************

! if we have not located a target element, the source is not in this slice
! therefore use first element only for fictitious iterative search
  if(.not. located_target) then
    ispec_selected_source_sub(itsource)=1
    ix_initial_guess_source = 2
    iy_initial_guess_source = 2
    iz_initial_guess_source = 2
  endif

! use initial guess in xi, eta and gamma
  xi = xigll(ix_initial_guess_source)
  eta = yigll(iy_initial_guess_source)
  gamma = zigll(iz_initial_guess_source)

! define coordinates of the control points of the element

  do ia=1,NGNOD

    if(iaddx(ia) == 0) then
      iax = 1
    else if(iaddx(ia) == 1) then
      iax = (NGLLX+1)/2
    else if(iaddx(ia) == 2) then
      iax = NGLLX
    else
      call exit_MPI(myrank,'incorrect value of iaddx')
    endif

    if(iaddy(ia) == 0) then
      iay = 1
    else if(iaddy(ia) == 1) then
      iay = (NGLLY+1)/2
    else if(iaddy(ia) == 2) then
      iay = NGLLY
    else
      call exit_MPI(myrank,'incorrect value of iaddy')
    endif

    if(iaddr(ia) == 0) then
      iaz = 1
    else if(iaddr(ia) == 1) then
      iaz = (NGLLZ+1)/2
    else if(iaddr(ia) == 2) then
      iaz = NGLLZ
    else
      call exit_MPI(myrank,'incorrect value of iaddr')
    endif

    iglob = ibool(iax,iay,iaz,ispec_selected_source_sub(itsource))
    xelm(ia) = dble(xstore(iglob))
    yelm(ia) = dble(ystore(iglob))
    zelm(ia) = dble(zstore(iglob))

  enddo

! iterate to solve the non linear system
  do iter_loop = 1,NUM_ITER

! recompute jacobian for the new point
    call recompute_jacobian(xelm,yelm,zelm,xi,eta,gamma,x,y,z, &
           xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz)

! compute distance to target location
  dx = - (x - x_target_source)
  dy = - (y - y_target_source)
  dz = - (z - z_target_source)

! compute increments
  dxi  = xix*dx + xiy*dy + xiz*dz
  deta = etax*dx + etay*dy + etaz*dz
  dgamma = gammax*dx + gammay*dy + gammaz*dz

! update values
  xi = xi + dxi
  eta = eta + deta
  gamma = gamma + dgamma

! impose that we stay in that element
! (useful if user gives a source outside the mesh for instance)
  if (xi > 1.d0) xi = 1.d0
  if (xi < -1.d0) xi = -1.d0
  if (eta > 1.d0) eta = 1.d0
  if (eta < -1.d0) eta = -1.d0
  if (gamma > 1.d0) gamma = 1.d0
  if (gamma < -1.d0) gamma = -1.d0

  enddo

! compute final coordinates of point found
  call recompute_jacobian(xelm,yelm,zelm,xi,eta,gamma,x,y,z, &
         xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz)

! store xi,eta,gamma and x,y,z of point found
  xi_source_sub(itsource) = xi
  eta_source_sub(itsource) = eta
  gamma_source_sub(itsource) = gamma
  x_found_source(itsource) = x
  y_found_source(itsource) = y
  z_found_source(itsource) = z

! compute final distance between asked and found (converted to km)
  final_distance_source_sub(itsource) = dsqrt((x_target_source-x_found_source(itsource))**2 + &
    (y_target_source-y_found_source(itsource))**2 + (z_target_source-z_found_source(itsource))**2)*R_EARTH/1000.d0

! end of loop on all the sources
  enddo

! now gather information from all the nodes
  ispec_selected_source_all(:,:) = -1
  call MPI_GATHER(ispec_selected_source_sub,NSOURCES_SUB,MPI_INTEGER, &
                  ispec_selected_source_all,NSOURCES_SUB,MPI_INTEGER,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(xi_source_sub,NSOURCES_SUB,MPI_DOUBLE_PRECISION, &
                  xi_source_all,NSOURCES_SUB,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(eta_source_sub,NSOURCES_SUB,MPI_DOUBLE_PRECISION, &
                  eta_source_all,NSOURCES_SUB,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(gamma_source_sub,NSOURCES_SUB,MPI_DOUBLE_PRECISION, &
                  gamma_source_all,NSOURCES_SUB,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(final_distance_source_sub,NSOURCES_SUB,MPI_DOUBLE_PRECISION, &
    final_distance_source_all,NSOURCES_SUB,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(x_found_source,NSOURCES_SUB,MPI_DOUBLE_PRECISION, &
    x_found_source_all,NSOURCES_SUB,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(y_found_source,NSOURCES_SUB,MPI_DOUBLE_PRECISION, &
    y_found_source_all,NSOURCES_SUB,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(z_found_source,NSOURCES_SUB,MPI_DOUBLE_PRECISION, &
    z_found_source_all,NSOURCES_SUB,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)

! this is executed by main process only
  if(myrank == 0) then

! check that the gather operation went well
  if(any(ispec_selected_source_all(:,:) == -1)) call exit_MPI(myrank,'gather operation failed for source')

! loop on all the sources within chunk
  do itsource = 1,min(NSOURCES_SUB,NSOURCES-isources_read)
     isource = isources_read+itsource
! loop on all the results to determine the best slice
  distmin = HUGEVAL
  do iprocloop = 0,NPROCTOT-1
    if(final_distance_source_all(itsource,iprocloop) < distmin) then
      distmin = final_distance_source_all(itsource,iprocloop)
      islice_selected_source(isource) = iprocloop
      ispec_selected_source(isource) = ispec_selected_source_all(itsource,iprocloop)
      xi_source(isource) = xi_source_all(itsource,iprocloop)
      eta_source(isource) = eta_source_all(itsource,iprocloop)
      gamma_source(isource) = gamma_source_all(itsource,iprocloop)
      x_found_source(itsource) = x_found_source_all(itsource,iprocloop)
      y_found_source(itsource) = y_found_source_all(itsource,iprocloop)
      z_found_source(itsource) = z_found_source_all(itsource,iprocloop)
    endif
  enddo
  final_distance_source(isource) = distmin

    write(IMAIN,*)
    write(IMAIN,*) '*************************************'
    write(IMAIN,*) ' locating source ',isource
    write(IMAIN,*) '*************************************'
    write(IMAIN,*)
    write(IMAIN,*) 'source located in slice ',islice_selected_source(itsource)
    write(IMAIN,*) '               in element ',ispec_selected_source(itsource)
    write(IMAIN,*)
    write(IMAIN,*) '   xi coordinate of source in that element: ',xi_source(isource)
    write(IMAIN,*) '  eta coordinate of source in that element: ',eta_source(isource)
    write(IMAIN,*) 'gamma coordinate of source in that element: ',gamma_source(isource)

! add message if source is a Heaviside
    if(hdur(isource) < 5.*DT) then
      write(IMAIN,*)
      write(IMAIN,*) 'Source time function is a Heaviside, convolve later'
      write(IMAIN,*)
    endif

    write(IMAIN,*)
    write(IMAIN,*) ' half duration: ',hdur(isource),' seconds'
    write(IMAIN,*) '    time shift: ',t_cmt(isource),' seconds'

! get latitude, longitude and depth of the source that will be used
    call xyz_2_rthetaphi_dble(x_found_source(itsource),y_found_source(itsource),z_found_source(itsource), &
           r_found_source,theta_source(isource),phi_source(isource))
    call reduce(theta_source(isource),phi_source(isource))

! convert geocentric to geographic colatitude
    colat_source=PI/2.0d0-datan(1.006760466d0*dcos(theta_source(isource))/dmax1(TINYVAL,dsin(theta_source(isource))))
    if(phi_source(isource)>PI) phi_source(isource)=phi_source(isource)-TWO_PI

    write(IMAIN,*)
    write(IMAIN,*) 'original (requested) position of the source:'
    write(IMAIN,*)
    write(IMAIN,*) '      latitude: ',lat(isource)
    write(IMAIN,*) '     longitude: ',long(isource)
    write(IMAIN,*) '         depth: ',depth(isource),' km'
    write(IMAIN,*)

! compute real position of the source
    write(IMAIN,*) 'position of the source that will be used:'
    write(IMAIN,*)
    write(IMAIN,*) '      latitude: ',(PI/2.0d0-colat_source)*180.0d0/PI
    write(IMAIN,*) '     longitude: ',phi_source(isource)*180.0d0/PI
    write(IMAIN,*) '         depth: ',(r0-r_found_source)*R_EARTH/1000.0d0,' km'
    write(IMAIN,*)

! display error in location estimate
    write(IMAIN,*) 'error in location of the source: ',sngl(final_distance_source(isource)),' km'

! add warning if estimate is poor
! (usually means source outside the mesh given by the user)
    if(final_distance_source(isource) > 50.d0) then
      write(IMAIN,*)
      write(IMAIN,*) '*****************************************************'
      write(IMAIN,*) '*****************************************************'
      write(IMAIN,*) '***** WARNING: source location estimate is poor *****'
      write(IMAIN,*) '*****************************************************'
      write(IMAIN,*) '*****************************************************'
    endif

! print source time function and spectrum
  if(PRINT_SOURCE_TIME_FUNCTION) then

  write(IMAIN,*)
  write(IMAIN,*) 'printing the source-time function'

! print the source-time function
  if(NSOURCES == 1) then
    plot_file = '/plot_source_time_function.txt'
  else
   if(isource < 10) then
      write(plot_file,"('/plot_source_time_function',i1,'.txt')") isource
    elseif(isource < 100) then
      write(plot_file,"('/plot_source_time_function',i2,'.txt')") isource
    else
      write(plot_file,"('/plot_source_time_function',i3,'.txt')") isource
    endif
  endif
  open(unit=27,file=trim(OUTPUT_FILES)//plot_file,status='unknown')

  scalar_moment = 0.
  do i = 1,6
    scalar_moment = scalar_moment + moment_tensor(i,isource)**2
  enddo
  scalar_moment = dsqrt(scalar_moment/2.)

  do it=1,NSTEP
    time_source = dble(it-1)*DT-t0-t_cmt(isource)
    write(27,*) sngl(dble(it-1)*DT-t0),sngl(scalar_moment*comp_source_time_function(time_source,hdur_gaussian(isource)))
  enddo
  close(27)

  write(IMAIN,*)
  write(IMAIN,*) 'printing the source spectrum'

! print the spectrum of the derivative of the source from 0 to 1/8 Hz
  if(NSOURCES == 1) then
   plot_file = '/plot_source_spectrum.txt'
  else
   if(isource < 10) then
      write(plot_file,"('/plot_source_spectrum',i1,'.txt')") isource
    elseif(isource < 100) then
      write(plot_file,"('/plot_source_spectrum',i2,'.txt')") isource
    else
      write(plot_file,"('/plot_source_spectrum',i3,'.txt')") isource
    endif
  endif
  open(unit=27,file=trim(OUTPUT_FILES)//plot_file,status='unknown')

  do iom=1,NSAMP_PLOT_SOURCE
    om=TWO_PI*(1.0d0/8.0d0)*(iom-1)/dble(NSAMP_PLOT_SOURCE-1)
    write(27,*) sngl(om/TWO_PI),sngl(scalar_moment*om*comp_source_spectrum(om,hdur(isource)))
  enddo
  close(27)

  endif

! end of loop on all the sources within source chunk
  enddo
  endif     ! end of section executed by main process only
! end of loop over all source chunks
  enddo
! display maximum error in location estimate
  if(myrank == 0) then
    write(IMAIN,*)
    write(IMAIN,*) 'maximum error in location of the sources: ',sngl(maxval(final_distance_source)),' km'
    write(IMAIN,*)
  endif


! main process broadcasts the results to all the slices
  call MPI_BCAST(islice_selected_source,NSOURCES,MPI_INTEGER,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(ispec_selected_source,NSOURCES,MPI_INTEGER,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(xi_source,NSOURCES,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(eta_source,NSOURCES,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(gamma_source,NSOURCES,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)

! elapsed time since beginning of source detection
  if(myrank == 0) then
    tCPU = MPI_WTIME() - time_start
    write(IMAIN,*)
    write(IMAIN,*) 'Elapsed time for detection of sources in seconds = ',tCPU
    write(IMAIN,*)
    write(IMAIN,*) 'End of source detection - done'
    write(IMAIN,*)
  endif

  end subroutine locate_sources

