module StructuralElementM

  use UtilitiesM

  use Tetrahedron3D4NodeM
  use Tetrahedron3D10NodeM
  use Hexahedron3D8NodeM
  use Hexahedron3D20NodeM

  use IntegratorPtrM

  use LeftHandSideM
  use ProcessInfoM

  use PointM
  use NodeM
  use NodePtrM

  use SourceM
  use SourcePtrM
  
  use ElementM

  use StructuralMaterialM

  implicit none

  private
  public :: StructuralElementDT, structuralElement, initGeometries

  type, extends(ElementDT) :: StructuralElementDT
     class(StructuralMaterialDT), pointer :: material
   contains
     procedure, public  :: init
     procedure, public  :: calculateLHS
     procedure, public  :: calculateRHS
     procedure, public  :: calculateLocalSystem
     procedure, public  :: calculateResults
     procedure, private :: setupIntegration
     procedure, private :: getValuedSource
  end type StructuralElementDT

  interface structuralElement
     procedure :: constructor
  end interface structuralElement

  type(Tetrahedron3D4NodeDT) , target, save :: myTetrahedron3D4Node
  type(Tetrahedron3D10NodeDT), target, save :: myTetrahedron3D10Node
  type(Hexahedron3D8NodeDT)  , target, save :: myHexahedron3D8Node
  type(Hexahedron3D20NodeDT) , target, save :: myHexahedron3D20Node

