!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  3 . 3
!          --------------------------------------------------
!
!                 Dimitri Komatitsch and Jeroen Tromp
!    Seismological Laboratory - California Institute of Technology
!        (c) California Institute of Technology September 2002
!
!    A signed non-commercial agreement is required to use this program.
!   Please check http://www.gps.caltech.edu/research/jtromp for details.
!           Free for non-commercial academic research ONLY.
!      This program is distributed WITHOUT ANY WARRANTY whatsoever.
!      Do not redistribute this program without written permission.
!
!=====================================================================

!----
!----  locate_source finds the correct position of the source
!----

! to locate the source we loop in elements above the 670 only

  subroutine locate_source(isource,NSOURCES,myrank,nspec,nglob,idoubling,ibool,&
                 xstore,ystore,zstore,xigll,yigll,zigll, &
                 NPROCTOT,ELLIPTICITY,TOPOGRAPHY, &
                 sec,t_cmt,yr,jda,ho,mi,theta_source,phi_source, &
                 NSTEP,DT,hdur,Mxx,Myy,Mzz,Mxy,Mxz,Myz, &
                 islice_selected_source,ispec_selected_source, &
                 xi_source,eta_source,gamma_source, &
                 rspl,espl,espl2,nspl,ibathy_topo)

  implicit none

! standard include of the MPI library
  include 'mpif.h'

  include "constants.h"
  include "precision.h"

  integer NPROCTOT

  logical ELLIPTICITY,TOPOGRAPHY

  integer NSTEP,NSOURCES
  double precision DT

! use integer array to store values
  integer ibathy_topo(NX_BATHY,NY_BATHY)

! for ellipticity
  integer nspl
  double precision rspl(NR),espl(NR),espl2(NR)

  integer nspec,nglob,myrank,isource

  integer idoubling(nspec)
  integer ibool(NGLLX,NGLLY,NGLLZ,nspec)

! arrays containing coordinates of the points
  real(kind=CUSTOM_REAL), dimension(nglob) :: xstore,ystore,zstore

! Gauss-Lobatto-Legendre points of integration
  double precision xigll(NGLLX),yigll(NGLLY),zigll(NGLLZ)

  integer yr,jda,ho,mi

  double precision sec,t_cmt

  integer iprocloop

  integer i,j,k,ispec,iglob
  integer ier

  double precision ell
  double precision elevation
  double precision r0,dcost,p20
  double precision theta,phi
  double precision theta_source,phi_source
  double precision dist
  double precision xi,eta,gamma,dx,dy,dz,dxi,deta

! topology of the control points of the surface element
  integer iax,iay,iaz
  integer iaddx(NGNOD),iaddy(NGNOD),iaddz(NGNOD)

! coordinates of the control points of the surface element
  double precision xelm(NGNOD),yelm(NGNOD),zelm(NGNOD)

  integer iter_loop

  integer ia
  double precision x,y,z
  double precision xix,xiy,xiz
  double precision etax,etay,etaz
  double precision gammax,gammay,gammaz
  double precision dgamma

  double precision final_distance_source

  double precision x_target_source,y_target_source,z_target_source
  double precision r_target_source

  integer islice_selected_source

! timer MPI
  double precision time_start,tCPU

  integer ispec_selected_source

  integer, dimension(0:NPROCTOT-1) :: ispec_selected_source_all
  double precision, dimension(0:NPROCTOT-1) :: xi_source_all,eta_source_all,gamma_source_all, &
     final_distance_source_all,x_found_source_all,y_found_source_all,z_found_source_all

  double precision hdur

  double precision Mxx,Myy,Mzz,Mxy,Mxz,Myz
  double precision xi_source,eta_source,gamma_source

  double precision elat,elon,depth
  double precision relat,relon,rdepth
  double precision scalar_moment,moment_tensor(6)
  double precision radius

  character(len=150) cmt_file,plot_file

  double precision x_found_source,y_found_source,z_found_source,r_found_source
  double precision st,ct,sp,cp
  double precision Mrr,Mtt,Mpp,Mrt,Mrp,Mtp
  double precision colat_source
  double precision distmin

  integer :: ix_initial_guess_source,iy_initial_guess_source,iz_initial_guess_source

! for calculation of source time function and spectrum
  integer it,iom
  double precision time_source,om
  double precision, external :: comp_source_time_function,comp_source_spectrum

! number of points to plot the source time function and spectrum
  integer, parameter :: NSAMP_PLOT_SOURCE = 1000

! **************

