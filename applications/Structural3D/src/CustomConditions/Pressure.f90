module PressureM
  use UtilitiesM

  use PointM
  use NodeM
  use NodePtrM
  use GeometryM

  use LeftHandSideM
  use ProcessInfoM

  use IntegratorPtrM
  
  use ConditionM

  use StructuralMaterialM

  implicit none

  private
  public :: PressureDT, pressure

  type, extends(ConditionDT) :: PressureDT
     integer(ikind), dimension(:), allocatable :: nodeIDList
     real(rkind)                               :: pressure
     class(StructuralMaterialDT) , pointer     :: material
   contains
     procedure, public :: init

     procedure, public :: calculateLocalSystem
     procedure, public :: calculateLHS
     procedure, public :: calculateRHS
  end type PressureDT

  interface pressure
     procedure :: constructor
  end interface pressure

contains

  type(PressureDT) function constructor(id, nodeIDList, pressure, node, geometry, material)
    implicit none
    integer(ikind)                           , intent(in) :: id
    integer(ikind)             , dimension(:), intent(in) :: nodeIDList
    real(rkind)                              , intent(in) :: pressure
    type(NodePtrDT)            , dimension(:), intent(in) :: node
    class(GeometryDT)          , pointer     , intent(in) :: geometry
    class(StructuralMaterialDT), target      , intent(in) :: material
    call constructor%init(id, nodeIDList, pressure, node, geometry, material)
  end function constructor

  subroutine init(this, id, nodeIDList, pressure, node, geometry, material)
    implicit none
    class(PressureDT)                        , intent(inout) :: this
    integer(ikind)                           , intent(in)    :: id
    integer(ikind)             , dimension(:), intent(in)    :: nodeIDList
    real(rkind)                              , intent(in)    :: pressure
    type(NodePtrDT)            , dimension(:), intent(in)    :: node
    class(GeometryDT)          , pointer     , intent(in)    :: geometry
    class(StructuralMaterialDT), pointer     , intent(in)    :: material
    this%id = id
    this%affectsLHS = .false.
    this%affectsRHS = .true.
    this%nodeIDList = nodeIDList
    this%pressure = pressure
    this%node = node
    this%geometry => geometry
    this%material => material
  end subroutine init

  subroutine calculateLocalSystem(this, processInfo, lhs, rhs)
    implicit none
    class(PressureDT)                                , intent(inout) :: this
    type(ProcessInfoDT)                              , intent(inout) :: processInfo
    type(LeftHandSideDT)                             , intent(inout) :: lhs
    real(rkind)         , dimension(:)  , allocatable, intent(inout) :: rhs
    call this%calculateRHS(processInfo, rhs)
  end subroutine calculateLocalSystem

  subroutine calculateLHS(this, processInfo, lhs)
    implicit none
    class(PressureDT)   , intent(inout) :: this
    type(ProcessInfoDT) , intent(inout) :: processInfo
    type(LeftHandSideDT), intent(inout) :: lhs
    print*, 'No LHS component in pressure condition'
  end subroutine calculateLHS
  
 subroutine calculateRHS(this, processInfo, rhs)
    implicit none
    class(PressureDT)                                   , intent(inout) :: this
    type(ProcessInfoDT)                                 , intent(inout) :: processInfo
    real(rkind)          , dimension(:)    , allocatable, intent(inout) :: rhs
    integer(ikind)                                                      :: i, j
    integer(ikind)                                                      :: nNode
    real(rkind)                                                         :: px, py, pz
    real(rkind)                                                         :: nx, ny, nz
    real(rkind)                                                         :: int1, int2, int3
    real(rkind)          , dimension(:,:,:), allocatable                :: jacobian
    real(rkind)          , dimension(:)    , allocatable                :: jacobianDet
    type(IntegratorPtrDT)                                               :: integrator
    type(NodePtrDT)      , dimension(:)    , allocatable                :: nodalPoints
    nNode = this%getnNode()
    integrator = this%getIntegrator()
    integrator%ptr => this%geometry%boundaryGeometry%integrator
    allocate(rhs(3*nNode))
    allocate(nodalPoints(nNode))
    rhs = 0._rkind
    do i = 1, nNode
       nodalPoints(i) = this%node(i)
    end do
    jacobian = this%geometry%boundaryGeometry%jacobianAtGPoints(nodalPoints)
    jacobianDet = this%geometry%boundaryGeometry%jacobianDetAtGPoints(jacobian)
    do i = 1, nNode
       int1 = 0._rkind
       int2 = 0._rkind
       int3 = 0._rkind
       do j = 1, integrator%getIntegTerms()
          nx = jacobian(j,1,2)*jacobian(j,2,3)-jacobian(j,2,2)*jacobian(j,1,3)
          ny = jacobian(j,2,1)*jacobian(j,1,3)-jacobian(j,1,1)*jacobian(j,2,3)
          nz = jacobian(j,1,1)*jacobian(j,3,2)-jacobian(j,2,1)*jacobian(j,1,2)
          px = this%pressure*nx/jacobianDet(j)
          py = this%pressure*ny/jacobianDet(j)
          pz = this%pressure*nz/jacobianDet(j)
          
          int1 = int1 + integrator%getWeight(j)*integrator%getShapeFunc(j,i)  &
               * px*jacobianDet(j)
          int2 = int2 + integrator%getWeight(j)*integrator%getShapeFunc(j,i)  &
               * py*jacobianDet(j)
          int3 = int3 + integrator%getWeight(j)*integrator%getShapeFunc(j,i)  &
               * pz*jacobianDet(j)
       end do
       rhs(3*i-2) = rhs(3*i-2) + int1
       rhs(3*i-1) = rhs(3*i-1) + int2
       rhs(3*i)   = rhs(3*i)   + int3
    end do
  end subroutine calculateRHS

end module PressureM
