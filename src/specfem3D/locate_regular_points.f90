!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  5 . 1
!          --------------------------------------------------
!
!          Main authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!             and CNRS / INRIA / University of Pau, France
! (c) Princeton University and CNRS / INRIA / University of Pau
!                            April 2011
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 2 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
!=====================================================================

subroutine read_kl_regular_grid(GRID)

  implicit none
  include 'constants.h'

  type kl_reg_grid_variables
    sequence
    real dlat
    real dlon
    integer nlayer
    real rlayer(NM_KL_REG_LAYER)
    integer ndoubling(NM_KL_REG_LAYER)
    integer nlat(NM_KL_REG_LAYER)
    integer nlon(NM_KL_REG_LAYER)
    integer npts_total
    integer npts_before_layer(NM_KL_REG_LAYER+1)
  end type kl_reg_grid_variables

  type (kl_reg_grid_variables), intent(inout) :: GRID

  integer :: ios,nlayer,i,nlat,nlon,npts_this_layer

  ! improvements to make: read-in by master and broadcast to all slaves
  open(10,file=PATHNAME_KL_REG,iostat=ios,status='old',action='read')

  read(10,*) GRID%dlat, GRID%dlon

  nlayer = 1
  do while (nlayer <= NM_KL_REG_LAYER)
    read(10,*,iostat=ios) GRID%rlayer(nlayer), GRID%ndoubling(nlayer)
    if (ios/=0) exit
    nlayer = nlayer + 1
  enddo
  close(10)

  if (nlayer > NM_KL_REG_LAYER) then
    call exit_MPI('Increase NM_KL_REG_LAYER limit')
  endif

  GRID%nlayer = nlayer

  GRID%npts_total = 0
  GRID%npts_before_layer = 0
  do i = 1, nlayer
    nlon = floor((KL_REG_MAX_LON-KL_REG_MIN_LON)/(GRID%dlon*GRID%ndoubling(i)))+1
    GRID%nlon(i) = nlon
    nlat = floor((KL_REG_MAX_LAT-KL_REG_MIN_LAT)/(GRID%dlat*GRID%ndoubling(i)))+1
    GRID%nlat(i) = nlat
    npts_this_layer = nlon * nlat
    GRID%npts_total = GRID%npts_total + npts_this_layer
    GRID%npts_before_layer(i+1) = GRID%npts_before_layer(i) + npts_this_layer
  enddo
  if (GRID%npts_total <= 0) then
    call exit_MPI('No Model points read in')
  endif

end subroutine read_kl_regular_grid

!==============================================================

subroutine find_regular_grid_slice_number(slice_number, GRID, &
                                          NCHUNKS, NPROC_XI, NPROC_ETA)

  implicit none
  include 'constants.h'

  integer, intent(out) :: slice_number(*)

  type kl_reg_grid_variables
    sequence
    real dlat
    real dlon
    integer nlayer
    real rlayer(NM_KL_REG_LAYER)
    integer ndoubling(NM_KL_REG_LAYER)
    integer nlat(NM_KL_REG_LAYER)
    integer nlon(NM_KL_REG_LAYER)
    integer npts_total
    integer npts_before_layer(NM_KL_REG_LAYER+1)
  end type kl_reg_grid_variables
  type (kl_reg_grid_variables), intent(in) :: GRID

  integer, intent(in) :: NCHUNKS,NPROC_XI,NPROC_ETA

  real(kind=CUSTOM_REAL) :: xi_width, eta_width
  integer :: nproc, ilayer, isp, ilat, ilon, k, chunk_isp
  integer :: iproc_xi, iproc_eta
  real :: lat,lon,th,ph,x,y,z,xik,etak,xi_isp,eta_isp,xi1,eta1

  ! assuming 6 chunks full global simulations right now
  if (NCHUNKS /= 6 .or. NPROC_XI /= NPROC_ETA) then
    call exit_MPI('Only deal with 6 chunks at this moment')
  endif

  xi_width=PI/2; eta_width=PI/2; nproc=NPROC_XI
  ilayer=0

  do isp = 1,GRID%npts_total
    if (isp == GRID%npts_before_layer(ilayer+1)+1) ilayer=ilayer+1
    ilat = (isp - GRID%npts_before_layer(ilayer) - 1) / GRID%nlat(ilayer)
    ilon = (isp - GRID%npts_before_layer(ilayer) - 1) - ilat * GRID%nlat(ilayer)

    ! (lat,lon,radius) for isp point
    lat = KL_REG_MIN_LAT + ilat * GRID%dlat * GRID%ndoubling(ilayer)
    th = (90 - lat) * DEGREES_TO_RADIANS
    lon = KL_REG_MIN_LON + ilon * GRID%dlon * GRID%ndoubling(ilayer)
    ph = lon * DEGREES_TO_RADIANS
    x = sin(th) * cos(ph); y = sin(th) * sin(ph); z = cos(th)

    ! figure out slice number
    chunk_isp = 1; xi_isp = 0; eta_isp = 0
    do k = 1, NCHUNKS
      call chunk_map(k, x, y, z, xik, etak)
      if (abs(xik) <= PI/4 .and. abs(etak) <= PI/4) then
        chunk_isp = k;  xi_isp = xik; eta_isp = etak; exit
      endif
    enddo
    xi1 = xi_isp / xi_width * 2; eta1 = eta_isp / eta_width * 2
    iproc_xi = floor((xi1+1)/2 * nproc)
    iproc_eta = floor((eta1+1)/2 * nproc)
    slice_number(isp) = nproc * nproc * (chunk_isp-1) + nproc * iproc_eta + iproc_xi
  enddo