! get MPI starting time
  time_start = MPI_WTIME()

  if(myrank == 0) then
    write(IMAIN,*)
    write(IMAIN,*) '*************************************'
    write(IMAIN,*) ' locating source ',isource
    write(IMAIN,*) '*************************************'
    write(IMAIN,*)
  endif

! define topology of the control element
  call usual_hex_nodes(iaddx,iaddy,iaddz)

  call get_cmt(yr,jda,ho,mi,sec,t_cmt,hdur,elat,elon,depth,moment_tensor,DT,isource)

  if(isource == 1) then
    if(t_cmt /= 0.) call exit_MPI(myrank,'t_cmt for the first source should be zero')
  else
    if(t_cmt < 0.) call exit_MPI(myrank,'t_cmt should not be less than zero')
  endif

  scalar_moment = 0.
  do i = 1,6
    scalar_moment = scalar_moment + moment_tensor(i)**2
  enddo
  scalar_moment = dsqrt(scalar_moment/2.)

! convert geographic latitude elat (degrees)
! to geocentric colatitude theta (radians)
  theta=PI/2.0d0-atan(0.99329534d0*dtan(elat*PI/180.0d0))
  phi=elon*PI/180.0d0
  call reduce(theta,phi)

! get the moment tensor
  Mrr = moment_tensor(1)
  Mtt = moment_tensor(2)
  Mpp = moment_tensor(3)
  Mrt = moment_tensor(4)
  Mrp = moment_tensor(5)
  Mtp = moment_tensor(6)

! convert from a spherical to a Cartesian representation of the moment tensor
  st=dsin(theta)
  ct=dcos(theta)
  sp=dsin(phi)
  cp=dcos(phi)

  Mxx=st*st*cp*cp*Mrr+ct*ct*cp*cp*Mtt+sp*sp*Mpp &
      +2.0d0*st*ct*cp*cp*Mrt-2.0d0*st*sp*cp*Mrp-2.0d0*ct*sp*cp*Mtp
  Myy=st*st*sp*sp*Mrr+ct*ct*sp*sp*Mtt+cp*cp*Mpp &
      +2.0d0*st*ct*sp*sp*Mrt+2.0d0*st*sp*cp*Mrp+2.0d0*ct*sp*cp*Mtp
  Mzz=ct*ct*Mrr+st*st*Mtt-2.0d0*st*ct*Mrt
  Mxy=st*st*sp*cp*Mrr+ct*ct*sp*cp*Mtt-sp*cp*Mpp &
      +2.0d0*st*ct*sp*cp*Mrt+st*(cp*cp-sp*sp)*Mrp+ct*(cp*cp-sp*sp)*Mtp
  Mxz=st*ct*cp*Mrr-st*ct*cp*Mtt &
      +(ct*ct-st*st)*cp*Mrt-ct*sp*Mrp+st*sp*Mtp
  Myz=st*ct*sp*Mrr-st*ct*sp*Mtt &
      +(ct*ct-st*st)*sp*Mrt+ct*cp*Mrp-st*cp*Mtp

! normalized source radius
  r0 = R_UNIT_SPHERE

  if(ELLIPTICITY) then
    if(TOPOGRAPHY) then
      call get_topo_bathy(elat,elon,elevation,ibathy_topo)
      r0 = r0 + elevation/R_EARTH
    endif
    dcost = dcos(theta)
    p20 = 0.5d0*(3.0d0*dcost*dcost-1.0d0)
    radius = r0 - depth*1000.0d0/R_EARTH
    call splint(rspl,espl,espl2,nspl,radius,ell)
    r0 = r0*(1.0d0-(2.0d0/3.0d0)*ell*p20)
  endif

! compute the Cartesian position of the source
  r_target_source = r0 - depth*1000.0d0/R_EARTH
  x_target_source = r_target_source*dsin(theta)*dcos(phi)
  y_target_source = r_target_source*dsin(theta)*dsin(phi)
  z_target_source = r_target_source*dcos(theta)

! set distance to huge initial value
  distmin = HUGEVAL

  do ispec=1,nspec

! loop on elements in the crust or in mantle above d660 only
  if(idoubling(ispec) == IFLAG_MANTLE_NORMAL .or. &
     idoubling(ispec) == IFLAG_BOTTOM_MANTLE_LEV2 .or. &
     idoubling(ispec) == IFLAG_BOTTOM_MANTLE) cycle

! loop only on points inside the element
! exclude edges to ensure this point is not shared with other elements
  do k=2,NGLLZ-1
    do j=2,NGLLY-1
      do i=2,NGLLX-1

