!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  5 . 1
!          --------------------------------------------------
!
!          Main authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!             and University of Pau / CNRS / INRIA, France
! (c) Princeton University / California Institute of Technology and University of Pau / CNRS / INRIA
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

module create_MPI_interfaces_par

  use constants,only: CUSTOM_REAL,NUMFACES_SHARED,NB_SQUARE_EDGES_ONEDIR,NDIM,IMAIN
  
  ! indirect addressing for each message for faces and corners of the chunks
  ! a given slice can belong to at most one corner and at most two faces
  integer :: NGLOB2DMAX_XY

  ! number of faces between chunks
  integer :: NUMMSGS_FACES

  ! number of corners between chunks
  integer :: NCORNERSCHUNKS

  ! number of message types
  integer :: NUM_MSG_TYPES

  integer :: NGLOB1D_RADIAL_CM 
  integer :: NGLOB1D_RADIAL_OC
  integer :: NGLOB1D_RADIAL_IC

  integer :: NGLOB2DMAX_XMIN_XMAX_CM
  integer :: NGLOB2DMAX_XMIN_XMAX_OC
  integer :: NGLOB2DMAX_XMIN_XMAX_IC

  integer :: NGLOB2DMAX_YMIN_YMAX_CM
  integer :: NGLOB2DMAX_YMIN_YMAX_OC
  integer :: NGLOB2DMAX_YMIN_YMAX_IC

  integer :: NSPEC2DMAX_XMIN_XMAX_CM
  integer :: NSPEC2DMAX_YMIN_YMAX_CM
  integer :: NSPEC2D_BOTTOM_CM
  integer :: NSPEC2D_TOP_CM

  integer :: NSPEC2DMAX_XMIN_XMAX_IC
  integer :: NSPEC2DMAX_YMIN_YMAX_IC
  integer :: NSPEC2D_BOTTOM_IC
  integer :: NSPEC2D_TOP_IC

  integer :: NSPEC2DMAX_XMIN_XMAX_OC
  integer :: NSPEC2DMAX_YMIN_YMAX_OC
  integer :: NSPEC2D_BOTTOM_OC
  integer :: NSPEC2D_TOP_OC

  integer :: NSPEC_CRUST_MANTLE
  integer :: NSPEC_INNER_CORE
  integer :: NSPEC_OUTER_CORE

  integer :: NGLOB_CRUST_MANTLE
  integer :: NGLOB_INNER_CORE
  integer :: NGLOB_OUTER_CORE
  
  !-----------------------------------------------------------------
  ! assembly
  !-----------------------------------------------------------------

  ! ---- arrays to assemble between chunks
  ! communication pattern for faces between chunks
  integer, dimension(:),allocatable :: iprocfrom_faces,iprocto_faces,imsg_type
  ! communication pattern for corners between chunks
  integer, dimension(:),allocatable :: iproc_master_corners,iproc_worker1_corners,iproc_worker2_corners

  ! this for non blocking MPI

  ! buffers for send and receive between faces of the slices and the chunks
  ! we use the same buffers to assemble scalars and vectors because vectors are
  ! always three times bigger and therefore scalars can use the first part
  ! of the vector buffer in memory even if it has an additional index here
  integer :: npoin2D_max_all_CM_IC
  real(kind=CUSTOM_REAL), dimension(:,:,:), allocatable :: buffer_send_faces,buffer_received_faces

  ! buffers for send and receive between corners of the chunks
  real(kind=CUSTOM_REAL), dimension(:),allocatable :: &
    buffer_send_chunkcorn_scalar,buffer_recv_chunkcorn_scalar

  ! size of buffers is the sum of two sizes because we handle two regions in the same MPI call
  real(kind=CUSTOM_REAL), dimension(:,:),allocatable :: &
     buffer_send_chunkcorn_vector,buffer_recv_chunkcorn_vector


  ! collected MPI interfaces
  ! MPI crust/mantle mesh
  integer :: num_interfaces_crust_mantle
  integer :: max_nibool_interfaces_crust_mantle
  integer, dimension(:), allocatable :: my_neighbours_crust_mantle,nibool_interfaces_crust_mantle
  integer, dimension(:,:), allocatable :: ibool_interfaces_crust_mantle

  real(kind=CUSTOM_REAL), dimension(:,:,:), allocatable :: buffer_send_vector_crust_mantle,buffer_recv_vector_crust_mantle

  integer, dimension(:), allocatable :: request_send_vector_crust_mantle,request_recv_vector_crust_mantle

  ! MPI inner core mesh
  integer :: num_interfaces_inner_core
  integer :: max_nibool_interfaces_inner_core
  integer, dimension(:), allocatable :: my_neighbours_inner_core,nibool_interfaces_inner_core
  integer, dimension(:,:), allocatable :: ibool_interfaces_inner_core

  real(kind=CUSTOM_REAL), dimension(:,:,:), allocatable :: buffer_send_vector_inner_core,buffer_recv_vector_inner_core

  integer, dimension(:), allocatable :: request_send_vector_inner_core,request_recv_vector_inner_core

  ! MPI outer core mesh
  integer :: num_interfaces_outer_core
  integer :: max_nibool_interfaces_outer_core
  integer, dimension(:), allocatable :: my_neighbours_outer_core,nibool_interfaces_outer_core
  integer, dimension(:,:), allocatable :: ibool_interfaces_outer_core

  real(kind=CUSTOM_REAL), dimension(:,:), allocatable :: buffer_send_scalar_outer_core,buffer_recv_scalar_outer_core

  integer, dimension(:), allocatable :: request_send_scalar_outer_core,request_recv_scalar_outer_core

  ! temporary arrays for elements on slices or edges
  logical, dimension(:),allocatable :: is_on_a_slice_edge_crust_mantle, &
    is_on_a_slice_edge_inner_core,is_on_a_slice_edge_outer_core

  logical, dimension(:),allocatable :: mask_ibool

  !--------------------------------------
  ! crust mantle
  !--------------------------------------
  real(kind=CUSTOM_REAL), dimension(:),allocatable :: &
    xstore_crust_mantle,ystore_crust_mantle,zstore_crust_mantle
  integer, dimension(:),allocatable :: idoubling_crust_mantle
  integer, dimension(:,:,:,:),allocatable :: ibool_crust_mantle

  ! assembly
  integer :: npoin2D_faces_crust_mantle(NUMFACES_SHARED)
  integer, dimension(NB_SQUARE_EDGES_ONEDIR) :: npoin2D_xi_crust_mantle,npoin2D_eta_crust_mantle

  ! indirect addressing for each corner of the chunks
  integer, dimension(:,:),allocatable :: iboolcorner_crust_mantle

  ! 2-D addressing and buffers for summation between slices
  integer, dimension(:),allocatable :: iboolleft_xi_crust_mantle,iboolright_xi_crust_mantle
  integer, dimension(:),allocatable :: iboolleft_eta_crust_mantle,iboolright_eta_crust_mantle

  integer, dimension(:,:),allocatable :: iboolfaces_crust_mantle

  ! inner / outer elements crust/mantle region
  integer :: num_phase_ispec_crust_mantle
  integer :: nspec_inner_crust_mantle,nspec_outer_crust_mantle
  integer, dimension(:,:), allocatable :: phase_ispec_inner_crust_mantle

  ! mesh coloring
  integer :: num_colors_outer_crust_mantle,num_colors_inner_crust_mantle
  integer,dimension(:),allocatable :: num_elem_colors_crust_mantle

  !--------------------------------------
  ! outer core
  !--------------------------------------
  real(kind=CUSTOM_REAL), dimension(:),allocatable :: &
    xstore_outer_core,ystore_outer_core,zstore_outer_core
  integer, dimension(:),allocatable :: idoubling_outer_core
  integer, dimension(:,:,:,:),allocatable :: ibool_outer_core
  
  ! assembly
  integer :: npoin2D_faces_outer_core(NUMFACES_SHARED)
  integer, dimension(NB_SQUARE_EDGES_ONEDIR) :: npoin2D_xi_outer_core,npoin2D_eta_outer_core

  ! indirect addressing for each corner of the chunks
  integer, dimension(:,:),allocatable :: iboolcorner_outer_core

  ! 2-D addressing and buffers for summation between slices
  integer, dimension(:),allocatable :: iboolleft_xi_outer_core,iboolright_xi_outer_core
  integer, dimension(:),allocatable :: iboolleft_eta_outer_core,iboolright_eta_outer_core

  integer, dimension(:,:),allocatable :: iboolfaces_outer_core

  ! inner / outer elements outer core region
  integer :: num_phase_ispec_outer_core
  integer :: nspec_inner_outer_core,nspec_outer_outer_core
  integer, dimension(:,:), allocatable :: phase_ispec_inner_outer_core

  ! mesh coloring
  integer :: num_colors_outer_outer_core,num_colors_inner_outer_core
  integer,dimension(:),allocatable :: num_elem_colors_outer_core


  !--------------------------------------
  ! inner core
  !--------------------------------------

  real(kind=CUSTOM_REAL), dimension(:),allocatable :: &
    xstore_inner_core,ystore_inner_core,zstore_inner_core
  integer, dimension(:),allocatable :: idoubling_inner_core
  integer, dimension(:,:,:,:),allocatable :: ibool_inner_core


  ! for matching with central cube in inner core
  integer, dimension(:), allocatable :: sender_from_slices_to_cube
  integer, dimension(:,:), allocatable :: ibool_central_cube
  double precision, dimension(:,:), allocatable :: buffer_slices,buffer_slices2
  double precision, dimension(:,:,:), allocatable :: buffer_all_cube_from_slices
  integer nb_msgs_theor_in_cube,non_zero_nb_msgs_theor_in_cube,npoin2D_cube_from_slices,receiver_cube_from_slices

  integer :: nspec2D_xmin_inner_core,nspec2D_xmax_inner_core, &
            nspec2D_ymin_inner_core,nspec2D_ymax_inner_core

  integer, dimension(:),allocatable :: ibelm_xmin_inner_core,ibelm_xmax_inner_core
  integer, dimension(:),allocatable :: ibelm_ymin_inner_core,ibelm_ymax_inner_core
  integer, dimension(:),allocatable :: ibelm_bottom_inner_core
  integer, dimension(:),allocatable :: ibelm_top_inner_core

  integer :: npoin2D_faces_inner_core(NUMFACES_SHARED)
  integer, dimension(NB_SQUARE_EDGES_ONEDIR) :: npoin2D_xi_inner_core,npoin2D_eta_inner_core

  ! indirect addressing for each corner of the chunks
  integer, dimension(:,:),allocatable :: iboolcorner_inner_core

  ! 2-D addressing and buffers for summation between slices
  integer, dimension(:),allocatable :: iboolleft_xi_inner_core,iboolright_xi_inner_core
  integer, dimension(:),allocatable :: iboolleft_eta_inner_core,iboolright_eta_inner_core

  integer, dimension(:,:),allocatable :: iboolfaces_inner_core

  ! inner / outer elements inner core region
  integer :: num_phase_ispec_inner_core
  integer :: nspec_inner_inner_core,nspec_outer_inner_core
  integer, dimension(:,:), allocatable :: phase_ispec_inner_inner_core

  ! mesh coloring
  integer :: num_colors_outer_inner_core,num_colors_inner_inner_core
  integer,dimension(:),allocatable :: num_elem_colors_inner_core
  