end subroutine find_regular_grid_slice_number

!==============================================================

! how about using single precision for the iterations?
subroutine locate_reg_points(npoints_slice,points_slice,GRID, &
                             NEX_XI,nspec,xstore,ystore,zstore,ibool, &
                             xigll,yigll,zigll,ispec_reg, &
                             hxir_reg,hetar_reg,hgammar_reg)

  implicit none
  include 'constants.h'

  ! declarations of regular grid model
  integer, intent(in) :: npoints_slice
  integer, dimension(NM_KL_REG_PTS), intent(in) :: points_slice

  type kl_reg_grid_variables
    sequence
    real dlat
    real dlon
    integer nlayer
    real rlayer(NM_KL_REG_LAYER)
    integer ndoubling(NM_KL_REG_LAYER)
    integer nlat(NM_KL_REG_LAYER)
    integer nlon(NM_KL_REG_LAYER)
    integer npts_total
    integer npts_before_layer(NM_KL_REG_LAYER+1)
  end type kl_reg_grid_variables
  type (kl_reg_grid_variables), intent(in) :: GRID

  ! simulation geometry
  integer, intent(in) :: NEX_XI, nspec
  real(kind=CUSTOM_REAL), dimension(*), intent(in) :: xstore,ystore,zstore
  integer, dimension(NGLLX,NGLLY,NGLLZ,*), intent(in) :: ibool

  ! Gauss-Lobatto-Legendre points of integration and weights
  double precision, dimension(NGLLX), intent(in) :: xigll
  double precision, dimension(NGLLY), intent(in) :: yigll
  double precision, dimension(NGLLZ), intent(in) :: zigll

  ! output
  integer, dimension(NM_KL_REG_PTS), intent(out) :: ispec_reg
  real(kind=CUSTOM_REAL), dimension(NGLLX,NM_KL_REG_PTS), intent(out) :: hxir_reg
  real(kind=CUSTOM_REAL), dimension(NGLLY,NM_KL_REG_PTS), intent(out) :: hetar_reg
  real(kind=CUSTOM_REAL), dimension(NGLLZ,NM_KL_REG_PTS), intent(out) :: hgammar_reg

  ! GLL number of anchors
  integer, dimension(NGNOD) :: iaddx, iaddy, iaddr

  integer :: i, j, k, isp, ilayer, ilat, ilon, iglob, ix_in, iy_in, iz_in
  integer :: ispec_in, ispec, iter_loop, ia, ipoint
  double precision :: lat, lon, radius, th, ph, x,y,z
  double precision :: x_target, y_target, z_target
  double precision :: distmin,dist,typical_size
  double precision :: xi,eta,gamma,dx,dy,dz,dxi,deta,dgamma
  double precision :: xix,xiy,xiz
  double precision :: etax,etay,etaz
  double precision :: gammax,gammay,gammaz

  logical locate_target
  double precision, dimension(NGNOD) :: xelm, yelm, zelm

  double precision, dimension(NGLLX) :: hxir
  double precision, dimension(NGLLY) :: hetar
  double precision, dimension(NGLLZ) :: hgammar

  ! DEBUG
  !real(kind=CUSTOM_REAL), dimension(npoints_slice) :: dist_final

  !---------------------------

  call hex_nodes2(iaddx,iaddy,iaddr)

  ! compute typical size of elements at the surface
  typical_size = TWO_PI * R_UNIT_SPHERE / (4.*NEX_XI)

  ! use 10 times the distance as a criterion for source detection
  typical_size = 10. * typical_size

  ! DEBUG
  !dist_final=HUGEVAL

  do ipoint = 1, npoints_slice
    isp = points_slice(ipoint)
    do ilayer = 1, GRID%nlayer
      if (isp <= GRID%npts_before_layer(ilayer+1)) exit
    enddo

    ilat = (isp - GRID%npts_before_layer(ilayer) - 1) / GRID%nlat(ilayer)
    ilon = (isp - GRID%npts_before_layer(ilayer) - 1) - ilat * GRID%nlat(ilayer)

    ! (lat,lon,radius) for isp point
    lat = KL_REG_MIN_LAT + ilat * GRID%dlat * GRID%ndoubling(ilayer)
    lon = KL_REG_MIN_LON + ilon * GRID%dlon * GRID%ndoubling(ilayer)
    ! convert radius to meters and then scale
    radius = GRID%rlayer(ilayer) * 1000.0 / R_EARTH
    ! (x,y,z) for isp point
    th = (90 - lat) * DEGREES_TO_RADIANS; ph = lon * DEGREES_TO_RADIANS
    x_target = radius * sin(th) * cos(ph)
    y_target = radius * sin(th) * sin(ph)
    z_target = radius * cos(th)

    ! first exclude elements too far away
    locate_target = .false.;  distmin = HUGEVAL
    do ispec = 1,nspec
      iglob = ibool(1,1,1,ispec)
      dist = dsqrt((x_target - xstore(iglob))**2 &
                 + (y_target - ystore(iglob))**2 &
                 + (z_target - zstore(iglob))**2)
      if (dist > typical_size) cycle

      locate_target = .true.
      ! loop only on points inside the element
      ! exclude edges to ensure this point is not
      ! shared with other elements
      ! can be improved if we have a better algorithm of determining if a point
      ! exists inside a 3x3x3 specfem element ???

      do k = 2, NGLLZ-1
        do j = 2, NGLLY-1
          do i = 2, NGLLX-1
            iglob = ibool(i,j,k,ispec)
            dist = dsqrt((x_target - xstore(iglob))**2 &
                        +(y_target - ystore(iglob))**2 &
                        +(z_target - zstore(iglob))**2)
            if (dist < distmin) then
              ix_in=i; iy_in=j; iz_in=k; ispec_in=ispec; distmin=dist
            endif
          enddo
        enddo
      enddo

    enddo
    if (.not. locate_target) stop 'error in point_source() array'

    xi = xigll(ix_in)
    eta = yigll(iy_in)
    gamma = zigll(iz_in)
    ispec_reg(ipoint) = ispec_in

    ! anchors
    do ia = 1, NGNOD
      iglob = ibool(iaddx(ia), iaddy(ia), iaddr(ia), ispec_in)
      xelm(ia) = dble(xstore(iglob))
      yelm(ia) = dble(ystore(iglob))
      zelm(ia) = dble(zstore(iglob))
    enddo

    ! iterate to solve the nonlinear system
    do iter_loop = 1,NUM_ITER

      ! recompute jacobian for the new point
      call recompute_jacobian(xelm,yelm,zelm, xi,eta,gamma, x,y,z, &
                              xix,xiy,xiz, etax,etay,etaz, gammax,gammay,gammaz)

      ! compute distance to target location
      dx = - (x - x_target)
      dy = - (y - y_target)
      dz = - (z - z_target)

      ! compute increments
      dxi  = xix*dx + xiy*dy + xiz*dz
      deta = etax*dx + etay*dy + etaz*dz
      dgamma = gammax*dx + gammay*dy + gammaz*dz

      ! update values
      xi = xi + dxi
      eta = eta + deta
      gamma = gamma + dgamma

      ! Debugging
      !if (abs(xi) > 1.d0+TINYVAL .or. abs(eta) > 1.d0+TINYVAL &
      !     .or. abs(gamma) > 1.0d0+TINYVAL) then
      !   print *, 'Outside the element ', myrank, ipoint,' : ', &
      !        iter_loop,xi,eta,gamma
      !endif

      ! impose that we stay in that element
      ! (useful if user gives a source outside the mesh for instance)
      if (xi > 1.d0) xi = 1.d0
      if (xi < -1.d0) xi = -1.d0
      if (eta > 1.d0) eta = 1.d0
      if (eta < -1.d0) eta = -1.d0
      if (gamma > 1.d0) gamma = 1.d0
      if (gamma < -1.d0) gamma = -1.d0

    enddo

    ! DEBUG: recompute jacobian for the new point (can be commented after debug)
    !call recompute_jacobian(xelm,yelm,zelm,xi,eta,gamma,x,y,z,xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz)
    !dist_final(ipoint)=dsqrt((x_target-x)**2+(y_target-y)**2+(z_target-z)**2)

    ! store l(xi),l(eta),l(gamma)
    call lagrange_any2(xi, NGLLX, xigll, hxir)
    call lagrange_any2(eta, NGLLY, yigll, hetar)
    call lagrange_any2(gamma, NGLLZ, zigll, hgammar)
    hxir_reg(:,ipoint) = hxir
    hetar_reg(:,ipoint) = hetar
    hgammar_reg(:,ipoint) = hgammar

  enddo ! ipoint