!       keep this point if it is closer to the receiver
        iglob = ibool(i,j,k,ispec)
        dist=dsqrt((x_target_source-dble(xstore(iglob)))**2 &
                  +(y_target_source-dble(ystore(iglob)))**2 &
                  +(z_target_source-dble(zstore(iglob)))**2)
        if(dist < distmin) then
          distmin=dist
          ispec_selected_source=ispec
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

    if(iaddz(ia) == 0) then
      iaz = 1
    else if(iaddz(ia) == 1) then
      iaz = (NGLLZ+1)/2
    else if(iaddz(ia) == 2) then
      iaz = NGLLZ
    else
      call exit_MPI(myrank,'incorrect value of iaddz')
    endif

    iglob = ibool(iax,iay,iaz,ispec_selected_source)
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
  xi_source = xi
  eta_source = eta
  gamma_source = gamma
  x_found_source = x
  y_found_source = y
  z_found_source = z

! compute final distance between asked and found (converted to km)
  final_distance_source = dsqrt((x_target_source-x_found_source)**2 + &
    (y_target_source-y_found_source)**2 + (z_target_source-z_found_source)**2)*R_EARTH/1000.d0

! synchronize all the processes to make sure all the estimates are available
  call MPI_BARRIER(MPI_COMM_WORLD,ier)

