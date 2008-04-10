!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  4 . 0
!          --------------------------------------------------
!
!          Main authors: Dimitri Komatitsch and Jeroen Tromp
!    Seismological Laboratory, California Institute of Technology, USA
!             and University of Pau / CNRS / INRIA, France
! (c) California Institute of Technology and University of Pau / CNRS / INRIA
!                            February 2008
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

  subroutine get_MPI_1D_buffers(myrank,prname,nspec,iMPIcut_xi,iMPIcut_eta,ibool, &
                        idoubling,xstore,ystore,zstore,mask_ibool,npointot, &
                        NSPEC1D_RADIAL_CORNER,NGLOB1D_RADIAL_CORNER,iregion)

! routine to create the MPI 1D chunk buffers for edges

  implicit none

  include "constants.h"

  integer nspec,myrank,nglob,ipoin1D,iregion
  integer, dimension(MAX_NUM_REGIONS,NB_SQUARE_CORNERS) :: NSPEC1D_RADIAL_CORNER,NGLOB1D_RADIAL_CORNER

  logical iMPIcut_xi(2,nspec)
  logical iMPIcut_eta(2,nspec)

  integer ibool(NGLLX,NGLLY,NGLLZ,nspec)

  integer idoubling(nspec)

  double precision xstore(NGLLX,NGLLY,NGLLZ,nspec)
  double precision ystore(NGLLX,NGLLY,NGLLZ,nspec)
  double precision zstore(NGLLX,NGLLY,NGLLZ,nspec)

! logical mask used to create arrays ibool1D
  integer npointot
  logical mask_ibool(npointot)

! global element numbering
  integer ispec

! MPI 1D buffer element numbering
  integer ispeccount,npoin1D,ix,iy,iz

! processor identification
  character(len=150) prname

! arrays for sorting routine
  integer, dimension(:), allocatable :: ind,ninseg,iglob,locval,iwork
  logical, dimension(:), allocatable :: ifseg
  double precision, dimension(:), allocatable :: work
  integer, dimension(:), allocatable :: ibool_selected
  double precision, dimension(:), allocatable :: xstore_selected,ystore_selected,zstore_selected

! allocate arrays for message buffers with maximum size
! define maximum size for message buffers
  if (PERFORM_CUTHILL_MCKEE) then
    allocate(ibool_selected(maxval(NGLOB1D_RADIAL_CORNER(iregion,:))))
    allocate(xstore_selected(maxval(NGLOB1D_RADIAL_CORNER(iregion,:))))
    allocate(ystore_selected(maxval(NGLOB1D_RADIAL_CORNER(iregion,:))))
    allocate(zstore_selected(maxval(NGLOB1D_RADIAL_CORNER(iregion,:))))
    allocate(ind(maxval(NGLOB1D_RADIAL_CORNER(iregion,:))))
    allocate(ninseg(maxval(NGLOB1D_RADIAL_CORNER(iregion,:))))
    allocate(iglob(maxval(NGLOB1D_RADIAL_CORNER(iregion,:))))
    allocate(locval(maxval(NGLOB1D_RADIAL_CORNER(iregion,:))))
    allocate(ifseg(maxval(NGLOB1D_RADIAL_CORNER(iregion,:))))
    allocate(iwork(maxval(NGLOB1D_RADIAL_CORNER(iregion,:))))
    allocate(work(maxval(NGLOB1D_RADIAL_CORNER(iregion,:))))
  endif

! write the MPI buffers for the left and right edges of the slice
! and the position of the points to check that the buffers are fine

! *****************************************************************
! ****************** generate for eta = eta_min *******************
! *****************************************************************

! determine if the element falls on the left MPI cut plane