! DEBUG
!  print *, 'Maximum distance discrepancy ', maxval(dist_final(1:npoints_slice))

end subroutine locate_reg_points

!==============================================================

subroutine hex_nodes2(iaddx,iaddy,iaddz)

  implicit none
  include 'constants.h'

  integer, dimension(NGNOD), intent(out) :: iaddx,iaddy,iaddz
  integer :: ia

  ! define topology of the control element
  call hex_nodes(iaddx,iaddy,iaddz)

  ! define coordinates of the control points of the element
  do ia=1,NGNOD

     if (iaddx(ia) == 0) then
        iaddx(ia) = 1
     else if (iaddx(ia) == 1) then
        iaddx(ia) = (NGLLX+1)/2
     else if (iaddx(ia) == 2) then
        iaddx(ia) = NGLLX
     else
        stop 'incorrect value of iaddx'
     endif

     if (iaddy(ia) == 0) then
        iaddy(ia) = 1
     else if (iaddy(ia) == 1) then
        iaddy(ia) = (NGLLY+1)/2
     else if (iaddy(ia) == 2) then
        iaddy(ia) = NGLLY
     else
        stop 'incorrect value of iaddy'
     endif

     if (iaddz(ia) == 0) then
        iaddz(ia) = 1
     else if (iaddz(ia) == 1) then
        iaddz(ia) = (NGLLZ+1)/2
     else if (iaddz(ia) == 2) then
        iaddz(ia) = NGLLZ
     else
        stop 'incorrect value of iaddz'
     endif

  enddo