end module create_MPI_interfaces_par

!
!-------------------------------------------------------------------------------------------------
!

  subroutine create_MPI_interfaces()

  use meshfem3D_par
  use create_MPI_interfaces_par
  implicit none
  
  ! sets up arrays
  call cmi_read_addressing()

  ! reads "iboolleft_..txt", "iboolright_..txt" (and "list_messages_..txt", "buffer_...txt") files and sets up MPI buffers
  call cmi_read_buffers()

  ! sets up MPI interfaces
  call cmi_setup_MPIinterfaces()

  ! sets up inner/outer element arrays
  call cmi_setup_InnerOuter()

  ! sets up mesh coloring
  call cmi_setup_color_perm()
  
  ! saves interface infos
  call cmi_save_interfaces()
    
  ! frees memory
  call cmi_free_arrays()

  end subroutine create_MPI_interfaces
  
!
!-------------------------------------------------------------------------------------------------
!

  subroutine cmi_read_addressing()

  use meshfem3D_par
  use create_MPI_interfaces_par
  implicit none

  ! local parameters
  integer :: NUM_FACES,NPROC_ONE_DIRECTION
  integer :: ier
  
  ! define maximum size for message buffers
  ! use number of elements found in the mantle since it is the largest region
  NGLOB2DMAX_XY = max(NGLOB2DMAX_XMIN_XMAX(IREGION_CRUST_MANTLE),NGLOB2DMAX_YMIN_YMAX(IREGION_CRUST_MANTLE))

  ! number of corners and faces shared between chunks and number of message types
  if(NCHUNKS == 1 .or. NCHUNKS == 2) then
    NCORNERSCHUNKS = 1
    NUM_FACES = 1
    NUM_MSG_TYPES = 1
  else if(NCHUNKS == 3) then
    NCORNERSCHUNKS = 1
    NUM_FACES = 1
    NUM_MSG_TYPES = 3
  else if(NCHUNKS == 6) then
    NCORNERSCHUNKS = 8
    NUM_FACES = 4
    NUM_MSG_TYPES = 3
  else
    call exit_MPI(myrank,'number of chunks must be either 1, 2, 3 or 6')
  endif
  ! if more than one chunk then same number of processors in each direction
  NPROC_ONE_DIRECTION = NPROC_XI
  ! total number of messages corresponding to these common faces
  NUMMSGS_FACES = NPROC_ONE_DIRECTION*NUM_FACES*NUM_MSG_TYPES


  allocate(iprocfrom_faces(NUMMSGS_FACES), &
          iprocto_faces(NUMMSGS_FACES), &
          imsg_type(NUMMSGS_FACES),stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating iproc faces arrays')
  
  ! communication pattern for corners between chunks
  allocate(iproc_master_corners(NCORNERSCHUNKS), &
          iproc_worker1_corners(NCORNERSCHUNKS), &
          iproc_worker2_corners(NCORNERSCHUNKS),stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating iproc corner arrays')
  

  ! parameters from header file
  NGLOB1D_RADIAL_CM = NGLOB1D_RADIAL(IREGION_CRUST_MANTLE)
  NGLOB1D_RADIAL_OC = NGLOB1D_RADIAL(IREGION_OUTER_CORE)
  NGLOB1D_RADIAL_IC = NGLOB1D_RADIAL(IREGION_INNER_CORE)

  NGLOB2DMAX_XMIN_XMAX_CM = NGLOB2DMAX_XMIN_XMAX(IREGION_CRUST_MANTLE)
  NGLOB2DMAX_XMIN_XMAX_OC = NGLOB2DMAX_XMIN_XMAX(IREGION_OUTER_CORE)
  NGLOB2DMAX_XMIN_XMAX_IC = NGLOB2DMAX_XMIN_XMAX(IREGION_INNER_CORE)

  NGLOB2DMAX_YMIN_YMAX_CM = NGLOB2DMAX_YMIN_YMAX(IREGION_CRUST_MANTLE)
  NGLOB2DMAX_YMIN_YMAX_OC = NGLOB2DMAX_YMIN_YMAX(IREGION_OUTER_CORE)
  NGLOB2DMAX_YMIN_YMAX_IC = NGLOB2DMAX_YMIN_YMAX(IREGION_INNER_CORE)

  NSPEC2DMAX_XMIN_XMAX_CM = NSPEC2DMAX_XMIN_XMAX(IREGION_CRUST_MANTLE)
  NSPEC2DMAX_YMIN_YMAX_CM = NSPEC2DMAX_YMIN_YMAX(IREGION_CRUST_MANTLE)
  NSPEC2D_BOTTOM_CM = NSPEC2D_BOTTOM(IREGION_CRUST_MANTLE)
  NSPEC2D_TOP_CM = NSPEC2D_TOP(IREGION_CRUST_MANTLE)

  NSPEC2DMAX_XMIN_XMAX_IC = NSPEC2DMAX_XMIN_XMAX(IREGION_INNER_CORE)
  NSPEC2DMAX_YMIN_YMAX_IC = NSPEC2DMAX_YMIN_YMAX(IREGION_INNER_CORE)
  NSPEC2D_BOTTOM_IC = NSPEC2D_BOTTOM(IREGION_INNER_CORE)
  NSPEC2D_TOP_IC = NSPEC2D_TOP(IREGION_INNER_CORE)

  NSPEC2DMAX_XMIN_XMAX_OC = NSPEC2DMAX_XMIN_XMAX(IREGION_OUTER_CORE)
  NSPEC2DMAX_YMIN_YMAX_OC = NSPEC2DMAX_YMIN_YMAX(IREGION_OUTER_CORE)
  NSPEC2D_BOTTOM_OC = NSPEC2D_BOTTOM(IREGION_OUTER_CORE)
  NSPEC2D_TOP_OC = NSPEC2D_TOP(IREGION_OUTER_CORE)

  NSPEC_CRUST_MANTLE = NSPEC(IREGION_CRUST_MANTLE)
  NSPEC_INNER_CORE = NSPEC(IREGION_INNER_CORE)
  NSPEC_OUTER_CORE = NSPEC(IREGION_OUTER_CORE)

  NGLOB_CRUST_MANTLE = NGLOB(IREGION_CRUST_MANTLE)
  NGLOB_INNER_CORE = NGLOB(IREGION_INNER_CORE)
  NGLOB_OUTER_CORE = NGLOB(IREGION_OUTER_CORE)

  ! allocates arrays

  allocate(buffer_send_chunkcorn_scalar(NGLOB1D_RADIAL_CM), &
          buffer_recv_chunkcorn_scalar(NGLOB1D_RADIAL_CM))

  allocate(buffer_send_chunkcorn_vector(NDIM,NGLOB1D_RADIAL_CM + NGLOB1D_RADIAL_IC), &
          buffer_recv_chunkcorn_vector(NDIM,NGLOB1D_RADIAL_CM + NGLOB1D_RADIAL_IC))

  ! crust mantle
  allocate(iboolcorner_crust_mantle(NGLOB1D_RADIAL_CM,NUMCORNERS_SHARED))
  allocate(iboolleft_xi_crust_mantle(NGLOB2DMAX_XMIN_XMAX_CM), &
          iboolright_xi_crust_mantle(NGLOB2DMAX_XMIN_XMAX_CM))          
  allocate(iboolleft_eta_crust_mantle(NGLOB2DMAX_YMIN_YMAX_CM), &
          iboolright_eta_crust_mantle(NGLOB2DMAX_YMIN_YMAX_CM))
  allocate(iboolfaces_crust_mantle(NGLOB2DMAX_XY,NUMFACES_SHARED))

  ! outer core
  allocate(iboolcorner_outer_core(NGLOB1D_RADIAL_OC,NUMCORNERS_SHARED))
  allocate(iboolleft_xi_outer_core(NGLOB2DMAX_XMIN_XMAX_OC), &
          iboolright_xi_outer_core(NGLOB2DMAX_XMIN_XMAX_OC))
  allocate(iboolleft_eta_outer_core(NGLOB2DMAX_YMIN_YMAX_OC), &
          iboolright_eta_outer_core(NGLOB2DMAX_YMIN_YMAX_OC))
  allocate(iboolfaces_outer_core(NGLOB2DMAX_XY,NUMFACES_SHARED))

  ! inner core
  allocate(ibelm_xmin_inner_core(NSPEC2DMAX_XMIN_XMAX_IC), &
          ibelm_xmax_inner_core(NSPEC2DMAX_XMIN_XMAX_IC))
  allocate(ibelm_ymin_inner_core(NSPEC2DMAX_YMIN_YMAX_IC), &
          ibelm_ymax_inner_core(NSPEC2DMAX_YMIN_YMAX_IC))
  allocate(ibelm_bottom_inner_core(NSPEC2D_BOTTOM_IC))
  allocate(ibelm_top_inner_core(NSPEC2D_TOP_IC))


  allocate(iboolcorner_inner_core(NGLOB1D_RADIAL_IC,NUMCORNERS_SHARED))
  allocate(iboolleft_xi_inner_core(NGLOB2DMAX_XMIN_XMAX_IC), &
          iboolright_xi_inner_core(NGLOB2DMAX_XMIN_XMAX_IC))
  allocate(iboolleft_eta_inner_core(NGLOB2DMAX_YMIN_YMAX_IC), &
          iboolright_eta_inner_core(NGLOB2DMAX_YMIN_YMAX_IC))
  allocate(iboolfaces_inner_core(NGLOB2DMAX_XY,NUMFACES_SHARED))


  ! crust mantle
  allocate(xstore_crust_mantle(NGLOB_CRUST_MANTLE), &
          ystore_crust_mantle(NGLOB_CRUST_MANTLE), &
          zstore_crust_mantle(NGLOB_CRUST_MANTLE))
  allocate(idoubling_crust_mantle(NSPEC_CRUST_MANTLE))
  allocate(ibool_crust_mantle(NGLLX,NGLLY,NGLLZ,NSPEC_CRUST_MANTLE), &
           stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating temporary crust mantle arrays')

  ! outer core
  allocate(xstore_outer_core(NGLOB_OUTER_CORE), &
          ystore_outer_core(NGLOB_OUTER_CORE), &
          zstore_outer_core(NGLOB_OUTER_CORE))
  allocate(idoubling_outer_core(NSPEC_OUTER_CORE))
  allocate(ibool_outer_core(NGLLX,NGLLY,NGLLZ,NSPEC_OUTER_CORE), &
           stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating temporary outer core arrays')

  ! inner core
  allocate(xstore_inner_core(NGLOB_INNER_CORE), &
          ystore_inner_core(NGLOB_INNER_CORE), &
          zstore_inner_core(NGLOB_INNER_CORE))
  allocate(idoubling_inner_core(NSPEC_INNER_CORE))
  allocate(ibool_inner_core(NGLLX,NGLLY,NGLLZ,NSPEC_INNER_CORE), &
           stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating temporary inner core arrays')

  ! allocates temporary arrays
  allocate(mask_ibool(NGLOB_CRUST_MANTLE))
  allocate( is_on_a_slice_edge_crust_mantle(NSPEC_CRUST_MANTLE), &
           is_on_a_slice_edge_inner_core(NSPEC_INNER_CORE), &
           is_on_a_slice_edge_outer_core(NSPEC_OUTER_CORE), &
           stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating temporary is_on_a_slice_edge arrays')
          
  
  ! read coordinates of the mesh
  ! crust mantle
  ibool_crust_mantle(:,:,:,:) = -1
  call cmi_read_solver_data(myrank,IREGION_CRUST_MANTLE, &
                           NSPEC_CRUST_MANTLE,NGLOB_CRUST_MANTLE, &
                           xstore_crust_mantle,ystore_crust_mantle,zstore_crust_mantle,&
                           ibool_crust_mantle,idoubling_crust_mantle, &
                           is_on_a_slice_edge_crust_mantle, &
                           LOCAL_PATH)

  ! check that the number of points in this slice is correct
  if(minval(ibool_crust_mantle(:,:,:,:)) /= 1 .or. &
    maxval(ibool_crust_mantle(:,:,:,:)) /= NGLOB_CRUST_MANTLE) &
      call exit_MPI(myrank,'incorrect global numbering: iboolmax does not equal nglob in crust and mantle')

  ! outer core
  ibool_outer_core(:,:,:,:) = -1  
  call cmi_read_solver_data(myrank,IREGION_OUTER_CORE, &
                           NSPEC_OUTER_CORE,NGLOB_OUTER_CORE, &
                           xstore_outer_core,ystore_outer_core,zstore_outer_core,&
                           ibool_outer_core,idoubling_outer_core, &
                           is_on_a_slice_edge_outer_core, &
                           LOCAL_PATH)

  ! check that the number of points in this slice is correct
  if(minval(ibool_outer_core(:,:,:,:)) /= 1 .or. &
     maxval(ibool_outer_core(:,:,:,:)) /= NGLOB_OUTER_CORE) &
    call exit_MPI(myrank,'incorrect global numbering: iboolmax does not equal nglob in outer core')

  ! inner core
  ibool_inner_core(:,:,:,:) = -1  
  call cmi_read_solver_data(myrank,IREGION_INNER_CORE, &
                           NSPEC_INNER_CORE,NGLOB_INNER_CORE, &
                           xstore_inner_core,ystore_inner_core,zstore_inner_core,&
                           ibool_inner_core,idoubling_inner_core, &
                           is_on_a_slice_edge_inner_core, &
                           LOCAL_PATH)

  ! check that the number of points in this slice is correct
  if(minval(ibool_inner_core(:,:,:,:)) /= 1 .or. maxval(ibool_inner_core(:,:,:,:)) /= NGLOB_INNER_CORE) &
    call exit_MPI(myrank,'incorrect global numbering: iboolmax does not equal nglob in inner core')

  ! synchronize processes
  call sync_all()
  
  end subroutine cmi_read_addressing  

!
!-------------------------------------------------------------------------------------------------
!

  subroutine cmi_read_buffers()

  use meshfem3D_par
  use create_MPI_interfaces_par
  implicit none

  ! local parameters
  integer :: ier
  integer njunk1,njunk2
  character(len=150) prname
  ! debug
  logical,parameter :: DEBUG_FLAGS = .false.
  character(len=150) :: filename

  ! read 2-D addressing for summation between slices with MPI

  ! mantle and crust
  if(myrank == 0) then
    write(IMAIN,*) 
    write(IMAIN,*) 'crust/mantle region:'
  endif

  call read_arrays_buffers_mesher(IREGION_CRUST_MANTLE,myrank,iboolleft_xi_crust_mantle, &
             iboolright_xi_crust_mantle,iboolleft_eta_crust_mantle,iboolright_eta_crust_mantle, &
             npoin2D_xi_crust_mantle,npoin2D_eta_crust_mantle, &
             iprocfrom_faces,iprocto_faces,imsg_type, &
             iproc_master_corners,iproc_worker1_corners,iproc_worker2_corners, &
             iboolfaces_crust_mantle,npoin2D_faces_crust_mantle, &
             iboolcorner_crust_mantle, &
             NGLOB2DMAX_XMIN_XMAX(IREGION_CRUST_MANTLE), &
             NGLOB2DMAX_YMIN_YMAX(IREGION_CRUST_MANTLE),NGLOB2DMAX_XY,NGLOB1D_RADIAL(IREGION_CRUST_MANTLE), &
             NUMMSGS_FACES,NCORNERSCHUNKS,NPROCTOT,NPROC_XI,NPROC_ETA,LOCAL_PATH,NCHUNKS)

  ! outer core
  if(myrank == 0) write(IMAIN,*) 'outer core region:'

  call read_arrays_buffers_mesher(IREGION_OUTER_CORE,myrank, &
             iboolleft_xi_outer_core,iboolright_xi_outer_core,iboolleft_eta_outer_core,iboolright_eta_outer_core, &
             npoin2D_xi_outer_core,npoin2D_eta_outer_core, &
             iprocfrom_faces,iprocto_faces,imsg_type, &
             iproc_master_corners,iproc_worker1_corners,iproc_worker2_corners, &
             iboolfaces_outer_core,npoin2D_faces_outer_core, &
             iboolcorner_outer_core, &
             NGLOB2DMAX_XMIN_XMAX(IREGION_OUTER_CORE), &
             NGLOB2DMAX_YMIN_YMAX(IREGION_OUTER_CORE),NGLOB2DMAX_XY,NGLOB1D_RADIAL(IREGION_OUTER_CORE), &
             NUMMSGS_FACES,NCORNERSCHUNKS,NPROCTOT,NPROC_XI,NPROC_ETA,LOCAL_PATH,NCHUNKS)

  ! inner core
  if(myrank == 0) write(IMAIN,*) 'inner core region:'

  call read_arrays_buffers_mesher(IREGION_INNER_CORE,myrank, &
             iboolleft_xi_inner_core,iboolright_xi_inner_core,iboolleft_eta_inner_core,iboolright_eta_inner_core, &
             npoin2D_xi_inner_core,npoin2D_eta_inner_core, &
             iprocfrom_faces,iprocto_faces,imsg_type, &
             iproc_master_corners,iproc_worker1_corners,iproc_worker2_corners, &
             iboolfaces_inner_core,npoin2D_faces_inner_core, &
             iboolcorner_inner_core, &
             NGLOB2DMAX_XMIN_XMAX(IREGION_INNER_CORE), &
             NGLOB2DMAX_YMIN_YMAX(IREGION_INNER_CORE),NGLOB2DMAX_XY,NGLOB1D_RADIAL(IREGION_INNER_CORE), &
             NUMMSGS_FACES,NCORNERSCHUNKS,NPROCTOT,NPROC_XI,NPROC_ETA,LOCAL_PATH,NCHUNKS)

  ! synchronizes processes
  call sync_all()

  ! read coupling arrays for inner core
  ! create name of database
  call create_name_database(prname,myrank,IREGION_INNER_CORE,LOCAL_PATH)

  ! read info for vertical edges for central cube matching in inner core
  open(unit=IIN,file=prname(1:len_trim(prname))//'boundary.bin', &
        status='old',form='unformatted',action='read',iostat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error opening boundary.bin file')
  
  read(IIN) nspec2D_xmin_inner_core
  read(IIN) nspec2D_xmax_inner_core
  read(IIN) nspec2D_ymin_inner_core
  read(IIN) nspec2D_ymax_inner_core
  read(IIN) njunk1
  read(IIN) njunk2

  ! boundary parameters
  read(IIN) ibelm_xmin_inner_core
  read(IIN) ibelm_xmax_inner_core
  read(IIN) ibelm_ymin_inner_core
  read(IIN) ibelm_ymax_inner_core
  read(IIN) ibelm_bottom_inner_core
  read(IIN) ibelm_top_inner_core
  close(IIN)


  ! added this to reduce the size of the buffers
  ! size of buffers is the sum of two sizes because we handle two regions in the same MPI call
  npoin2D_max_all_CM_IC = max(maxval(npoin2D_xi_crust_mantle(:) + npoin2D_xi_inner_core(:)), &
                        maxval(npoin2D_eta_crust_mantle(:) + npoin2D_eta_inner_core(:)))

  allocate(buffer_send_faces(NDIM,npoin2D_max_all_CM_IC,NUMFACES_SHARED), &
          buffer_received_faces(NDIM,npoin2D_max_all_CM_IC,NUMFACES_SHARED),stat=ier)
  if( ier /= 0 ) call exit_MPI(myrank,'error allocating mpi buffer')

  ! central cube buffers
  if(INCLUDE_CENTRAL_CUBE) then

    if(myrank == 0) then
      write(IMAIN,*)
      write(IMAIN,*) 'including central cube'
    endif
    call sync_all()
    
    ! compute number of messages to expect in cube as well as their size
    call comp_central_cube_buffer_size(iproc_xi,iproc_eta,ichunk, &
                NPROC_XI,NPROC_ETA,NSPEC2D_BOTTOM(IREGION_INNER_CORE), &
                nb_msgs_theor_in_cube,npoin2D_cube_from_slices)

    ! this value is used for dynamic memory allocation, therefore make sure it is never zero
    if(nb_msgs_theor_in_cube > 0) then
      non_zero_nb_msgs_theor_in_cube = nb_msgs_theor_in_cube
    else
      non_zero_nb_msgs_theor_in_cube = 1
    endif

    ! allocate buffers for cube and slices
    allocate(sender_from_slices_to_cube(non_zero_nb_msgs_theor_in_cube), &
            buffer_all_cube_from_slices(non_zero_nb_msgs_theor_in_cube,npoin2D_cube_from_slices,NDIM), &
            buffer_slices(npoin2D_cube_from_slices,NDIM), &
            buffer_slices2(npoin2D_cube_from_slices,NDIM), &
            ibool_central_cube(non_zero_nb_msgs_theor_in_cube,npoin2D_cube_from_slices),stat=ier)
    if( ier /= 0 ) call exit_MPI(myrank,'error allocating cube buffers')

    ! handles the communications with the central cube if it was included in the mesh
    ! create buffers to assemble with the central cube
    call create_central_cube_buffers(myrank,iproc_xi,iproc_eta,ichunk, &
               NPROC_XI,NPROC_ETA,NCHUNKS, &
               NSPEC_INNER_CORE,NGLOB_INNER_CORE, &
               NSPEC2DMAX_XMIN_XMAX(IREGION_INNER_CORE),NSPEC2DMAX_YMIN_YMAX(IREGION_INNER_CORE), &
               NSPEC2D_BOTTOM(IREGION_INNER_CORE), &
               addressing,ibool_inner_core,idoubling_inner_core, &
               xstore_inner_core,ystore_inner_core,zstore_inner_core, &
               nspec2D_xmin_inner_core,nspec2D_xmax_inner_core, &
               nspec2D_ymin_inner_core,nspec2D_ymax_inner_core, &
               ibelm_xmin_inner_core,ibelm_xmax_inner_core, &
               ibelm_ymin_inner_core,ibelm_ymax_inner_core,ibelm_bottom_inner_core, &
               nb_msgs_theor_in_cube,non_zero_nb_msgs_theor_in_cube,npoin2D_cube_from_slices, &
               receiver_cube_from_slices,sender_from_slices_to_cube,ibool_central_cube, &
               buffer_slices,buffer_slices2,buffer_all_cube_from_slices)

    if(myrank == 0) write(IMAIN,*) ''

  else

    ! allocate fictitious buffers for cube and slices with a dummy size
    ! just to be able to use them as arguments in subroutine calls
    allocate(sender_from_slices_to_cube(1), &
            buffer_all_cube_from_slices(1,1,1), &
            buffer_slices(1,1), &
            buffer_slices2(1,1), &
            ibool_central_cube(1,1),stat=ier)
    if( ier /= 0 ) call exit_MPI(myrank,'error allocating dummy buffers')

  endif

  ! note: fix_... routines below update is_on_a_slice_edge_.. arrays:
  !          assign flags for each element which is on a rim of the slice
  !          thus, they include elements on top and bottom not shared with other MPI partitions
  !
  !          we will re-set these flags when setting up inner/outer elements, but will
  !          use these arrays for now as initial guess for the search for elements which share a global point
  !          between different MPI processes
  call fix_non_blocking_slices(is_on_a_slice_edge_crust_mantle,iboolright_xi_crust_mantle, &
         iboolleft_xi_crust_mantle,iboolright_eta_crust_mantle,iboolleft_eta_crust_mantle, &
         npoin2D_xi_crust_mantle,npoin2D_eta_crust_mantle,ibool_crust_mantle, &
         mask_ibool,NSPEC_CRUST_MANTLE,NGLOB_CRUST_MANTLE,NGLOB2DMAX_XMIN_XMAX_CM,NGLOB2DMAX_YMIN_YMAX_CM)

  call fix_non_blocking_slices(is_on_a_slice_edge_outer_core,iboolright_xi_outer_core, &
         iboolleft_xi_outer_core,iboolright_eta_outer_core,iboolleft_eta_outer_core, &
         npoin2D_xi_outer_core,npoin2D_eta_outer_core,ibool_outer_core, &
         mask_ibool,NSPEC_OUTER_CORE,NGLOB_OUTER_CORE,NGLOB2DMAX_XMIN_XMAX_OC,NGLOB2DMAX_YMIN_YMAX_OC)

  call fix_non_blocking_slices(is_on_a_slice_edge_inner_core,iboolright_xi_inner_core, &
         iboolleft_xi_inner_core,iboolright_eta_inner_core,iboolleft_eta_inner_core, &
         npoin2D_xi_inner_core,npoin2D_eta_inner_core,ibool_inner_core, &
         mask_ibool,NSPEC_INNER_CORE,NGLOB_INNER_CORE,NGLOB2DMAX_XMIN_XMAX_IC,NGLOB2DMAX_YMIN_YMAX_IC)

  if(INCLUDE_CENTRAL_CUBE) then
    ! updates flags for elements on slice boundaries
    call fix_non_blocking_central_cube(is_on_a_slice_edge_inner_core, &
         ibool_inner_core,NSPEC_INNER_CORE,NGLOB_INNER_CORE,nb_msgs_theor_in_cube,ibelm_bottom_inner_core, &
         idoubling_inner_core,npoin2D_cube_from_slices, &
         ibool_central_cube,NSPEC2D_BOTTOM(IREGION_INNER_CORE), &
         ichunk,NPROC_XI)
  endif

  ! debug: saves element flags
  if( DEBUG_FLAGS ) then
    ! crust mantle
    write(filename,'(a,i6.6)') trim(OUTPUT_FILES)//'/MPI_is_on_a_slice_edge_crust_mantle_proc',myrank
    call write_VTK_data_elem_l(NSPEC_CRUST_MANTLE,NGLOB_CRUST_MANTLE, &
                              xstore_crust_mantle,ystore_crust_mantle,zstore_crust_mantle, &
                              ibool_crust_mantle, &
                              is_on_a_slice_edge_crust_mantle,filename)
    ! outer core
    write(filename,'(a,i6.6)') trim(OUTPUT_FILES)//'/MPI_is_on_a_slice_edge_outer_core_proc',myrank
    call write_VTK_data_elem_l(NSPEC_OUTER_CORE,NGLOB_OUTER_CORE, &
                              xstore_outer_core,ystore_outer_core,zstore_outer_core, &
                              ibool_outer_core, &
                              is_on_a_slice_edge_outer_core,filename)
    ! inner core
    write(filename,'(a,i6.6)') trim(OUTPUT_FILES)//'/MPI_is_on_a_slice_edge_inner_core_proc',myrank
    call write_VTK_data_elem_l(NSPEC_INNER_CORE,NGLOB_INNER_CORE, &
                              xstore_inner_core,ystore_inner_core,zstore_inner_core, &
                              ibool_inner_core, &
                              is_on_a_slice_edge_inner_core,filename)
  endif

  end subroutine cmi_read_buffers

!
!-------------------------------------------------------------------------------------------------
!

  subroutine cmi_setup_MPIinterfaces()

  use meshfem3D_par
  use create_MPI_interfaces_par
  implicit none

  include 'mpif.h'

  ! local parameters
  integer :: ier,ndim_assemble

  ! temporary buffers for send and receive between faces of the slices and the chunks
  real(kind=CUSTOM_REAL), dimension(npoin2D_max_all_CM_IC) ::  &
    buffer_send_faces_scalar,buffer_received_faces_scalar

  ! assigns initial maximum arrays
  ! for global slices, maximum number of neighbor is around 17 ( 8 horizontal, max of 8 on bottom )
  integer :: MAX_NEIGHBOURS
  integer, dimension(:),allocatable :: my_neighbours,nibool_neighbours
  integer, dimension(:,:),allocatable :: ibool_neighbours
  integer :: max_nibool
  real(kind=CUSTOM_REAL),dimension(:),allocatable :: test_flag
  integer,dimension(:),allocatable :: dummy_i
  integer :: i,j,k,ispec,iglob
  ! debug
  character(len=150) :: filename
  logical,parameter :: DEBUG_INTERFACES = .false.

  ! estimates a maximum size of needed arrays
  MAX_NEIGHBOURS = 8 + NCORNERSCHUNKS  
  allocate(my_neighbours(MAX_NEIGHBOURS), &
          nibool_neighbours(MAX_NEIGHBOURS),stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating my_neighbours array')
  
  ! estimates initial maximum ibool array
  max_nibool = npoin2D_max_all_CM_IC * NUMFACES_SHARED &
               + non_zero_nb_msgs_theor_in_cube*npoin2D_cube_from_slices

  allocate(ibool_neighbours(max_nibool,MAX_NEIGHBOURS), stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating ibool_neighbours')


! sets up MPI interfaces
! crust mantle region
  if( myrank == 0 ) write(IMAIN,*) 'crust mantle mpi:'
  allocate(test_flag(NGLOB_CRUST_MANTLE), &
          stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating test_flag')

  ! sets flag to rank id (+1 to avoid problems with zero rank)
  test_flag(:) = myrank + 1.0

  ! assembles values
  call assemble_MPI_scalar_block(myrank,test_flag, &
            NGLOB_CRUST_MANTLE, &
            iproc_xi,iproc_eta,ichunk,addressing, &
            iboolleft_xi_crust_mantle,iboolright_xi_crust_mantle,iboolleft_eta_crust_mantle,iboolright_eta_crust_mantle, &
            npoin2D_faces_crust_mantle,npoin2D_xi_crust_mantle,npoin2D_eta_crust_mantle, &
            iboolfaces_crust_mantle,iboolcorner_crust_mantle, &
            iprocfrom_faces,iprocto_faces,imsg_type, &
            iproc_master_corners,iproc_worker1_corners,iproc_worker2_corners, &
            buffer_send_faces_scalar,buffer_received_faces_scalar,npoin2D_max_all_CM_IC, &
            buffer_send_chunkcorn_scalar,buffer_recv_chunkcorn_scalar, &
            NUMMSGS_FACES,NUM_MSG_TYPES,NCORNERSCHUNKS, &
            NPROC_XI,NPROC_ETA,NGLOB1D_RADIAL(IREGION_CRUST_MANTLE), &
            NGLOB2DMAX_XMIN_XMAX(IREGION_CRUST_MANTLE),NGLOB2DMAX_YMIN_YMAX(IREGION_CRUST_MANTLE),NGLOB2DMAX_XY,NCHUNKS)

  ! removes own myrank id (+1)
  test_flag(:) = test_flag(:) - ( myrank + 1.0)

  ! debug: saves array
  !write(filename,'(a,i6.6)') trim(OUTPUT_FILES)//'/MPI_test_flag_crust_mantle_proc',myrank
  !call write_VTK_glob_points(NGLOB_CRUST_MANTLE, &
  !                      xstore_crust_mantle,ystore_crust_mantle,zstore_crust_mantle, &
  !                      test_flag,filename)

  allocate(dummy_i(NSPEC_CRUST_MANTLE),stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating dummy_i')

  ! determines neighbor rank for shared faces
  call get_MPI_interfaces(myrank,NGLOB_CRUST_MANTLE,NSPEC_CRUST_MANTLE, &
                            test_flag,my_neighbours,nibool_neighbours,ibool_neighbours, &
                            num_interfaces_crust_mantle,max_nibool_interfaces_crust_mantle, &
                            max_nibool,MAX_NEIGHBOURS, &
                            ibool_crust_mantle,&
                            is_on_a_slice_edge_crust_mantle, &
                            IREGION_CRUST_MANTLE,.false.,dummy_i,INCLUDE_CENTRAL_CUBE, &
                            xstore_crust_mantle,ystore_crust_mantle,zstore_crust_mantle,NPROCTOT)

  deallocate(test_flag)
  deallocate(dummy_i)

  ! stores MPI interfaces informations
  allocate(my_neighbours_crust_mantle(num_interfaces_crust_mantle), &
          nibool_interfaces_crust_mantle(num_interfaces_crust_mantle), &
          stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating array my_neighbours_crust_mantle etc.')
  my_neighbours_crust_mantle = -1
  nibool_interfaces_crust_mantle = 0

  ! copies interfaces arrays
  if( num_interfaces_crust_mantle > 0 ) then
    allocate(ibool_interfaces_crust_mantle(max_nibool_interfaces_crust_mantle,num_interfaces_crust_mantle), &
           stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating array ibool_interfaces_crust_mantle')
    ibool_interfaces_crust_mantle = 0

    ! ranks of neighbour processes
    my_neighbours_crust_mantle(:) = my_neighbours(1:num_interfaces_crust_mantle)
    ! number of global ibool entries on each interface
    nibool_interfaces_crust_mantle(:) = nibool_neighbours(1:num_interfaces_crust_mantle)
    ! global iglob point ids on each interface
    ibool_interfaces_crust_mantle(:,:) = ibool_neighbours(1:max_nibool_interfaces_crust_mantle,1:num_interfaces_crust_mantle)
  else
    ! dummy allocation (fortran90 should allow allocate statement with zero array size)
    max_nibool_interfaces_crust_mantle = 0
    allocate(ibool_interfaces_crust_mantle(0,0),stat=ier)
  endif

  ! debug: outputs MPI interface
  if( DEBUG_INTERFACES ) then
  do i=1,num_interfaces_crust_mantle
    write(filename,'(a,i6.6,a,i2.2)') trim(OUTPUT_FILES)//'/MPI_points_crust_mantle_proc',myrank, &
                    '_',my_neighbours_crust_mantle(i)
    call write_VTK_data_points(NGLOB_crust_mantle, &
                      xstore_crust_mantle,ystore_crust_mantle,zstore_crust_mantle, &
                      ibool_interfaces_crust_mantle(1:nibool_interfaces_crust_mantle(i),i), &
                      nibool_interfaces_crust_mantle(i),filename)
  enddo
  call sync_all()
  endif

  ! checks addressing
  call test_MPI_neighbours(IREGION_CRUST_MANTLE, &
                              num_interfaces_crust_mantle,max_nibool_interfaces_crust_mantle, &
                              my_neighbours_crust_mantle,nibool_interfaces_crust_mantle, &
                              ibool_interfaces_crust_mantle)

  ! allocates MPI buffers
  ! crust mantle
  allocate(buffer_send_vector_crust_mantle(NDIM,max_nibool_interfaces_crust_mantle,num_interfaces_crust_mantle), &
          buffer_recv_vector_crust_mantle(NDIM,max_nibool_interfaces_crust_mantle,num_interfaces_crust_mantle), &
          request_send_vector_crust_mantle(num_interfaces_crust_mantle), &
          request_recv_vector_crust_mantle(num_interfaces_crust_mantle), &
          stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating array buffer_send_vector_crust_mantle etc.')

  ! checks with assembly of test fields
  call test_MPI_cm()


! outer core region
  if( myrank == 0 ) write(IMAIN,*) 'outer core mpi:'

  allocate(test_flag(NGLOB_OUTER_CORE), &
          stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating test_flag outer core')

  ! sets flag to rank id (+1 to avoid problems with zero rank)
  test_flag(:) = myrank + 1.0

  ! assembles values
  call assemble_MPI_scalar_block(myrank,test_flag, &
            NGLOB_OUTER_CORE, &
            iproc_xi,iproc_eta,ichunk,addressing, &
            iboolleft_xi_outer_core,iboolright_xi_outer_core,iboolleft_eta_outer_core,iboolright_eta_outer_core, &
            npoin2D_faces_outer_core,npoin2D_xi_outer_core,npoin2D_eta_outer_core, &
            iboolfaces_outer_core,iboolcorner_outer_core, &
            iprocfrom_faces,iprocto_faces,imsg_type, &
            iproc_master_corners,iproc_worker1_corners,iproc_worker2_corners, &
            buffer_send_faces_scalar,buffer_received_faces_scalar,npoin2D_max_all_CM_IC, &
            buffer_send_chunkcorn_scalar,buffer_recv_chunkcorn_scalar, &
            NUMMSGS_FACES,NUM_MSG_TYPES,NCORNERSCHUNKS, &
            NPROC_XI,NPROC_ETA,NGLOB1D_RADIAL(IREGION_OUTER_CORE), &
            NGLOB2DMAX_XMIN_XMAX(IREGION_OUTER_CORE),NGLOB2DMAX_YMIN_YMAX(IREGION_OUTER_CORE),NGLOB2DMAX_XY,NCHUNKS)


  ! removes own myrank id (+1)
  test_flag(:) = test_flag(:) - ( myrank + 1.0)

  ! debug: saves array
  !write(filename,'(a,i6.6)') trim(OUTPUT_FILES)//'/MPI_test_flag_outer_core_proc',myrank
  !call write_VTK_glob_points(NGLOB_OUTER_CORE, &
  !                      xstore_outer_core,ystore_outer_core,zstore_outer_core, &
  !                      test_flag,filename)

  allocate(dummy_i(NSPEC_OUTER_CORE),stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating dummy_i')

  ! determines neighbor rank for shared faces
  call get_MPI_interfaces(myrank,NGLOB_OUTER_CORE,NSPEC_OUTER_CORE, &
                            test_flag,my_neighbours,nibool_neighbours,ibool_neighbours, &
                            num_interfaces_outer_core,max_nibool_interfaces_outer_core, &
                            max_nibool,MAX_NEIGHBOURS, &
                            ibool_outer_core,&
                            is_on_a_slice_edge_outer_core, &
                            IREGION_OUTER_CORE,.false.,dummy_i,INCLUDE_CENTRAL_CUBE, &
                            xstore_outer_core,ystore_outer_core,zstore_outer_core,NPROCTOT)

  deallocate(test_flag)
  deallocate(dummy_i)

  ! stores MPI interfaces informations
  allocate(my_neighbours_outer_core(num_interfaces_outer_core), &
          nibool_interfaces_outer_core(num_interfaces_outer_core), &
          stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating array my_neighbours_outer_core etc.')
  my_neighbours_outer_core = -1
  nibool_interfaces_outer_core = 0

  ! copies interfaces arrays
  if( num_interfaces_outer_core > 0 ) then
    allocate(ibool_interfaces_outer_core(max_nibool_interfaces_outer_core,num_interfaces_outer_core), &
           stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating array ibool_interfaces_outer_core')
    ibool_interfaces_outer_core = 0

    ! ranks of neighbour processes
    my_neighbours_outer_core(:) = my_neighbours(1:num_interfaces_outer_core)
    ! number of global ibool entries on each interface
    nibool_interfaces_outer_core(:) = nibool_neighbours(1:num_interfaces_outer_core)
    ! global iglob point ids on each interface
    ibool_interfaces_outer_core(:,:) = ibool_neighbours(1:max_nibool_interfaces_outer_core,1:num_interfaces_outer_core)
  else
    ! dummy allocation (fortran90 should allow allocate statement with zero array size)
    max_nibool_interfaces_outer_core = 0
    allocate(ibool_interfaces_outer_core(0,0),stat=ier)
  endif

  ! debug: outputs MPI interface
  if( DEBUG_INTERFACES ) then
  do i=1,num_interfaces_outer_core
    write(filename,'(a,i6.6,a,i2.2)') trim(OUTPUT_FILES)//'/MPI_points_outer_core_proc',myrank, &
                    '_',my_neighbours_outer_core(i)
    call write_VTK_data_points(NGLOB_OUTER_CORE, &
                      xstore_outer_core,ystore_outer_core,zstore_outer_core, &
                      ibool_interfaces_outer_core(1:nibool_interfaces_outer_core(i),i), &
                      nibool_interfaces_outer_core(i),filename)
  enddo
  call sync_all()
  endif
  
  ! checks addressing
  call test_MPI_neighbours(IREGION_OUTER_CORE, &
                              num_interfaces_outer_core,max_nibool_interfaces_outer_core, &
                              my_neighbours_outer_core,nibool_interfaces_outer_core, &
                              ibool_interfaces_outer_core)

  ! allocates MPI buffers
  ! outer core
  allocate(buffer_send_scalar_outer_core(max_nibool_interfaces_outer_core,num_interfaces_outer_core), &
          buffer_recv_scalar_outer_core(max_nibool_interfaces_outer_core,num_interfaces_outer_core), &
          request_send_scalar_outer_core(num_interfaces_outer_core), &
          request_recv_scalar_outer_core(num_interfaces_outer_core), &
          stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating array buffer_send_vector_outer_core etc.')

  ! checks with assembly of test fields
  call test_MPI_oc()


! inner core
  if( myrank == 0 ) write(IMAIN,*) 'inner core mpi:'

  allocate(test_flag(NGLOB_INNER_CORE), &
          stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating test_flag inner core')

  ! sets flag to rank id (+1 to avoid problems with zero rank)
  test_flag(:) = 0.0
  do ispec=1,NSPEC_INNER_CORE
    ! suppress fictitious elements in central cube
    if(idoubling_inner_core(ispec) == IFLAG_IN_FICTITIOUS_CUBE) cycle
    ! sets flags
    do k = 1,NGLLZ
      do j = 1,NGLLY
        do i = 1,NGLLX
          iglob = ibool_inner_core(i,j,k,ispec)
          test_flag(iglob) = myrank + 1.0
        enddo
      enddo
    enddo
  enddo

  ! assembles values
  call assemble_MPI_scalar_block(myrank,test_flag, &
            NGLOB_INNER_CORE, &
            iproc_xi,iproc_eta,ichunk,addressing, &
            iboolleft_xi_inner_core,iboolright_xi_inner_core,iboolleft_eta_inner_core,iboolright_eta_inner_core, &
            npoin2D_faces_inner_core,npoin2D_xi_inner_core,npoin2D_eta_inner_core, &
            iboolfaces_inner_core,iboolcorner_inner_core, &
            iprocfrom_faces,iprocto_faces,imsg_type, &
            iproc_master_corners,iproc_worker1_corners,iproc_worker2_corners, &
            buffer_send_faces_scalar,buffer_received_faces_scalar,npoin2D_max_all_CM_IC, &
            buffer_send_chunkcorn_scalar,buffer_recv_chunkcorn_scalar, &
            NUMMSGS_FACES,NUM_MSG_TYPES,NCORNERSCHUNKS, &
            NPROC_XI,NPROC_ETA,NGLOB1D_RADIAL(IREGION_INNER_CORE), &
            NGLOB2DMAX_XMIN_XMAX(IREGION_INNER_CORE),NGLOB2DMAX_YMIN_YMAX(IREGION_INNER_CORE),NGLOB2DMAX_XY,NCHUNKS)

  ! debug: saves array
  !write(filename,'(a,i6.6)') trim(OUTPUT_FILES)//'/MPI_test_flag_inner_core_A_proc',myrank
  !call write_VTK_glob_points(NGLOB_INNER_CORE, &
  !                      xstore_inner_core,ystore_inner_core,zstore_inner_core, &
  !                      test_flag,filename)
  
  ! debug: idoubling inner core
  if( DEBUG_INTERFACES ) then
    write(filename,'(a,i6.6)') trim(OUTPUT_FILES)//'/MPI_idoubling_inner_core_proc',myrank
    call write_VTK_data_elem_i(NSPEC_INNER_CORE,NGLOB_INNER_CORE, &
                            xstore_inner_core,ystore_inner_core,zstore_inner_core, &
                            ibool_inner_core, &
                            idoubling_inner_core,filename)
    call sync_all()
  endif
  
  ! including central cube
  if(INCLUDE_CENTRAL_CUBE) then
    ! user output
    if( myrank == 0 ) write(IMAIN,*) 'inner core with central cube mpi:'

    ! test_flag is a scalar, not a vector
    ndim_assemble = 1

    ! use central cube buffers to assemble the inner core mass matrix with the central cube
    call assemble_MPI_central_cube_block(ichunk,nb_msgs_theor_in_cube, sender_from_slices_to_cube, &
                 npoin2D_cube_from_slices, buffer_all_cube_from_slices, &
                 buffer_slices, buffer_slices2, ibool_central_cube, &
                 receiver_cube_from_slices, ibool_inner_core, &
                 idoubling_inner_core, NSPEC_INNER_CORE, &
                 ibelm_bottom_inner_core, NSPEC2D_BOTTOM(IREGION_INNER_CORE), &
                 NGLOB_INNER_CORE, &
                 test_flag,ndim_assemble, &
                 iproc_eta,addressing,NCHUNKS,NPROC_XI,NPROC_ETA)
  endif

  ! removes own myrank id (+1)
  test_flag = test_flag - ( myrank + 1.0)
  where( test_flag < 0.0 ) test_flag = 0.0

  ! debug: saves array
  !write(filename,'(a,i6.6)') trim(OUTPUT_FILES)//'/MPI_test_flag_inner_core_B_proc',myrank
  !call write_VTK_glob_points(NGLOB_INNER_CORE, &
  !                    xstore_inner_core,ystore_inner_core,zstore_inner_core, &
  !                    test_flag,filename)
  !call sync_all()

  ! in sequential order, for testing purpose
  do i=0,NPROCTOT - 1
    if( myrank == i ) then
      ! gets new interfaces for inner_core without central cube yet
      ! determines neighbor rank for shared faces
      call get_MPI_interfaces(myrank,NGLOB_INNER_CORE,NSPEC_INNER_CORE, &
                            test_flag,my_neighbours,nibool_neighbours,ibool_neighbours, &
                            num_interfaces_inner_core,max_nibool_interfaces_inner_core, &
                            max_nibool,MAX_NEIGHBOURS, &
                            ibool_inner_core,&
                            is_on_a_slice_edge_inner_core, &
                            IREGION_INNER_CORE,.false.,idoubling_inner_core,INCLUDE_CENTRAL_CUBE, &
                            xstore_inner_core,ystore_inner_core,zstore_inner_core,NPROCTOT)

    endif
    call sync_all()
  enddo


  deallocate(test_flag)
  call sync_all()

  ! stores MPI interfaces informations
  allocate(my_neighbours_inner_core(num_interfaces_inner_core), &
          nibool_interfaces_inner_core(num_interfaces_inner_core), &
          stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating array my_neighbours_inner_core etc.')
  my_neighbours_inner_core = -1
  nibool_interfaces_inner_core = 0

  ! copies interfaces arrays
  if( num_interfaces_inner_core > 0 ) then
    allocate(ibool_interfaces_inner_core(max_nibool_interfaces_inner_core,num_interfaces_inner_core), &
           stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating array ibool_interfaces_inner_core')
    ibool_interfaces_inner_core = 0

    ! ranks of neighbour processes
    my_neighbours_inner_core(:) = my_neighbours(1:num_interfaces_inner_core)
    ! number of global ibool entries on each interface
    nibool_interfaces_inner_core(:) = nibool_neighbours(1:num_interfaces_inner_core)
    ! global iglob point ids on each interface
    ibool_interfaces_inner_core(:,:) = ibool_neighbours(1:max_nibool_interfaces_inner_core,1:num_interfaces_inner_core)
  else
    ! dummy allocation (fortran90 should allow allocate statement with zero array size)
    max_nibool_interfaces_inner_core = 0
    allocate(ibool_interfaces_inner_core(0,0),stat=ier)
  endif

  ! debug: saves MPI interfaces
  if( DEBUG_INTERFACES ) then
  do i=1,num_interfaces_inner_core
    write(filename,'(a,i6.6,a,i2.2)') trim(OUTPUT_FILES)//'/MPI_points_inner_core_proc',myrank, &
                    '_',my_neighbours_inner_core(i)
    call write_VTK_data_points(NGLOB_INNER_CORE, &
                      xstore_inner_core,ystore_inner_core,zstore_inner_core, &
                      ibool_interfaces_inner_core(1:nibool_interfaces_inner_core(i),i), &
                      nibool_interfaces_inner_core(i),filename)
  enddo
  call sync_all()
  endif
  
  ! checks addressing
  call test_MPI_neighbours(IREGION_INNER_CORE, &
                              num_interfaces_inner_core,max_nibool_interfaces_inner_core, &
                              my_neighbours_inner_core,nibool_interfaces_inner_core, &
                              ibool_interfaces_inner_core)

  ! allocates MPI buffers
  ! inner core
  allocate(buffer_send_vector_inner_core(NDIM,max_nibool_interfaces_inner_core,num_interfaces_inner_core), &
          buffer_recv_vector_inner_core(NDIM,max_nibool_interfaces_inner_core,num_interfaces_inner_core), &
          request_send_vector_inner_core(num_interfaces_inner_core), &
          request_recv_vector_inner_core(num_interfaces_inner_core), &
          stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating array buffer_send_vector_inner_core etc.')

  ! checks with assembly of test fields
  call test_MPI_ic()

  ! synchronizes MPI processes
  call sync_all()

  ! frees temporary array
  deallocate(ibool_neighbours)
  deallocate(my_neighbours,nibool_neighbours)

  end subroutine cmi_setup_MPIinterfaces

!
!-------------------------------------------------------------------------------------------------
!

  subroutine cmi_setup_InnerOuter()
  
  use meshfem3D_par
  use create_MPI_interfaces_par
  implicit none

  ! local parameters
  real :: percentage_edge
  integer :: ier,ispec,iinner,iouter
  ! debug  
  character(len=150) :: filename
  logical,parameter :: DEBUG_INTERFACES = .false.
  
  ! stores inner / outer elements
  !
  ! note: arrays is_on_a_slice_edge_.. have flags set for elements which need to
  !         communicate with other MPI processes

  ! crust_mantle
  nspec_outer_crust_mantle = count( is_on_a_slice_edge_crust_mantle )
  nspec_inner_crust_mantle = NSPEC_CRUST_MANTLE - nspec_outer_crust_mantle

  num_phase_ispec_crust_mantle = max(nspec_inner_crust_mantle,nspec_outer_crust_mantle)

  allocate(phase_ispec_inner_crust_mantle(num_phase_ispec_crust_mantle,2),stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating array phase_ispec_inner_crust_mantle')

  phase_ispec_inner_crust_mantle(:,:) = 0
  iinner = 0
  iouter = 0
  do ispec=1,NSPEC_CRUST_MANTLE
    if( is_on_a_slice_edge_crust_mantle(ispec) ) then
      ! outer element
      iouter = iouter + 1
      phase_ispec_inner_crust_mantle(iouter,1) = ispec
    else
      ! inner element
      iinner = iinner + 1
      phase_ispec_inner_crust_mantle(iinner,2) = ispec
    endif
  enddo

  ! outer_core
  nspec_outer_outer_core = count( is_on_a_slice_edge_outer_core )
  nspec_inner_outer_core = NSPEC_OUTER_CORE - nspec_outer_outer_core

  num_phase_ispec_outer_core = max(nspec_inner_outer_core,nspec_outer_outer_core)

  allocate(phase_ispec_inner_outer_core(num_phase_ispec_outer_core,2),stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating array phase_ispec_inner_outer_core')

  phase_ispec_inner_outer_core(:,:) = 0
  iinner = 0
  iouter = 0
  do ispec=1,NSPEC_OUTER_CORE
    if( is_on_a_slice_edge_outer_core(ispec) ) then
      ! outer element
      iouter = iouter + 1
      phase_ispec_inner_outer_core(iouter,1) = ispec
    else
      ! inner element
      iinner = iinner + 1
      phase_ispec_inner_outer_core(iinner,2) = ispec
    endif
  enddo

  ! inner_core
  nspec_outer_inner_core = count( is_on_a_slice_edge_inner_core )
  nspec_inner_inner_core = NSPEC_INNER_CORE - nspec_outer_inner_core

  num_phase_ispec_inner_core = max(nspec_inner_inner_core,nspec_outer_inner_core)

  allocate(phase_ispec_inner_inner_core(num_phase_ispec_inner_core,2),stat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error allocating array phase_ispec_inner_inner_core')

  phase_ispec_inner_inner_core(:,:) = 0
  iinner = 0
  iouter = 0
  do ispec=1,NSPEC_INNER_CORE
    if( is_on_a_slice_edge_inner_core(ispec) ) then
      ! outer element
      iouter = iouter + 1
      phase_ispec_inner_inner_core(iouter,1) = ispec
    else
      ! inner element
      iinner = iinner + 1
      phase_ispec_inner_inner_core(iinner,2) = ispec
    endif
  enddo

  ! user output
  if(myrank == 0) then

    write(IMAIN,*)
    write(IMAIN,*) 'for overlapping of communications with calculations:'
    write(IMAIN,*)

    percentage_edge = 100. * nspec_outer_crust_mantle / real(NSPEC_CRUST_MANTLE)
    write(IMAIN,*) 'percentage of edge elements in crust/mantle ',percentage_edge,'%'
    write(IMAIN,*) 'percentage of volume elements in crust/mantle ',100. - percentage_edge,'%'
    write(IMAIN,*)

    percentage_edge = 100.* nspec_outer_outer_core / real(NSPEC_OUTER_CORE)
    write(IMAIN,*) 'percentage of edge elements in outer core ',percentage_edge,'%'
    write(IMAIN,*) 'percentage of volume elements in outer core ',100. - percentage_edge,'%'
    write(IMAIN,*)

    percentage_edge = 100. * nspec_outer_inner_core / real(NSPEC_INNER_CORE)
    write(IMAIN,*) 'percentage of edge elements in inner core ',percentage_edge,'%'
    write(IMAIN,*) 'percentage of volume elements in inner core ',100. - percentage_edge,'%'
    write(IMAIN,*)

  endif

  ! debug: saves element flags
  if( DEBUG_INTERFACES ) then
    ! crust mantle
    write(filename,'(a,i6.6)') trim(OUTPUT_FILES)//'/MPI_innerouter_crust_mantle_proc',myrank
    call write_VTK_data_elem_l(NSPEC_CRUST_MANTLE,NGLOB_CRUST_MANTLE, &
                              xstore_crust_mantle,ystore_crust_mantle,zstore_crust_mantle, &
                              ibool_crust_mantle, &
                              is_on_a_slice_edge_crust_mantle,filename)
    ! outer core
    write(filename,'(a,i6.6)') trim(OUTPUT_FILES)//'/MPI_innerouter_outer_core_proc',myrank
    call write_VTK_data_elem_l(NSPEC_OUTER_CORE,NGLOB_OUTER_CORE, &
                              xstore_outer_core,ystore_outer_core,zstore_outer_core, &
                              ibool_outer_core, &
                              is_on_a_slice_edge_outer_core,filename)
    ! inner core
    write(filename,'(a,i6.6)') trim(OUTPUT_FILES)//'/MPI_innerouter_inner_core_proc',myrank
    call write_VTK_data_elem_l(NSPEC_INNER_CORE,NGLOB_INNER_CORE, &
                              xstore_inner_core,ystore_inner_core,zstore_inner_core, &
                              ibool_inner_core, &
                              is_on_a_slice_edge_inner_core,filename)
  endif
  
  end subroutine cmi_setup_InnerOuter


!
!-------------------------------------------------------------------------------------------------
!

  subroutine cmi_setup_color_perm()
  
  use meshfem3D_par
  use create_MPI_interfaces_par
  implicit none

  ! local parameters
  integer, dimension(:), allocatable :: perm
  integer :: ier

  ! user output
  if(myrank == 0) then
    write(IMAIN,*) 'mesh coloring: ',USE_MESH_COLORING_GPU
  endif

  ! crust mantle
  ! initializes
  num_colors_outer_crust_mantle = 0
  num_colors_inner_crust_mantle = 0

  ! mesh coloring
  if( USE_MESH_COLORING_GPU ) then

    ! user output
    if(myrank == 0) write(IMAIN,*) '  coloring crust mantle... '

    ! creates coloring of elements
    allocate(perm(NSPEC_CRUST_MANTLE),stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating temporary perm crust mantle array')
    perm(:) = 0

    allocate(num_elem_colors_crust_mantle(num_colors_outer_crust_mantle+num_colors_inner_crust_mantle),stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating num_elem_colors_crust_mantle array')

    deallocate(perm)
  else
    ! dummy array
    allocate(num_elem_colors_crust_mantle(num_colors_outer_crust_mantle+num_colors_inner_crust_mantle),stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating num_elem_colors_crust_mantle array')
  endif

  ! outer core
  ! initializes
  num_colors_outer_outer_core = 0
  num_colors_inner_outer_core = 0

  ! mesh coloring
  if( USE_MESH_COLORING_GPU ) then

    ! user output
    if(myrank == 0) write(IMAIN,*) '  coloring outer core... '

    ! creates coloring of elements
    allocate(perm(NSPEC_OUTER_CORE),stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating temporary perm outer core array')
    perm(:) = 0

    allocate(num_elem_colors_outer_core(num_colors_outer_outer_core+num_colors_inner_outer_core),stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating num_elem_colors_outer_core array')

    deallocate(perm)
  else
    ! dummy array 
    allocate(num_elem_colors_outer_core(num_colors_outer_outer_core+num_colors_inner_outer_core),stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating num_elem_colors_outer_core array')
  endif
  
  ! inner core
  ! initializes
  num_colors_outer_inner_core = 0
  num_colors_inner_inner_core = 0

  ! mesh coloring
  if( USE_MESH_COLORING_GPU ) then

    ! user output
    if(myrank == 0) write(IMAIN,*) '  coloring inner core... '

    ! creates coloring of elements
    allocate(perm(NSPEC_INNER_CORE),stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating temporary perm inner core array')
    perm(:) = 0

    allocate(num_elem_colors_inner_core(num_colors_outer_inner_core+num_colors_inner_inner_core),stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating num_elem_colors_inner_core array')

    deallocate(perm)
  else
    ! dummy array
    allocate(num_elem_colors_inner_core(num_colors_outer_inner_core+num_colors_inner_inner_core),stat=ier)
    if( ier /= 0 ) call exit_mpi(myrank,'error allocating num_elem_colors_inner_core array')
  endif
  
  end subroutine cmi_setup_color_perm
  
!
!-------------------------------------------------------------------------------------------------
!

  subroutine cmi_save_interfaces()
  
  use meshfem3D_par
  use create_MPI_interfaces_par
  implicit none

  ! crust mantle
  call cmi_save_solver_data(myrank,IREGION_CRUST_MANTLE,LOCAL_PATH, &
                           num_interfaces_crust_mantle,max_nibool_interfaces_crust_mantle, &
                           my_neighbours_crust_mantle,nibool_interfaces_crust_mantle, &
                           ibool_interfaces_crust_mantle, &
                           nspec_inner_crust_mantle,nspec_outer_crust_mantle, &
                           num_phase_ispec_crust_mantle,phase_ispec_inner_crust_mantle, &
                           num_colors_outer_crust_mantle,num_colors_inner_crust_mantle, &
                           num_elem_colors_crust_mantle)


  ! outer core
  call cmi_save_solver_data(myrank,IREGION_OUTER_CORE,LOCAL_PATH, &
                           num_interfaces_outer_core,max_nibool_interfaces_outer_core, &
                           my_neighbours_outer_core,nibool_interfaces_outer_core, &
                           ibool_interfaces_outer_core, &
                           nspec_inner_outer_core,nspec_outer_outer_core, &
                           num_phase_ispec_outer_core,phase_ispec_inner_outer_core, &
                           num_colors_outer_outer_core,num_colors_inner_outer_core, &
                           num_elem_colors_outer_core)


  ! inner core
  call cmi_save_solver_data(myrank,IREGION_INNER_CORE,LOCAL_PATH, &
                           num_interfaces_inner_core,max_nibool_interfaces_inner_core, &
                           my_neighbours_inner_core,nibool_interfaces_inner_core, &
                           ibool_interfaces_inner_core, &
                           nspec_inner_inner_core,nspec_outer_inner_core, &
                           num_phase_ispec_inner_core,phase_ispec_inner_inner_core, &
                           num_colors_outer_inner_core,num_colors_inner_inner_core, &
                           num_elem_colors_inner_core)


  end subroutine cmi_save_interfaces

  
  
!
!-------------------------------------------------------------------------------------------------
!

  subroutine cmi_free_arrays()

  use meshfem3D_par
  use create_MPI_interfaces_par
  implicit none

  ! synchronize processes
  call sync_all()

  deallocate(iprocfrom_faces,iprocto_faces,imsg_type)
  deallocate(iproc_master_corners,iproc_worker1_corners,iproc_worker2_corners)
  deallocate(buffer_send_chunkcorn_scalar,buffer_recv_chunkcorn_scalar)
  deallocate(buffer_send_chunkcorn_vector,buffer_recv_chunkcorn_vector)

  ! crust mantle
  deallocate(iboolcorner_crust_mantle)
  deallocate(iboolleft_xi_crust_mantle, &
          iboolright_xi_crust_mantle)          
  deallocate(iboolleft_eta_crust_mantle, &
          iboolright_eta_crust_mantle)
  deallocate(iboolfaces_crust_mantle)

  deallocate(phase_ispec_inner_crust_mantle)
  deallocate(num_elem_colors_crust_mantle)
  
  ! outer core
  deallocate(iboolcorner_outer_core)
  deallocate(iboolleft_xi_outer_core, &
          iboolright_xi_outer_core)
  deallocate(iboolleft_eta_outer_core, &
          iboolright_eta_outer_core)
  deallocate(iboolfaces_outer_core)

  deallocate(phase_ispec_inner_outer_core)
  deallocate(num_elem_colors_outer_core)

  ! inner core
  deallocate(ibelm_xmin_inner_core, &
          ibelm_xmax_inner_core)
  deallocate(ibelm_ymin_inner_core, &
          ibelm_ymax_inner_core)
  deallocate(ibelm_bottom_inner_core)
  deallocate(ibelm_top_inner_core)

  deallocate(iboolcorner_inner_core)
  deallocate(iboolleft_xi_inner_core, &
          iboolright_xi_inner_core)
  deallocate(iboolleft_eta_inner_core, &
          iboolright_eta_inner_core)
  deallocate(iboolfaces_inner_core)

  deallocate(xstore_crust_mantle,ystore_crust_mantle,zstore_crust_mantle)
  deallocate(idoubling_crust_mantle,ibool_crust_mantle)

  deallocate(xstore_outer_core,ystore_outer_core,zstore_outer_core)
  deallocate(idoubling_outer_core,ibool_outer_core)

  deallocate(xstore_inner_core,ystore_inner_core,zstore_inner_core)
  deallocate(idoubling_inner_core,ibool_inner_core)

  deallocate(phase_ispec_inner_inner_core)
  deallocate(num_elem_colors_inner_core)

  deallocate(mask_ibool)
  
  ! frees temporary allocated arrays
  deallocate(is_on_a_slice_edge_crust_mantle, &
            is_on_a_slice_edge_outer_core, &
            is_on_a_slice_edge_inner_core)

  end subroutine cmi_free_arrays

!
!-------------------------------------------------------------------------------------------------
!

  subroutine cmi_read_solver_data(myrank,iregion_code, &
                                  nspec,nglob, &
                                  xstore,ystore,zstore, &
                                  ibool,idoubling,is_on_a_slice_edge, &
                                  LOCAL_PATH)
  implicit none

  include "constants.h"

  integer :: iregion_code,myrank

  integer :: nspec,nglob
  
  real(kind=CUSTOM_REAL), dimension(nglob) :: xstore,ystore,zstore
  integer, dimension(NGLLX,NGLLY,NGLLZ,nspec) :: ibool
  integer, dimension(nspec) :: idoubling
  logical, dimension(nspec) :: is_on_a_slice_edge

  character(len=150) :: LOCAL_PATH
  
  ! local parameters
  character(len=150) prname
  integer :: ier
  
  ! create the name for the database of the current slide and region
  call create_name_database(prname,myrank,iregion_code,LOCAL_PATH)
  
  open(unit=IIN,file=prname(1:len_trim(prname))//'solver_data_2.bin', &
       status='old',action='read',form='unformatted',iostat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error opening solver_data_2.bin')
  
  read(IIN) xstore
  read(IIN) ystore
  read(IIN) zstore
  read(IIN) ibool
  read(IIN) idoubling
  read(IIN) is_on_a_slice_edge

  close(IIN)
  
  end subroutine cmi_read_solver_data

!
!-------------------------------------------------------------------------------------------------
!

  subroutine cmi_save_solver_data(myrank,iregion_code,LOCAL_PATH, &
                                  num_interfaces,max_nibool_interfaces, &
                                  my_neighbours,nibool_interfaces, &
                                  ibool_interfaces, &
                                  nspec_inner,nspec_outer, &
                                  num_phase_ispec,phase_ispec_inner, &
                                  num_colors_outer,num_colors_inner, &
                                  num_elem_colors)
  implicit none

  include "constants.h"

  integer :: iregion_code,myrank

  character(len=150) :: LOCAL_PATH

  ! MPI interfaces
  integer :: num_interfaces,max_nibool_interfaces
  integer, dimension(num_interfaces) :: my_neighbours
  integer, dimension(num_interfaces) :: nibool_interfaces
  integer, dimension(max_nibool_interfaces,num_interfaces) :: &
    ibool_interfaces

  ! inner/outer elements
  integer :: nspec_inner,nspec_outer
  integer :: num_phase_ispec
  integer,dimension(num_phase_ispec,2) :: phase_ispec_inner

  ! mesh coloring
  integer :: num_colors_outer,num_colors_inner
  integer, dimension(num_colors_outer + num_colors_inner) :: &
    num_elem_colors
  
  ! local parameters
  character(len=150) prname
  integer :: ier
  
  ! create the name for the database of the current slide and region
  call create_name_database(prname,myrank,iregion_code,LOCAL_PATH)
  
  open(unit=IOUT,file=prname(1:len_trim(prname))//'solver_data_mpi.bin', &
       status='unknown',action='write',form='unformatted',iostat=ier)
  if( ier /= 0 ) call exit_mpi(myrank,'error opening solver_data_mpi.bin')
  
  ! MPI interfaces
  write(IOUT) num_interfaces
  if( num_interfaces > 0 ) then
    write(IOUT) max_nibool_interfaces
    write(IOUT) my_neighbours
    write(IOUT) nibool_interfaces
    write(IOUT) ibool_interfaces
  endif

  ! inner/outer elements
  write(IOUT) nspec_inner,nspec_outer
  write(IOUT) num_phase_ispec
  if(num_phase_ispec > 0 ) write(IOUT) phase_ispec_inner

  ! mesh coloring
  if( USE_MESH_COLORING_GPU ) then
    write(IOUT) num_colors_outer,num_colors_inner
    write(IOUT) num_elem_colors
  endif

  close(IOUT)

  end subroutine cmi_save_solver_data
  
  