! global point number and coordinates left MPI 1D buffer
  open(unit=10,file=prname(1:len_trim(prname))//'ibool1D_leftxi_lefteta.txt',status='unknown')

! erase the logical mask used to mark points already found
  mask_ibool(:) = .false.

! nb of global points shared with the other slice
  npoin1D = 0

! nb of elements in this 1D buffer
  ispeccount=0

  do ispec=1,nspec
    ! remove central cube for chunk buffers
    if(idoubling(ispec) == IFLAG_MIDDLE_CENTRAL_CUBE .or. &
      idoubling(ispec) == IFLAG_BOTTOM_CENTRAL_CUBE .or. &
      idoubling(ispec) == IFLAG_TOP_CENTRAL_CUBE .or. &
      idoubling(ispec) == IFLAG_IN_FICTITIOUS_CUBE) cycle
  ! corner detection here
    if(iMPIcut_xi(1,ispec) .and. iMPIcut_eta(1,ispec)) then
      ispeccount=ispeccount+1
      ! loop on all the points
      ix = 1
      iy = 1
      do iz=1,NGLLZ
        ! select point, if not already selected
        if(.not. mask_ibool(ibool(ix,iy,iz,ispec))) then
            mask_ibool(ibool(ix,iy,iz,ispec)) = .true.
            npoin1D = npoin1D + 1
            if (PERFORM_CUTHILL_MCKEE) then
              ibool_selected(npoin1D) = ibool(ix,iy,iz,ispec)
              xstore_selected(npoin1D) = xstore(ix,iy,iz,ispec)
              ystore_selected(npoin1D) = ystore(ix,iy,iz,ispec)
              zstore_selected(npoin1D) = zstore(ix,iy,iz,ispec)
            else
              write(10,*) ibool(ispec), xstore(ispec), &
                    ystore(ispec),zstore(ispec)
            endif
        endif
      enddo
    endif
  enddo

  if (PERFORM_CUTHILL_MCKEE) then
    call sort_array_coordinates(npoin1D,xstore_selected,ystore_selected,zstore_selected, &
            ibool_selected,iglob,locval,ifseg,nglob,ind,ninseg,iwork,work)
  
    do ipoin1D=1,npoin1D
        write(10,*) ibool_selected(ipoin1D), xstore_selected(ipoin1D), &
                    ystore_selected(ipoin1D),zstore_selected(ipoin1D)
    enddo
  endif
! put flag to indicate end of the list of points
  write(10,*) '0  0  0.  0.  0.'

! write total number of points
  write(10,*) npoin1D

  close(10)

! compare number of edge elements detected to analytical value
  if(ispeccount /= NSPEC1D_RADIAL_CORNER(iregion,1) .or. npoin1D /= NGLOB1D_RADIAL_CORNER(iregion,1)) &
    call exit_MPI(myrank,'error MPI 1D buffer detection in xi=left')

! determine if the element falls on the right MPI cut plane

! global point number and coordinates right MPI 1D buffer
  open(unit=10,file=prname(1:len_trim(prname))//'ibool1D_rightxi_lefteta.txt',status='unknown')

! erase the logical mask used to mark points already found
  mask_ibool(:) = .false.

! nb of global points shared with the other slice
  npoin1D = 0

! nb of elements in this 1D buffer
  ispeccount=0
  do ispec=1,nspec
    ! remove central cube for chunk buffers
    if(idoubling(ispec) == IFLAG_MIDDLE_CENTRAL_CUBE .or. &
      idoubling(ispec) == IFLAG_BOTTOM_CENTRAL_CUBE .or. &
      idoubling(ispec) == IFLAG_TOP_CENTRAL_CUBE .or. &
      idoubling(ispec) == IFLAG_IN_FICTITIOUS_CUBE) cycle
  ! corner detection here
    if(iMPIcut_xi(2,ispec) .and. iMPIcut_eta(1,ispec)) then
      ispeccount=ispeccount+1
      ! loop on all the points
      ix = NGLLX
      iy = 1
      do iz=1,NGLLZ
        ! select point, if not already selected
        if(.not. mask_ibool(ibool(ix,iy,iz,ispec))) then
            mask_ibool(ibool(ix,iy,iz,ispec)) = .true.
            npoin1D = npoin1D + 1
            if (PERFORM_CUTHILL_MCKEE) then
              ibool_selected(npoin1D) = ibool(ix,iy,iz,ispec)
              xstore_selected(npoin1D) = xstore(ix,iy,iz,ispec)
              ystore_selected(npoin1D) = ystore(ix,iy,iz,ispec)
              zstore_selected(npoin1D) = zstore(ix,iy,iz,ispec)
            else
              write(10,*) ibool(ispec), xstore(ispec), &
                    ystore(ispec),zstore(ispec)
            endif
        endif
      enddo
    endif
  enddo

  if (PERFORM_CUTHILL_MCKEE) then
    call sort_array_coordinates(npoin1D,xstore_selected,ystore_selected,zstore_selected, &
            ibool_selected,iglob,locval,ifseg,nglob,ind,ninseg,iwork,work)
  
    do ipoin1D=1,npoin1D
        write(10,*) ibool_selected(ipoin1D), xstore_selected(ipoin1D), &
                    ystore_selected(ipoin1D),zstore_selected(ipoin1D)
    enddo
  endif

! put flag to indicate end of the list of points
  write(10,*) '0  0  0.  0.  0.'

! write total number of points
  write(10,*) npoin1D

  close(10)

! compare number of edge elements and points detected to analytical value
  if(ispeccount /= NSPEC1D_RADIAL_CORNER(iregion,2) .or. npoin1D /= NGLOB1D_RADIAL_CORNER(iregion,2)) &
    call exit_MPI(myrank,'error MPI 1D buffer detection in xi=right')

! *****************************************************************
! ****************** generate for eta = eta_max *******************
! *****************************************************************

! determine if the element falls on the left MPI cut plane

! global point number and coordinates left MPI 1D buffer
  open(unit=10,file=prname(1:len_trim(prname))//'ibool1D_leftxi_righteta.txt',status='unknown')

! erase the logical mask used to mark points already found
  mask_ibool(:) = .false.

! nb of global points shared with the other slice
  npoin1D = 0

! nb of elements in this 1D buffer
  ispeccount=0

  do ispec=1,nspec

! remove central cube for chunk buffers
  if(idoubling(ispec) == IFLAG_MIDDLE_CENTRAL_CUBE .or. &
     idoubling(ispec) == IFLAG_BOTTOM_CENTRAL_CUBE .or. &
     idoubling(ispec) == IFLAG_TOP_CENTRAL_CUBE .or. &
     idoubling(ispec) == IFLAG_IN_FICTITIOUS_CUBE) cycle

! corner detection here
  if(iMPIcut_xi(1,ispec) .and. iMPIcut_eta(2,ispec)) then

    ispeccount=ispeccount+1

! loop on all the points
  ix = 1
  iy = NGLLY
  do iz=1,NGLLZ

        ! select point, if not already selected
        if(.not. mask_ibool(ibool(ix,iy,iz,ispec))) then
            mask_ibool(ibool(ix,iy,iz,ispec)) = .true.
            npoin1D = npoin1D + 1
            if (PERFORM_CUTHILL_MCKEE) then
              ibool_selected(npoin1D) = ibool(ix,iy,iz,ispec)
              xstore_selected(npoin1D) = xstore(ix,iy,iz,ispec)
              ystore_selected(npoin1D) = ystore(ix,iy,iz,ispec)
              zstore_selected(npoin1D) = zstore(ix,iy,iz,ispec)
            else
              write(10,*) ibool(ispec), xstore(ispec), &
                    ystore(ispec),zstore(ispec)
            endif
        endif
      enddo
    endif
  enddo

  if (PERFORM_CUTHILL_MCKEE) then
    call sort_array_coordinates(npoin1D,xstore_selected,ystore_selected,zstore_selected, &
            ibool_selected,iglob,locval,ifseg,nglob,ind,ninseg,iwork,work)
  
    do ipoin1D=1,npoin1D
        write(10,*) ibool_selected(ipoin1D), xstore_selected(ipoin1D), &
                    ystore_selected(ipoin1D),zstore_selected(ipoin1D)
    enddo
  endif

! put flag to indicate end of the list of points
  write(10,*) '0  0  0.  0.  0.'

! write total number of points
  write(10,*) npoin1D

  close(10)

! compare number of edge elements detected to analytical value
  if(ispeccount /= NSPEC1D_RADIAL_CORNER(iregion,4) .or. npoin1D /= NGLOB1D_RADIAL_CORNER(iregion,4)) &
    call exit_MPI(myrank,'error MPI 1D buffer detection in xi=left')

! determine if the element falls on the right MPI cut plane

! global point number and coordinates right MPI 1D buffer
  open(unit=10,file=prname(1:len_trim(prname))//'ibool1D_rightxi_righteta.txt',status='unknown')

! erase the logical mask used to mark points already found
  mask_ibool(:) = .false.

! nb of global points shared with the other slice
  npoin1D = 0

! nb of elements in this 1D buffer
  ispeccount=0

  do ispec=1,nspec

! remove central cube for chunk buffers
  if(idoubling(ispec) == IFLAG_MIDDLE_CENTRAL_CUBE .or. &
     idoubling(ispec) == IFLAG_BOTTOM_CENTRAL_CUBE .or. &
     idoubling(ispec) == IFLAG_TOP_CENTRAL_CUBE .or. &
     idoubling(ispec) == IFLAG_IN_FICTITIOUS_CUBE) cycle

! corner detection here
  if(iMPIcut_xi(2,ispec) .and. iMPIcut_eta(2,ispec)) then

    ispeccount=ispeccount+1

! loop on all the points
  ix = NGLLX
  iy = NGLLY
  do iz=1,NGLLZ

        ! select point, if not already selected
        if(.not. mask_ibool(ibool(ix,iy,iz,ispec))) then
            mask_ibool(ibool(ix,iy,iz,ispec)) = .true.
            npoin1D = npoin1D + 1
            if (PERFORM_CUTHILL_MCKEE) then
              ibool_selected(npoin1D) = ibool(ix,iy,iz,ispec)
              xstore_selected(npoin1D) = xstore(ix,iy,iz,ispec)
              ystore_selected(npoin1D) = ystore(ix,iy,iz,ispec)
              zstore_selected(npoin1D) = zstore(ix,iy,iz,ispec)
            else
              write(10,*) ibool(ispec), xstore(ispec), &
                    ystore(ispec),zstore(ispec)
            endif
        endif
      enddo
    endif
  enddo

  if (PERFORM_CUTHILL_MCKEE) then
    call sort_array_coordinates(npoin1D,xstore_selected,ystore_selected,zstore_selected, &
            ibool_selected,iglob,locval,ifseg,nglob,ind,ninseg,iwork,work)
  
    do ipoin1D=1,npoin1D
        write(10,*) ibool_selected(ipoin1D), xstore_selected(ipoin1D), &
                    ystore_selected(ipoin1D),zstore_selected(ipoin1D)
    enddo
  endif

! put flag to indicate end of the list of points
  write(10,*) '0  0  0.  0.  0.'

! write total number of points
  write(10,*) npoin1D

  close(10)

! compare number of edge elements and points detected to analytical value
  if(ispeccount /= NSPEC1D_RADIAL_CORNER(iregion,3) .or. npoin1D /= NGLOB1D_RADIAL_CORNER(iregion,3)) &
    call exit_MPI(myrank,'error MPI 1D buffer detection in xi=right')

  if (PERFORM_CUTHILL_MCKEE) then
    deallocate(ibool_selected)
    deallocate(xstore_selected)
    deallocate(ystore_selected)
    deallocate(zstore_selected)
    deallocate(ind)
    deallocate(ninseg)
    deallocate(iglob)
    deallocate(locval)
    deallocate(ifseg)
    deallocate(iwork)
    deallocate(work)
  endif

  end subroutine get_MPI_1D_buffers