end subroutine hex_nodes2

!==============================================================

subroutine lagrange_any2(xi,NGLL,xigll,h)

! subroutine to compute the Lagrange interpolants based upon the GLL points
! and their first derivatives at any point xi in [-1,1]

  implicit none

  double precision, intent(in) :: xi
  integer, intent(in) :: NGLL
  double precision, dimension(NGLL), intent(in) :: xigll
  double precision, dimension(NGLL), intent(out) :: h

  integer :: dgr,i
  double precision :: prod1,prod2

  do dgr=1,NGLL
     prod1 = 1.0d0
     prod2 = 1.0d0

     do i=1,NGLL
        if (i /= dgr) then
           prod1 = prod1 * (xi         - xigll(i))
           prod2 = prod2 * (xigll(dgr) - xigll(i))
        endif
     enddo

     h(dgr) = prod1 / prod2
  enddo

end subroutine lagrange_any2

!==============================================================

subroutine chunk_map(k,xx,yy,zz,xi,eta)

  ! this program get the xi,eta for (xx,yy,zz)
  ! point under the k'th chunk coordinate
  ! transformation

  implicit none
  include 'constants.h'

  integer, intent(in) :: k
  real, intent(in) :: xx, yy, zz
  real, intent(out) :: xi, eta

  real :: x, y, z
  real, parameter :: EPS=1e-6

  x = xx; y = yy; z = zz
  if (0 <= x .and. x < EPS)  x = EPS
  if (-EPS < x .and. x < 0)  x = -EPS
  if (0 <= y .and. y < EPS)  y = EPS
  if (-EPS < y .and. y < 0)  y = -EPS
  if (0 <= z .and. z < EPS)  z = EPS
  if (-EPS < z .and. z < 0)  z = -EPS

  if (k == CHUNK_AB) then
     xi = atan(y/z); eta = atan(-x/z)
     if (z < 0)  xi = 10
  else if (k == CHUNK_AC) then
     xi = atan(-z/y); eta = atan(x/y)
     if (y > 0)  xi = 10
  else if (k == CHUNK_BC) then
     xi = atan(-z/x); eta = atan(-y/x)
     if (x > 0)  xi = 10
  else if (k == CHUNK_AC_ANTIPODE) then
     xi = atan(-z/y); eta = atan(-x/y)
     if (y < 0)  xi = 10
  else if (k == CHUNK_BC_ANTIPODE) then
     xi = atan(z/x); eta = atan(-y/x)
     if (x < 0)  xi = 10
  else if (k == CHUNK_AB_ANTIPODE) then
     xi = atan(y/z); eta = atan(x/z)
     if (z > 0)  xi = 10
  else
     stop 'chunk number k < 6'
  endif

end subroutine chunk_map