contains

  type(StructuralElementDT) function constructor(id, node, material)
    implicit none
    integer(ikind)                          , intent(in) :: id
    type(NodePtrDT)           , dimension(:), intent(in) :: node
    type(StructuralMaterialDT), target      , intent(in) :: material
    call constructor%init(id, node, material)
  end function constructor

  subroutine init(this, id, node, material)
    implicit none
    class(StructuralElementDT)              , intent(inout) :: this
    integer(ikind)                          , intent(in)    :: id
    type(NodePtrDT)           , dimension(:), intent(in)    :: node
    type(StructuralMaterialDT), target      , intent(in)    :: material
    this%id = id
    this%node = node
    this%material => material
    if(size(node) == 4) then
       this%geometry => myTetrahedron3D4Node
    else if(size(node) == 8) then
       this%geometry => myHexahedron3D8Node
    else if(size(node) == 10) then
       this%geometry => myTetrahedron3D10Node
    else if(size(node) == 20) then
       this%geometry => myHexahedron3D20Node
    end if
    allocate(this%source(1))
  end subroutine init

  subroutine initGeometries(nGauss)
    implicit none
    integer(ikind), intent(in) :: nGauss
    myTetrahedron3D4Node = tetrahedron3D4Node(nGauss)
    myTetrahedron3D10Node = tetrahedron3D10Node(nGauss)
    myHexahedron3D8Node = hexahedron3D8Node(nGauss)
    myHexahedron3D20Node = hexahedron3D20Node(nGauss)
  end subroutine initGeometries

  subroutine calculateLocalSystem(this, processInfo, lhs, rhs)
    implicit none
    class(StructuralElementDT)                            , intent(inout) :: this
    type(ProcessInfoDT)                                   , intent(inout) :: processInfo
    type(LeftHandSideDT)                                  , intent(inout) :: lhs
    real(rkind)            , dimension(:)    , allocatable, intent(inout) :: rhs
    integer(ikind)                                                        :: i, j, ii, jj, k
    integer(ikind)                                                        :: nNode, nDof
    real(rkind)                                                           :: dNidx, dNidy, dNidz
    real(rkind)                                                           :: dNjdx, dNjdy, dNjdz
    real(rkind)            , dimension(3,3)                               :: Kij
    real(rkind)            , dimension(:,:,:), allocatable                :: jacobian
    real(rkind)            , dimension(:,:,:), allocatable                :: jacobianInv
    real(rkind)            , dimension(:)    , allocatable                :: jacobianDet
    real(rkind)                                                           :: val1, val2, val3
    real(rkind)            , dimension(:,:)  , allocatable                :: valuedSource
    type(IntegratorPtrDT)                                                 :: integrator
    type(NodePtrDT)        , dimension(:)    , allocatable                :: nodalPoints
    nNode = this%getnNode()
    nDof = this%node(1)%getnDof()
    integrator = this%getIntegrator()
    lhs = leftHandSide(0, 0, nNode*nDof)
    allocate(rhs(nNode*nDof))
    allocate(nodalPoints(nNode))
    rhs = 0._rkind
    do i = 1, nNode
       nodalPoints(i) = this%node(i)
    end do
    jacobian = this%geometry%jacobianAtGPoints(nodalPoints)
    jacobianDet = this%geometry%jacobianDetAtGPoints(jacobian)
    allocate(jacobianInv(integrator%getIntegTerms(),3,3))
    do i = 1, integrator%getIntegTerms()
       jacobianInv(i,1:3,1:3) = matinv3(jacobian(i,1:3,1:3))
    end do
    lhs%stiffness = 0._rkind
    do i = 1, nNode
       do j = 1, nNode
          ii = nDof*i-2
          jj = nDof*j-2
          do k = 1, integrator%getIntegTerms()
             dNidx = jacobianInv(k,1,1)*integrator%getDShapeFunc(k,1,i) &
                  + jacobianInv(k,1,2)*integrator%getDShapeFunc(k,2,i)  &
                  + jacobianInv(k,1,3)*integrator%getDShapeFunc(k,3,i)
             dNidy = jacobianInv(k,2,1)*integrator%getDShapeFunc(k,1,i) &
                  + jacobianInv(k,2,2)*integrator%getDShapeFunc(k,2,i)  &
                  + jacobianInv(k,2,3)*integrator%getDShapeFunc(k,3,i)
             dNidz = jacobianInv(k,3,1)*integrator%getDShapeFunc(k,1,i) &
                  + jacobianInv(k,3,2)*integrator%getDShapeFunc(k,2,i)  &
                  + jacobianInv(k,3,3)*integrator%getDShapeFunc(k,3,i)
             dNjdx = jacobianInv(k,1,1)*integrator%getDShapeFunc(k,1,j) &
                  + jacobianInv(k,1,2)*integrator%getDShapeFunc(k,2,j)  &
                  + jacobianInv(k,1,3)*integrator%getDShapeFunc(k,3,j)
             dNjdy = jacobianInv(k,2,1)*integrator%getDShapeFunc(k,1,j) &
                  + jacobianInv(k,2,2)*integrator%getDShapeFunc(k,2,j)  &
                  + jacobianInv(k,2,3)*integrator%getDShapeFunc(k,3,j)
             dNjdz = jacobianInv(k,3,1)*integrator%getDShapeFunc(k,1,j) &
                  + jacobianInv(k,3,2)*integrator%getDShapeFunc(k,2,j)  &
                  + jacobianInv(k,3,3)*integrator%getDShapeFunc(k,3,j)
             
             Kij(1,1) = dNidx*this%material%d(1,1)*dNjdx &
                  +     dNidy*this%material%d(4,4)*dNjdy &
                  +     dNidz*this%material%d(6,6)*dNjdz
             Kij(2,2) = dNidy*this%material%d(2,2)*dNjdy &
                  +     dNidx*this%material%d(4,4)*dNjdx &
                  +     dNidz*this%material%d(5,5)*dNjdz
             Kij(3,3) = dNidz*this%material%d(3,3)*dNjdz &
                  +     dNidy*this%material%d(5,5)*dNjdy &
                  +     dNidx*this%material%d(6,6)*dNjdx
             Kij(1,2) = dNidx*this%material%d(1,2)*dNjdy &
                  +     dNidy*this%material%d(4,4)*dNjdx
             Kij(2,1) = dNidy*this%material%d(2,1)*dNjdx &
                  +     dNidx*this%material%d(4,4)*dNjdy
             Kij(1,3) = dNidx*this%material%d(1,3)*dNjdz &
                  +     dNidz*this%material%d(6,6)*dNjdx
             Kij(3,1) = dNidz*this%material%d(3,1)*dNjdx &
                  +     dNidx*this%material%d(6,6)*dNjdz
             Kij(2,3) = dNidy*this%material%d(2,3)*dNjdz &
                  +     dNidz*this%material%d(5,5)*dNjdy
             Kij(3,2) = dNidz*this%material%d(3,2)*dNjdy &
                  +     dNidy*this%material%d(5,5)*dNjdz

             lhs%stiffness(ii,jj)     = lhs%stiffness(ii,jj)      &
                  + integrator%getWeight(k)*Kij(1,1)*jacobianDet(k)
             lhs%stiffness(ii,jj+1)   = lhs%stiffness(ii,jj+1)    &
                  + integrator%getWeight(k)*Kij(1,2)*jacobianDet(k)
             lhs%stiffness(ii,jj+2)   = lhs%stiffness(ii,jj+2)    &
                  + integrator%getWeight(k)*Kij(1,3)*jacobianDet(k)
             lhs%stiffness(ii+1,jj)   = lhs%stiffness(ii+1,jj)    &
                  + integrator%getWeight(k)*Kij(2,1)*jacobianDet(k)
             lhs%stiffness(ii+1,jj+1) = lhs%stiffness(ii+1,jj+1)  &
                  + integrator%getWeight(k)*Kij(2,2)*jacobianDet(k)
             lhs%stiffness(ii+1,jj+2) = lhs%stiffness(ii+1,jj+2)  &
                  + integrator%getWeight(k)*Kij(2,3)*jacobianDet(k)
             lhs%stiffness(ii+2,jj)   = lhs%stiffness(ii+2,jj)    &
                  + integrator%getWeight(k)*Kij(3,1)*jacobianDet(k)
             lhs%stiffness(ii+2,jj+1) = lhs%stiffness(ii+2,jj+1)  &
                  + integrator%getWeight(k)*Kij(3,2)*jacobianDet(k)
             lhs%stiffness(ii+2,jj+2) = lhs%stiffness(ii+2,jj+2)  &
                  + integrator%getWeight(k)*Kij(3,3)*jacobianDet(k)
          end do
       end do
       if(this%node(i)%hasSource()) then
          val1 = this%node(i)%ptr%source(1) &
               %evaluate(1, (/this%node(i)%getx(), this%node(i)%gety(), this%node(i)%getz()/))
          val2 = this%node(i)%ptr%source(1) &
               %evaluate(2, (/this%node(i)%getx(), this%node(i)%gety(), this%node(i)%getz()/))
          val3 = this%node(i)%ptr%source(1) &
               %evaluate(3, (/this%node(i)%getx(), this%node(i)%gety(), this%node(i)%getz()/))
          rhs(nDof*i-2) = rhs(nDof*i-2) + val1
          rhs(nDof*i-1) = rhs(nDof*i-1) + val2
          rhs(nDof*i)   = rhs(nDof*i)   + val3
       end if
    end do
    if(this%hasSource()) then
       allocate(valuedSource(3,integrator%getIntegTerms()))
       call this%setupIntegration(integrator, valuedSource, jacobianDet)
       do i = 1, nNode
          val1 = 0._rkind
          val2 = 0._rkind
          val3 = 0._rkind
          do j = 1, integrator%getIntegTerms()
             val1 = val1 + integrator%getWeight(j)*integrator%ptr%shapeFunc(j,i) &
                  *valuedSource(1,j)*jacobianDet(j)
             val2 = val2 + integrator%getWeight(j)*integrator%ptr%shapeFunc(j,i) &
                  *valuedSource(2,j)*jacobianDet(j)
             val3 = val3 + integrator%getWeight(j)*integrator%ptr%shapeFunc(j,i) &
                  *valuedSource(3,j)*jacobianDet(j)
          end do
          rhs(i*nDof-2) = rhs(i*nDof-2) + val1
          rhs(i*nDof-1) = rhs(i*nDof-1) + val2
          rhs(i*nDof)   = rhs(i*nDof)   + val3
       end do
       deallocate(valuedSource)
    end if
    deallocate(jacobian)
    deallocate(jacobianDet)
  end subroutine calculateLocalSystem

  subroutine calculateLHS(this, processInfo, lhs)
    implicit none
    class(StructuralElementDT)                            , intent(inout) :: this
    type(ProcessInfoDT)                                   , intent(inout) :: processInfo
    type(LeftHandSideDT)                                  , intent(inout) :: lhs
    integer(ikind)                                                        :: i, j, ii, jj, k
    integer(ikind)                                                        :: nNode, nDof
    real(rkind)                                                           :: dNidx, dNidy, dNidz
    real(rkind)                                                           :: dNjdx, dNjdy, dNjdz
    real(rkind)            , dimension(3,3)                               :: Kij
    real(rkind)            , dimension(:,:,:), allocatable                :: jacobian
    real(rkind)            , dimension(:,:,:), allocatable                :: jacobianInv
    real(rkind)            , dimension(:)    , allocatable                :: jacobianDet
    type(IntegratorPtrDT)                                                 :: integrator
    type(NodePtrDT)        , dimension(:)    , allocatable                :: nodalPoints
    nNode = this%getnNode()
    nDof = this%node(1)%getnDof()
    integrator = this%getIntegrator()
    lhs = leftHandSide(0, 0, nNode*nDof)
    allocate(nodalPoints(nNode))
    do i = 1, nNode
       nodalPoints(i) = this%node(i)
    end do
    jacobian = this%geometry%jacobianAtGPoints(nodalPoints)
    jacobianDet = this%geometry%jacobianDetAtGPoints(jacobian)
    allocate(jacobianInv(integrator%getIntegTerms(),3,3))
    do i = 1, integrator%getIntegTerms()
       jacobianInv(i,1:3,1:3) = matinv3(jacobian(i,1:3,1:3))
    end do
    do i = 1, nNode
       do j = 1, nNode
          ii = nDof*i-2
          jj = nDof*j-2
          lhs%stiffness(ii,jj)     = 0._rkind
          lhs%stiffness(ii+1,jj)   = 0._rkind
          lhs%stiffness(ii,jj+1)   = 0._rkind
          lhs%stiffness(ii+1,jj+1) = 0._rkind
          do k = 1, integrator%getIntegTerms()
             dNidx = jacobianInv(k,1,1)*integrator%getDShapeFunc(k,1,i) &
                  + jacobianInv(k,1,2)*integrator%getDShapeFunc(k,2,i)  &
                  + jacobianInv(k,1,3)*integrator%getDShapeFunc(k,3,i)
             dNidy = jacobianInv(k,2,1)*integrator%getDShapeFunc(k,1,i) &
                  + jacobianInv(k,2,2)*integrator%getDShapeFunc(k,2,i)  &
                  + jacobianInv(k,2,3)*integrator%getDShapeFunc(k,3,i)
             dNidz = jacobianInv(k,3,1)*integrator%getDShapeFunc(k,1,i) &
                  + jacobianInv(k,3,2)*integrator%getDShapeFunc(k,2,i)  &
                  + jacobianInv(k,3,3)*integrator%getDShapeFunc(k,3,i)
             dNjdx = jacobianInv(k,1,1)*integrator%getDShapeFunc(k,1,j) &
                  + jacobianInv(k,1,2)*integrator%getDShapeFunc(k,2,j)  &
                  + jacobianInv(k,1,3)*integrator%getDShapeFunc(k,3,j)
             dNjdy = jacobianInv(k,2,1)*integrator%getDShapeFunc(k,1,j) &
                  + jacobianInv(k,2,2)*integrator%getDShapeFunc(k,2,j)  &
                  + jacobianInv(k,2,3)*integrator%getDShapeFunc(k,3,j)
             dNjdz = jacobianInv(k,3,1)*integrator%getDShapeFunc(k,1,j) &
                  + jacobianInv(k,3,2)*integrator%getDShapeFunc(k,2,j)  &
                  + jacobianInv(k,3,3)*integrator%getDShapeFunc(k,3,j)
             
             Kij(1,1) = dNidx*this%material%d(1,1)*dNjdx &
                  +     dNidy*this%material%d(4,4)*dNjdy &
                  +     dNidz*this%material%d(6,6)*dNjdz
             Kij(2,2) = dNidy*this%material%d(2,2)*dNjdy &
                  +     dNidx*this%material%d(4,4)*dNjdx &
                  +     dNidz*this%material%d(5,5)*dNjdz
             Kij(3,3) = dNidz*this%material%d(3,3)*dNjdz &
                  +     dNidy*this%material%d(5,5)*dNjdy &
                  +     dNidx*this%material%d(6,6)*dNjdx
             Kij(1,2) = dNidx*this%material%d(1,2)*dNjdy &
                  +     dNidy*this%material%d(4,4)*dNjdx
             Kij(2,1) = dNidy*this%material%d(2,1)*dNjdx &
                  +     dNidx*this%material%d(4,4)*dNjdy
             Kij(1,3) = dNidx*this%material%d(1,3)*dNjdz &
                  +     dNidz*this%material%d(6,6)*dNjdx
             Kij(3,1) = dNidz*this%material%d(3,1)*dNjdx &
                  +     dNidx*this%material%d(6,6)*dNjdz
             Kij(2,3) = dNidy*this%material%d(2,3)*dNjdz &
                  +     dNidz*this%material%d(5,5)*dNjdy
             Kij(3,2) = dNidz*this%material%d(3,2)*dNjdy &
                  +     dNidy*this%material%d(5,5)*dNjdz

             lhs%stiffness(ii,jj)     = lhs%stiffness(ii,jj)      &
                  + integrator%getWeight(k)*Kij(1,1)*jacobianDet(k)
             lhs%stiffness(ii,jj+1)   = lhs%stiffness(ii,jj+1)    &
                  + integrator%getWeight(k)*Kij(1,2)*jacobianDet(k)
             lhs%stiffness(ii,jj+2)   = lhs%stiffness(ii,jj+2)    &
                  + integrator%getWeight(k)*Kij(1,3)*jacobianDet(k)
             lhs%stiffness(ii+1,jj)   = lhs%stiffness(ii+1,jj)    &
                  + integrator%getWeight(k)*Kij(2,1)*jacobianDet(k)
             lhs%stiffness(ii+1,jj+1) = lhs%stiffness(ii+1,jj+1)  &
                  + integrator%getWeight(k)*Kij(2,2)*jacobianDet(k)
             lhs%stiffness(ii+1,jj+2) = lhs%stiffness(ii+1,jj+2)  &
                  + integrator%getWeight(k)*Kij(2,3)*jacobianDet(k)
             lhs%stiffness(ii+2,jj)   = lhs%stiffness(ii+2,jj)    &
                  + integrator%getWeight(k)*Kij(3,1)*jacobianDet(k)
             lhs%stiffness(ii+2,jj+1) = lhs%stiffness(ii+2,jj+1)  &
                  + integrator%getWeight(k)*Kij(3,2)*jacobianDet(k)
             lhs%stiffness(ii+2,jj+2) = lhs%stiffness(ii+2,jj+2)  &
                  + integrator%getWeight(k)*Kij(3,3)*jacobianDet(k)
          end do
       end do
    end do
  end subroutine calculateLHS

  subroutine calculateRHS(this, processInfo, rhs)
    implicit none
    class(StructuralElementDT)                          , intent(inout) :: this
    type(ProcessInfoDT)                                 , intent(inout) :: processInfo
    real(rkind)            , dimension(:)  , allocatable, intent(inout) :: rhs
    integer(ikind)                                                      :: i, j, nNode, nDof
    real(rkind)                                                         :: val1, val2, val3
    real(rkind)            , dimension(:,:), allocatable                :: valuedSource
    real(rkind)            , dimension(:)  , allocatable                :: jacobianDet
    type(IntegratorPtrDT)                                               :: integrator
    nNode = this%getnNode()
    nDof = this%node(1)%getnDof()
    allocate(rhs(nNode*nDof))
    rhs = 0._rkind
    do i = 1, nNode
       if(this%node(i)%hasSource()) then
          val1 = this%node(i)%ptr%source(1) &
               %evaluate(1, (/this%node(i)%getx(), this%node(i)%gety(), this%node(i)%getz()/))
          val2 = this%node(i)%ptr%source(1) &
               %evaluate(2, (/this%node(i)%getx(), this%node(i)%gety(), this%node(i)%getz()/))
          val3 = this%node(i)%ptr%source(1) &
               %evaluate(3, (/this%node(i)%getx(), this%node(i)%gety(), this%node(i)%getz()/))
          rhs(nDof*i-2) = rhs(nDof*i-2) + val1
          rhs(nDof*i-1) = rhs(nDof*i-1) + val2
          rhs(nDof*i)   = rhs(nDof*i)   + val3
       end if
    end do
    if(this%hasSource()) then
       integrator = this%getIntegrator()
       allocate(valuedSource(3,integrator%getIntegTerms()))
       allocate(jacobianDet(integrator%getIntegTerms()))
       call this%setupIntegration(integrator, valuedSource, jacobianDet)
       do i = 1, nNode
          val1 = 0._rkind
          val2 = 0._rkind
          val3 = 0._rkind
          do j = 1, integrator%getIntegTerms()
             val1 = val1 + integrator%getWeight(j)*integrator%ptr%shapeFunc(j,i) &
                  *valuedSource(1,j)*jacobianDet(j)
             val2 = val2 + integrator%getWeight(j)*integrator%ptr%shapeFunc(j,i) &
                  *valuedSource(2,j)*jacobianDet(j)
             val3 = val3 + integrator%getWeight(j)*integrator%ptr%shapeFunc(j,i) &
                  *valuedSource(3,j)*jacobianDet(j)
          end do
          rhs(i*nDof-2) = rhs(i*nDof-2) + val1
          rhs(i*nDof-1) = rhs(i*nDof-1) + val2
          rhs(i*nDof)   = rhs(i*nDof)   + val3
       end do
       deallocate(valuedSource)
       deallocate(jacobianDet)
    end if
  end subroutine calculateRHS

  subroutine setupIntegration(this, integrator, valuedSource, jacobianDet)
    implicit none
    class(StructuralElementDT)                          , intent(inout) :: this
    type(IntegratorPtrDT)                               , intent(in)    :: integrator
    real(rkind), dimension(2,integrator%getIntegTerms()), intent(out)   :: valuedSource
    real(rkind), dimension(integrator%getIntegTerms())  , intent(out)   :: jacobianDet
    integer(ikind)                                                      :: i, nNode
    type(NodePtrDT), dimension(:), allocatable                          :: nodalPoints
    nNode = this%getnNode()
    allocate(nodalPoints(nNode))
    valuedSource = this%getValuedSource(integrator)
    do i = 1, nNode
       nodalPoints(i) = this%node(i)
    end do
    jacobianDet = this%geometry%jacobianDetAtGPoints(nodalPoints)
  end subroutine setupIntegration

  function getValuedSource(this, integrator)
    implicit none
    class(StructuralElementDT), intent(inout) :: this
    type(IntegratorPtrDT) , intent(in) :: integrator
    real(rkind), dimension(3,integrator%getIntegTerms()) :: getValuedSource
    integer(ikind) :: i, j, nNode
    real(rkind) :: x, y, z
    type(NodePtrDT), dimension(:), allocatable :: node
    nNode = this%getnNode()
    do i = 1, integrator%getIntegTerms()
       node = this%node
       x = 0
       y = 0
       z = 0
       do j = 1, nNode
          x = x + integrator%getShapeFunc(i,j)*node(j)%ptr%getx()
          y = y + integrator%getShapeFunc(i,j)*node(j)%ptr%gety()
          z = z + integrator%getShapeFunc(i,j)*node(j)%ptr%getz()
       end do
       getValuedSource(1,i) = this%source(1)%evaluate(1, (/x,y,z/))
       getValuedSource(2,i) = this%source(1)%evaluate(2, (/x,y,z/))
       getValuedSource(3,i) = this%source(1)%evaluate(3, (/x,y,z/))
    end do
  end function getValuedSource

  subroutine calculateResults(this, processInfo, resultMat)
    implicit none
    class(StructuralElementDT)                            , intent(inout) :: this
    type(ProcessInfoDT)                                   , intent(inout) :: processInfo
    real(rkind)            , dimension(:,:,:), allocatable, intent(inout) :: resultMat
    integer(ikind)                                                        :: i, iGauss, nNode
    real(rkind)                                                           :: sxy, sxz, syz
    real(rkind)                                                           :: epx, epy, epz
    real(rkind)                                                           :: xi, eta
    real(rkind)                                                           :: dNidx, dNidy, dNidz
    real(rkind)                                                           :: kx, ky
    real(rkind)            , dimension(6,6)                               :: d
    real(rkind)            , dimension(:,:,:), allocatable                :: jacobian
    real(rkind)            , dimension(:,:,:), allocatable                :: jacobianInv
    real(rkind)            , dimension(:)    , allocatable                :: jacobianDet
    type(IntegratorPtrDT)                                                 :: integrator
    type(NodePtrDT)        , dimension(:)    , allocatable                :: nodalPoints
    integrator = this%getIntegrator()
    nNode = this%getnNode()
    allocate(nodalPoints(nNode))
    allocate(resultMat(3,integrator%getIntegTerms(),3))
    do i = 1, nNode
       nodalPoints(i) = this%node(i)
    end do
    jacobian = this%geometry%jacobianAtGPoints(nodalPoints)
    jacobianDet = this%geometry%jacobianDetAtGPoints(jacobian)
    allocate(jacobianInv(integrator%getIntegTerms(),3,3))
    do i = 1, integrator%getIntegTerms()
       jacobianInv(i,1:3,1:3) = matinv3(jacobian(i,1:3,1:3))
    end do
    do iGauss = 1, integrator%getIntegTerms()
       sxy = 0._rkind
       sxz = 0._rkind
       syz = 0._rkind
       epx = 0._rkind
       epy = 0._rkind
       epz = 0._rkind
       do i = 1, nNode
          dNidx = jacobianInv(iGauss,1,1)*integrator%getDShapeFunc(iGauss,1,i) &
               + jacobianInv(iGauss,1,2)*integrator%getDShapeFunc(iGauss,2,i)  &
               + jacobianInv(iGauss,1,3)*integrator%getDShapeFunc(iGauss,3,i)
          dNidy = jacobianInv(iGauss,2,1)*integrator%getDShapeFunc(iGauss,1,i) &
               + jacobianInv(iGauss,2,2)*integrator%getDShapeFunc(iGauss,2,i)  &
               + jacobianInv(iGauss,2,3)*integrator%getDShapeFunc(iGauss,3,i)
          dNidz = jacobianInv(iGauss,3,1)*integrator%getDShapeFunc(iGauss,1,i) &
               + jacobianInv(iGauss,3,2)*integrator%getDShapeFunc(iGauss,2,i)  &
               + jacobianInv(iGauss,3,3)*integrator%getDShapeFunc(iGauss,3,i)
          sxy = sxy + dNidx*this%node(i)%ptr%dof(2)%val + dNidy*this%node(i)%ptr%dof(1)%val
          sxz = sxz + dNidx*this%node(i)%ptr%dof(3)%val + dNidz*this%node(i)%ptr%dof(1)%val
          syz = syz + dNidy*this%node(i)%ptr%dof(3)%val + dNidz*this%node(i)%ptr%dof(2)%val
          epx = epx + dNidx*this%node(i)%ptr%dof(1)%val
          epy = epy + dNidy*this%node(i)%ptr%dof(2)%val
          epz = epz + dNidz*this%node(i)%ptr%dof(3)%val
       end do
       d = this%material%d
       resultMat(1,iGauss,1) = d(1,1)*epx + d(1,2)*epy + d(1,3)*epz
       resultMat(1,iGauss,2) = d(2,1)*epx + d(2,2)*epy + d(2,3)*epz
       resultMat(1,iGauss,3) = d(3,1)*epx + d(3,2)*epy + d(3,3)*epz
       resultMat(2,iGauss,1) = d(4,4)*sxy
       resultMat(2,iGauss,2) = d(5,5)*syz
       resultMat(2,iGauss,3) = d(6,6)*sxz
       resultMat(3,iGauss,1) = epx
       resultMat(3,iGauss,2) = epy
       resultMat(3,iGauss,3) = epz
    end do
  end subroutine calculateResults

end module StructuralElementM