! for MPI version, now gather information from all the nodes
  ispec_selected_source_all(:) = -1
  call MPI_GATHER(ispec_selected_source,1,MPI_INTEGER,ispec_selected_source_all,1,MPI_INTEGER,0,MPI_COMM_WORLD,ier)

  call MPI_GATHER(xi_source,1,MPI_DOUBLE_PRECISION,xi_source_all,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(eta_source,1,MPI_DOUBLE_PRECISION,eta_source_all,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(gamma_source,1,MPI_DOUBLE_PRECISION,gamma_source_all,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(final_distance_source,1,MPI_DOUBLE_PRECISION, &
    final_distance_source_all,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(x_found_source,1,MPI_DOUBLE_PRECISION, &
    x_found_source_all,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(y_found_source,1,MPI_DOUBLE_PRECISION, &
    y_found_source_all,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_GATHER(z_found_source,1,MPI_DOUBLE_PRECISION, &
    z_found_source_all,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)

! MPI this is executed by main process only
  if(myrank == 0) then

! check that the gather operation went well
  if(any(ispec_selected_source_all(:) == -1)) call exit_MPI(myrank,'gather operation failed for source')

! MPI loop on all the results to determine the best slice
  distmin = HUGEVAL
  do iprocloop = 0,NPROCTOT-1
    if(final_distance_source_all(iprocloop) < distmin) then
      distmin = final_distance_source_all(iprocloop)
      islice_selected_source = iprocloop
      ispec_selected_source = ispec_selected_source_all(iprocloop)
      xi_source = xi_source_all(iprocloop)
      eta_source = eta_source_all(iprocloop)
      gamma_source = gamma_source_all(iprocloop)
      x_found_source = x_found_source_all(iprocloop)
      y_found_source = y_found_source_all(iprocloop)
      z_found_source = z_found_source_all(iprocloop)
    endif
  enddo
  final_distance_source = distmin

    write(IMAIN,*)
    write(IMAIN,*) 'source located in slice ',islice_selected_source
    write(IMAIN,*) '               in element ',ispec_selected_source
    write(IMAIN,*)
    write(IMAIN,*) '   xi coordinate of source in that element: ',xi_source
    write(IMAIN,*) '  eta coordinate of source in that element: ',eta_source
    write(IMAIN,*) 'gamma coordinate of source in that element: ',gamma_source

! add message if source is a Heaviside
    if(hdur < 5.*DT) then
      write(IMAIN,*)
      write(IMAIN,*) 'Source time function is a Heaviside, convolve later'
      write(IMAIN,*)
    endif

    write(IMAIN,*)
    write(IMAIN,*) ' half duration: ',hdur,' seconds'
    write(IMAIN,*)

    write(IMAIN,*)
    write(IMAIN,*) '    time shift: ',t_cmt,' seconds'
    write(IMAIN,*)

! get latitude, longitude and depth of the source that will be used
    call xyz_2_rthetaphi_dble(x_found_source,y_found_source,z_found_source,r_found_source,theta_source,phi_source)
    call reduce(theta_source,phi_source)

! convert geocentric to geographic colatitude
    colat_source=PI/2.0d0-datan(1.006760466d0*dcos(theta_source)/dmax1(TINYVAL,dsin(theta_source)))
    if(phi_source>PI) phi_source=phi_source-TWO_PI

! compute real position of the source
    relat = (PI/2.0d0-colat_source)*180.0d0/PI
    relon = phi_source*180.0d0/PI
    rdepth = (r0-r_found_source)*R_EARTH/1000.0d0

    write(IMAIN,*)
    write(IMAIN,*) 'original (requested) position of the source:'
    write(IMAIN,*)
    write(IMAIN,*) '      latitude: ',elat
    write(IMAIN,*) '     longitude: ',elon
    write(IMAIN,*) '         depth: ',depth,' km'

    write(IMAIN,*)
    write(IMAIN,*) 'position of the source that will be used:'
    write(IMAIN,*)
    write(IMAIN,*) '      latitude: ',relat
    write(IMAIN,*) '     longitude: ',relon
    write(IMAIN,*) '         depth: ',rdepth,' km'
    write(IMAIN,*)

! display error in location estimate
    write(IMAIN,*) 'error in location of the source: ',sngl(final_distance_source),' km'

! add warning if estimate is poor
! (usually means source outside the mesh given by the user)
    if(final_distance_source > 50.d0) then
      write(IMAIN,*)
      write(IMAIN,*) '*****************************************************'
      write(IMAIN,*) '*****************************************************'
      write(IMAIN,*) '***** WARNING: source location estimate is poor *****'
      write(IMAIN,*) '*****************************************************'
      write(IMAIN,*) '*****************************************************'
    endif

  write(IMAIN,*)
  write(IMAIN,*) 'printing the source-time function'

! print the source-time function
  if(NSOURCES == 1) then
    plot_file = 'OUTPUT_FILES/plot_source_time_function.txt'
  else
   if(isource < 10) then
      write(plot_file,"('OUTPUT_FILES/plot_source_time_function',i1,'.txt')") isource
    elseif(isource < 100) then
      write(plot_file,"('OUTPUT_FILES/plot_source_time_function',i2,'.txt')") isource
    else
      write(plot_file,"('OUTPUT_FILES/plot_source_time_function',i3,'.txt')") isource
    endif
  endif
  open(unit=27,file=plot_file(1:len_trim(plot_file)),status='unknown')

  do it=1,NSTEP
    time_source = dble(it-1)*DT-hdur-t_cmt
    write(27,*) sngl(dble(it-1)*DT),sngl(scalar_moment*comp_source_time_function(time_source,hdur))
  enddo
  close(27)

  write(IMAIN,*)
  write(IMAIN,*) 'printing the source spectrum'

! print the spectrum of the derivative of the source from 0 to 1/8 Hz
  if(NSOURCES == 1) then
   plot_file = 'OUTPUT_FILES/plot_source_spectrum.txt'
  else
   if(isource < 10) then
      write(plot_file,"('OUTPUT_FILES/plot_source_spectrum',i1,'.txt')") isource
    elseif(isource < 100) then
      write(plot_file,"('OUTPUT_FILES/plot_source_spectrum',i2,'.txt')") isource
    else
      write(plot_file,"('OUTPUT_FILES/plot_source_spectrum',i3,'.txt')") isource
    endif
  endif
  open(unit=27,file=plot_file(1:len_trim(plot_file)),status='unknown')

  do iom=1,NSAMP_PLOT_SOURCE
    om=TWO_PI*(1.0d0/8.0d0)*(iom-1)/dble(NSAMP_PLOT_SOURCE-1)
    write(27,*) sngl(om/TWO_PI),sngl(scalar_moment*om*comp_source_spectrum(om,hdur))
  enddo
  close(27)

! elapsed time since beginning of mesh generation
  tCPU = MPI_WTIME() - time_start
  write(IMAIN,*)
  write(IMAIN,*) 'Elapsed time for source detection in seconds = ',tCPU
  write(IMAIN,*)
  write(IMAIN,*) 'End of source detection - done'
  write(IMAIN,*)

  endif     ! end of section executed by main process only

! main process broadcasts the results to all the slices
  call MPI_BCAST(islice_selected_source,1,MPI_INTEGER,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(ispec_selected_source,1,MPI_INTEGER,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(xi_source,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(eta_source,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(gamma_source,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)

! synchronize all the processes to make sure everybody has finished
  call MPI_BARRIER(MPI_COMM_WORLD,ier)

  end subroutine locate_source

